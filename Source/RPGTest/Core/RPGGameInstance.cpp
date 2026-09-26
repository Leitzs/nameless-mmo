#include "Core/RPGGameInstance.h"

#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "RPGTest.h"

#define LOCTEXT_NAMESPACE "RPGGameInstance"

URPGGameInstance::URPGGameInstance()
{
	auto AddMap = [this](const FText& Name, const FText& Description, const TCHAR* LevelPath)
	{
		FRPGMapInfo& Map = Maps.AddDefaulted_GetRef();
		Map.DisplayName = Name;
		Map.Description = Description;
		Map.Level = TSoftObjectPtr<UWorld>(FSoftObjectPath(LevelPath));
	};
	AddMap(LOCTEXT("Whisperwood", "Whisperwood Forest"), LOCTEXT("WhisperwoodDescription", "Procedural forest with a village, roads, ruins and a training bot."),
		TEXT("/Game/RPGTest/Maps/L_Whisperwood.L_Whisperwood"));
	AddMap(LOCTEXT("TestArena", "Test Arena"), LOCTEXT("TestArenaDescription", "Flat grid arena: duel bot with range rings, bot group, cover, range lane."),
		TEXT("/Game/RPGTest/Maps/L_TestArena.L_TestArena"));
}

int32 URPGGameInstance::FindMapIndex(const UWorld* World) const
{
	if (!World)
	{
		return INDEX_NONE;
	}

	// PIE worlds live in packages like /Game/Maps/UEDPIE_0_L_Map.
	const FString PackageName = UWorld::RemovePIEPrefix(World->GetPackage()->GetName());
	return Maps.IndexOfByPredicate([&PackageName](const FRPGMapInfo& Map) { return Map.Level.GetLongPackageName() == PackageName; });
}

bool URPGGameInstance::OpenMap(int32 MapIndex)
{
	if (!Maps.IsValidIndex(MapIndex))
	{
		return false;
	}

	MarkMapChosen();
	if (FindMapIndex(GetWorld()) == MapIndex)
	{
		return false;
	}

	UE_LOG(LogRPG, Log, TEXT("Opening map '%s'"), *Maps[MapIndex].Level.GetLongPackageName());
	UGameplayStatics::OpenLevelBySoftObjectPtr(this, Maps[MapIndex].Level);
	return true;
}

#undef LOCTEXT_NAMESPACE
