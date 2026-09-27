using UnrealBuildTool;

public class RPGTest : ModuleRules
{
	public RPGTest(ReadOnlyTargetRules Target) : base(Target)
	{
		PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;

		PublicIncludePaths.Add(ModuleDirectory);

		PublicDependencyModuleNames.AddRange(new string[]
		{
			"Core",
			"CoreUObject",
			"Engine",
			"InputCore",
			"EnhancedInput",
			"AIModule",
			"NavigationSystem",
			"GameplayTasks",
			// Gameplay Ability System: abilities, attributes, effects and tags.
			"GameplayAbilities",
			"GameplayTags",
			"ProceduralMeshComponent",
			// Push-model replication (MARK_PROPERTY_DIRTY).
			"NetCore"
		});

		// Main menu and class picker are plain Slate widgets built in code; Sockets finds the host's LAN address;
		// EngineSettings gives the default map to return to when leaving a game.
		PrivateDependencyModuleNames.AddRange(new string[] { "Slate", "SlateCore", "Sockets", "EngineSettings" });
	}
}
