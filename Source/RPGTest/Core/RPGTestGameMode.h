#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "RPGTestGameMode.generated.h"

/** Spawns the player as a Mage with the RPG controller and HUD, and respawns the player after death. */
UCLASS()
class RPGTEST_API ARPGTestGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ARPGTestGameMode();

	/** Schedules a respawn at a player start. */
	void NotifyPlayerDied(AController* PlayerController);

	/** Seconds until the dead player respawns, 0 when no respawn is pending. */
	float GetRespawnTimeRemaining() const;

protected:
	UPROPERTY(EditDefaultsOnly, Category = "RPG", meta = (ClampMin = "0"))
	float PlayerRespawnDelay = 5.f;

private:
	void RespawnPlayer(TWeakObjectPtr<AController> PlayerController);

	FTimerHandle RespawnTimer;
};
