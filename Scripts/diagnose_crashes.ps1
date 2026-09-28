# Collects the evidence needed to tell an Unreal/game crash apart from a machine-level reset.
#
# Run it after a crash (the editor/game closed by itself, or the PC restarted) and it prints:
#   - unexpected shutdowns (Kernel-Power 41 / EventLog 6008)
#   - corrected PCIe/hardware errors (WHEA-Logger)
#   - WER application crashes (UnrealEditor.exe and friends)
#   - Unreal crash report folders and the tail of the last RPGTest log
#   - CPU / RAM / GPU summary (RAM speed above JEDEC means XMP is on)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File Scripts\diagnose_crashes.ps1
#   $env:RPG_DIAG_DAYS = 30; powershell -ExecutionPolicy Bypass -File Scripts\diagnose_crashes.ps1
#
# How to read the output:
#   - "Unexpected shutdowns" with no WER crash for UnrealEditor.exe = the OS went down (power, thermal,
#     XMP/memory or a PCIe device dropping off), not the game. Look for the matching log tail.
#   - WHEA errors repeating on one device = a marginal PCIe link on the motherboard (driver/BIOS/port).
#   - A WER crash whose faulting module is an nv*.dll = the GPU driver; update it.

param(
	[int]$Days = 0
)

if ($Days -le 0) {
	if ($env:RPG_DIAG_DAYS) { $Days = [int]$env:RPG_DIAG_DAYS } else { $Days = 7 }
}

$Root = Split-Path -Parent $PSScriptRoot
$Since = (Get-Date).AddDays(-$Days)

function Write-Section([string]$Title) {
	Write-Output ""
	Write-Output ("=" * 78)
	Write-Output $Title
	Write-Output ("=" * 78)
}

function Write-EventLines($Events, [int]$Max) {
	$i = 0
	foreach ($e in $Events) {
		if ($i -ge $Max) { break }
		Write-Output ("  {0} | {1} | Id={2}" -f $e.TimeCreated, $e.ProviderName, $e.Id)
		foreach ($line in ($e.Message -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 3)) {
			Write-Output ("      " + $line.Trim())
		}
		$i++
	}
	if ($i -eq 0) { Write-Output "  (none)" }
}

Write-Output "RPGTest crash diagnosis - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - looking back $Days day(s)"

Write-Section "Machine: unexpected shutdowns and boots"
try {
	$unclean = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41, 6008; StartTime = $Since } -ErrorAction SilentlyContinue |
		Sort-Object TimeCreated
	Write-Output "  Unclean shutdown / reboot reports: $($unclean.Count)"
	Write-EventLines $unclean 15
} catch { Write-Output "  (System log not readable: $_)" }

Write-Section "Machine: WHEA hardware errors (corrected)"
try {
	$whea = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $Since } -ErrorAction SilentlyContinue
	Write-Output "  WHEA events: $($whea.Count)"
	if ($whea.Count -gt 0) {
		$whea | ForEach-Object {
			$device = "unknown"
			try {
				$xml = [xml]$_.ToXml()
				$data = @{}
				$xml.Event.EventData.Data | ForEach-Object { $data[$_.Name] = $_.'#text' }
				$device = "bus $($data.Bus) dev $($data.Device) fn $($data.Function) id=$($data.DeviceID) name=$($data.PrimaryDeviceName)"
			} catch { }
			[pscustomobject]@{ Device = $device; Day = $_.TimeCreated.ToString('yyyy-MM-dd HH') }
		} | Group-Object Device | ForEach-Object {
			Write-Output ("  {0} x  {1}" -f $_.Count, $_.Name)
			$_.Group | Group-Object Day | Sort-Object Name | Select-Object -Last 5 | ForEach-Object { Write-Output ("      {0}h: {1}" -f $_.Name, $_.Count) }
		}
	}
} catch { Write-Output "  (WHEA query failed: $_)" }

Write-Section "Machine: application crashes (Windows Error Reporting)"
try {
	$wer = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $Since } -ErrorAction SilentlyContinue |
		Where-Object { ($_.Id -eq 1000) -or ($_.Id -eq 1001 -and $_.Message -match 'Unreal|RPGTest|nv|d3d') }
	Write-Output "  WER entries: $($wer.Count)"
	Write-EventLines ($wer | Sort-Object TimeCreated) 15
} catch { Write-Output "  (Application log not readable: $_)" }

Write-Section "Unreal: crash report folders"
$crashConfigRoot = Join-Path $Root 'Saved\Config\CrashReportClient'
if (Test-Path $crashConfigRoot) {
	$dirs = Get-ChildItem $crashConfigRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
	Write-Output "  Saved\Config\CrashReportClient entries: $($dirs.Count) (newest first)"
	$dirs | Select-Object -First 8 | ForEach-Object { Write-Output ("  {0} | {1}" -f $_.LastWriteTime, $_.Name) }
}
$crashRoot = Join-Path $Root 'Saved\Crashes'
if (Test-Path $crashRoot) {
	Write-Output "  Saved\Crashes:"
	Get-ChildItem $crashRoot -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 8 |
		ForEach-Object { Write-Output ("  {0} | {1}" -f $_.LastWriteTime, $_.Name) }
} else {
	Write-Output "  Saved\Crashes does not exist - keep it next time by closing the crash dialog with 'Close without sending'."
}

Write-Section "Unreal: tail of the last session log"
$logs = Get-ChildItem (Join-Path $Root 'Saved\Logs') -Filter 'RPGTest*.log' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($logs) {
	$newest = $logs | Select-Object -First 1
	Write-Output "  $($newest.FullName) (last write $($newest.LastWriteTime))"
	Get-Content $newest.FullName -Tail 20 | ForEach-Object { Write-Output ("  " + $_) }
} else {
	Write-Output "  (no RPGTest logs found)"
}

Write-Section "Hardware summary"
try {
	Get-CimInstance Win32_Processor | ForEach-Object { Write-Output ("  CPU: {0} ({1}C/{2}T, base {3} MHz)" -f $_.Name, $_.NumberOfCores, $_.NumberOfLogicalProcessors, $_.MaxClockSpeed) }
	Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
		$speed = $_.Speed
		$note = ""
		if ($speed -gt 2666) { $note = "  <- above JEDEC for most DDR4 kits: this is an XMP profile" }
		Write-Output ("  RAM: {0} {1} {2} GB @ {3} MT/s{4}" -f $_.Manufacturer, $_.PartNumber, [int]($_.Capacity / 1GB), $_.ConfiguredClockSpeed, $note)
	}
	Get-CimInstance Win32_VideoController | ForEach-Object { Write-Output ("  GPU: {0} - driver {1} ({2})" -f $_.Name, $_.DriverVersion, $_.DriverDate) }
	$cc = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' -ErrorAction SilentlyContinue
	if ($cc) { Write-Output ("  Crash dumps: CrashDumpEnabled=$($cc.CrashDumpEnabled) AutoReboot=$($cc.AutoReboot) Dump=$($cc.DumpFile)") }
} catch { Write-Output "  (hardware query failed: $_)" }

Write-Output ""
Write-Output "Done."
