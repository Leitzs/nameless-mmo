#pragma once

#include "CoreMinimal.h"
#include "Engine/GameInstance.h"
#include "RPGGameInstance.generated.h"

class ARPGPlayerCharacter;

/** A level offered by the map selector. */
USTRUCT(BlueprintType)
struct FRPGMapInfo
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Map")
	FText DisplayName;

	/** One line shown under the name in the selector. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Map")
	FText Description;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Map")
	TSoftObjectPtr<UWorld> Level;
};

/** A playable class offered by the class selector. */
USTRUCT(BlueprintType)
struct FRPGCharacterClassInfo
{
	GENERATED_BODY()

	/** Stable identifier sent over the network and saved in the player profile. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Class")
	FName Id;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Class")
	FText DisplayName;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Class")
	FText Description;

	/** Accent color in menus. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Class")
	FLinearColor Color = FLinearColor::White;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Class")
	TSubclassOf<ARPGPlayerCharacter> PawnClass;
};

/**
 * Lives for the whole play session: holds the maps and playable classes, and the local player's profile
 * (name, chosen class, last address joined), which is saved to the user's Game.ini. URPGLocalPlayer sends the
 * name and class to the server on every login. Hosting, joining and leaving games is done by URPGSessionSubsystem.
 */
UCLASS(Config = Game)
class RPGTEST_API URPGGameInstance : public UGameInstance
{
	GENERATED_BODY()

public:
	URPGGameInstance();

	virtual void Init() override;

	const TArray<FRPGMapInfo>& GetMaps() const { return Maps; }

	/** Index of the map loaded in World, or INDEX_NONE when it is not in the list. */
	int32 FindMapIndex(const UWorld* World) const;

	const TArray<FRPGCharacterClassInfo>& GetCharacterClasses() const { return CharacterClasses; }
	const FRPGCharacterClassInfo* FindCharacterClass(FName ClassId) const;
	FName GetDefaultCharacterClassId() const { return CharacterClasses.Num() > 0 ? CharacterClasses[0].Id : NAME_None; }

	// Local player profile.
	const FString& GetPlayerName() const { return PlayerName; }
	void SetPlayerName(const FString& InPlayerName);
	FName GetSelectedClassId() const { return SelectedClassId; }
	void SetSelectedClassId(FName InClassId);
	const FString& GetLastJoinAddress() const { return LastJoinAddress; }
	void SetLastJoinAddress(const FString& InAddress);

	/** Keeps letters, digits, '_' and '-' (URL-safe), at most 20 characters. */
	static FString SanitizePlayerName(const FString& InName);

protected:
	UPROPERTY(EditDefaultsOnly, Category = "Maps")
	TArray<FRPGMapInfo> Maps;

	/** The first entry is the default class. */
	UPROPERTY(EditDefaultsOnly, Category = "Classes")
	TArray<FRPGCharacterClassInfo> CharacterClasses;

private:
	UPROPERTY(Config)
	FString PlayerName;

	UPROPERTY(Config)
	FName SelectedClassId;

	UPROPERTY(Config)
	FString LastJoinAddress;
};
