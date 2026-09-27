#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "UObject/ObjectKey.h"
#include "RPGTestGameMode.generated.h"

class ARPGCharacterBase;

/**
 * Server-only rules, offline and online alike:
 *  - each player spawns as the class in its player state (from the login URL or picked later in game),
 *  - deathmatch: players are hostile to each other, kills and deaths are counted, kills are announced,
 *  - a dead player respawns after PlayerRespawnDelay at the player start farthest from the other players.
 */
UCLASS()
class RPGTEST_API ARPGTestGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ARPGTestGameMode();

	/** Login URL option carrying the class id, e.g. "?RPGClass=Mage" (see URPGLocalPlayer). */
	static constexpr const TCHAR* ClassOption = TEXT("RPGClass");

	virtual void InitGameState() override;
	virtual FString InitNewPlayer(APlayerController* NewPlayerController, const FUniqueNetIdRepl& UniqueId, const FString& Options, const FString& Portal = TEXT("")) override;
	virtual UClass* GetDefaultPawnClassForController_Implementation(AController* InController) override;
	virtual AActor* ChoosePlayerStart_Implementation(AController* Player) override;
	virtual APawn* SpawnDefaultPawnAtTransform_Implementation(AController* NewPlayer, const FTransform& SpawnTransform) override;
	virtual void Logout(AController* Exiting) override;

	/** Called by every character when it dies. Counts the score and schedules the respawn of players. */
	void NotifyCharacterDied(ARPGCharacterBase* Victim, AActor* Killer);

	/** Switches a player to another class. A living character is replaced right away; a dead one respawns as the new class. */
	bool ChangeCharacterClass(APlayerController* PlayerController, FName ClassId);

	/** Changes a player's display name (sanitized). */
	void ChangePlayerName(APlayerController* PlayerController, const FString& NewName);

protected:
	UPROPERTY(EditDefaultsOnly, Category = "RPG", meta = (ClampMin = "0"))
	float PlayerRespawnDelay = 5.f;

	/** Deathmatch: characters of different players damage each other. */
	UPROPERTY(EditDefaultsOnly, Category = "RPG")
	bool bPlayersHostile = true;

private:
	void RespawnPlayer(TWeakObjectPtr<AController> PlayerController);

	TMap<TObjectKey<AController>, FTimerHandle> RespawnTimers;
};
