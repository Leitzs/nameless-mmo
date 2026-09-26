using UnrealBuildTool;

public class RPGTestTarget : TargetRules
{
	public RPGTestTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("RPGTest");
	}
}
