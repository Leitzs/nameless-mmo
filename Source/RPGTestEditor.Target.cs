using UnrealBuildTool;

public class RPGTestEditorTarget : TargetRules
{
	public RPGTestEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("RPGTest");
	}
}
