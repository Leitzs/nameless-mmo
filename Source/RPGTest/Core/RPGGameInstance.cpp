#include "Core/RPGGameInstance.h"

#include "AbilitySystemGlobals.h"
#include "Characters/ArcherCharacter.h"
#include "Characters/MageCharacter.h"
#include "Characters/PaladinCharacter.h"
#include "Characters/RogueCharacter.h"
#include "Characters/WarlockCharacter.h"
#include "Characters/WarriorCharacter.h"
#include "Engine/World.h"

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

	// New classes: add a row here (and a pawn class deriving from ARPGPlayerCharacter).
	auto AddClass = [this](FName Id, const FText& Name, const FText& Description, const FLinearColor& Color, TSubclassOf<ARPGPlayerCharacter> PawnClass)
	{
		FRPGCharacterClassInfo& Info = CharacterClasses.AddDefaulted_GetRef();
		Info.Id = Id;
		Info.DisplayName = Name;
		Info.Description = Description;
		Info.Color = Color;
		Info.PawnClass = PawnClass;
	};
	AddClass(TEXT("Mage"), LOCTEXT("MageClass", "Mage"),
		LOCTEXT("MageClassDescription", "Ranged caster (mana). Fireball, Frost Nova, Lightning Strike, Blink, Arcane Shield."),
		FLinearColor(0.6f, 0.35f, 1.f), AMageCharacter::StaticClass());
	AddClass(TEXT("Warlock"), LOCTEXT("WarlockClass", "Warlock"),
		LOCTEXT("WarlockClassDescription", "Shadow caster (mana). Shadow Bolt, Corruption, Drain Life, Fear, Demonic Circle."),
		FLinearColor(0.35f, 0.9f, 0.25f), AWarlockCharacter::StaticClass());
	AddClass(TEXT("Paladin"), LOCTEXT("PaladinClass", "Paladin"),
		LOCTEXT("PaladinClassDescription", "Sword and shield (mana). Crusader Strike, Hammer of Justice, Flash of Light, Cleanse, Divine Shield."),
		FLinearColor(1.f, 0.82f, 0.35f), APaladinCharacter::StaticClass());
	AddClass(TEXT("Rogue"), LOCTEXT("RogueClass", "Rogue"),
		LOCTEXT("RogueClassDescription", "Daggers (energy). Stealth, Backstab, Throwing Knife, Kidney Shot, Shadowstep."),
		FLinearColor(0.95f, 0.9f, 0.4f), ARogueCharacter::StaticClass());
	AddClass(TEXT("Warrior"), LOCTEXT("WarriorClass", "Warrior"),
		LOCTEXT("WarriorClassDescription", "Greatsword (rage). Charge, Mortal Strike, Hamstring, Whirlwind, Berserker Rush."),
		FLinearColor(0.9f, 0.3f, 0.2f), AWarriorCharacter::StaticClass());
	AddClass(TEXT("Archer"), LOCTEXT("ArcherClass", "Archer"),
		LOCTEXT("ArcherClassDescription", "Longbow (energy). Aimed Shot, Multi-Shot, Concussive Shot, Disengage, Rain of Arrows."),
		FLinearColor(0.3f, 0.75f, 0.55f), AArcherCharacter::StaticClass());
}

void URPGGameInstance::Init()
{
	Super::Init();

	// Loads the ability system's global data (target data types used to send aim to the server).
	if (!UAbilitySystemGlobals::Get().IsAbilitySystemGlobalsInitialized())
	{
		UAbilitySystemGlobals::Get().InitGlobalData();
	}

	if (!FindCharacterClass(SelectedClassId))
	{
		SelectedClassId = GetDefaultCharacterClassId();
	}
	PlayerName = SanitizePlayerName(PlayerName);
	if (PlayerName.IsEmpty())
	{
		PlayerName = FString::Printf(TEXT("Player%03d"), FMath::RandRange(1, 999));
		SaveConfig();
	}
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

const FRPGCharacterClassInfo* URPGGameInstance::FindCharacterClass(FName ClassId) const
{
	return CharacterClasses.FindByPredicate([ClassId](const FRPGCharacterClassInfo& Info) { return Info.Id == ClassId; });
}

void URPGGameInstance::SetPlayerName(const FString& InPlayerName)
{
	const FString Sanitized = SanitizePlayerName(InPlayerName);
	if (!Sanitized.IsEmpty() && Sanitized != PlayerName)
	{
		PlayerName = Sanitized;
		SaveConfig();
	}
}

void URPGGameInstance::SetSelectedClassId(FName InClassId)
{
	if (FindCharacterClass(InClassId) && InClassId != SelectedClassId)
	{
		SelectedClassId = InClassId;
		SaveConfig();
	}
}

void URPGGameInstance::SetLastJoinAddress(const FString& InAddress)
{
	if (InAddress != LastJoinAddress)
	{
		LastJoinAddress = InAddress;
		SaveConfig();
	}
}

FString URPGGameInstance::SanitizePlayerName(const FString& InName)
{
	FString Result;
	for (const TCHAR Character : InName.TrimStartAndEnd())
	{
		if (FChar::IsAlnum(Character) || Character == TEXT('_') || Character == TEXT('-'))
		{
			Result.AppendChar(Character);
		}
	}
	return Result.Left(20);
}

#undef LOCTEXT_NAMESPACE
