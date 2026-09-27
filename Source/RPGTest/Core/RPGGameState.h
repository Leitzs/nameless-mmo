#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameStateBase.h"
#include "FX/RPGTransientFX.h"
#include "RPGGameState.generated.h"

class APlayerState;

/**
 * Match state every machine can see: whether players fight each other (deathmatch) and the channel that forwards
 * one-off cosmetic events from the server to all clients (spell effects, kill messages).
 */
UCLASS()
class RPGTEST_API ARPGGameState : public AGameStateBase
{
	GENERATED_BODY()

public:
	ARPGGameState();

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

	/** True in deathmatch: characters on the Player team are hostile to each other. */
	bool ArePlayersHostile() const { return bPlayersHostile; }
	void SetPlayersHostile(bool bInPlayersHostile);

	/** Use ARPGTransientFX::SpawnForAll instead of calling this directly. */
	UFUNCTION(NetMulticast, Unreliable)
	void MulticastSpawnFX(FVector_NetQuantize Location, FRotator Rotation, const FRPGFXParams& Params, AActor* AttachTo);

	/** Adds "Killer defeated Victim" to every player's kill feed. Killer is null when the victim died to a bot or to itself. */
	UFUNCTION(NetMulticast, Reliable)
	void MulticastKillMessage(APlayerState* Killer, APlayerState* Victim);

private:
	UPROPERTY(Replicated)
	bool bPlayersHostile = true;
};
