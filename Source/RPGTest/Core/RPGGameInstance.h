#pragma once

#include "CoreMinimal.h"
#include "Engine/GameInstance.h"
#include "RPGGameInstance.generated.h"

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

/**
 * Lives for the whole play session: holds the maps offered by the map selector and remembers whether the player
 * already picked one, so the selector only opens on the first level loaded after pressing Play.
 */
UCLASS()
class RPGTEST_API URPGGameInstance : public UGameInstance
{
	GENERATED_BODY()

public:
	URPGGameInstance();

	const TArray<FRPGMapInfo>& GetMaps() const { return Maps; }

	/** Index of the map loaded in World, or INDEX_NONE when it is not in the list. */
	int32 FindMapIndex(const UWorld* World) const;

	bool HasChosenMap() const { return bHasChosenMap; }

	/** Stops the selector from opening automatically on later level loads. */
	void MarkMapChosen() { bHasChosenMap = true; }

	/** Marks the map as chosen and travels to it unless it is already loaded. Returns true when a level change started. */
	bool OpenMap(int32 MapIndex);

protected:
	UPROPERTY(EditDefaultsOnly, Category = "Maps")
	TArray<FRPGMapInfo> Maps;

private:
	bool bHasChosenMap = false;
};
