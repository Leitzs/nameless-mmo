#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerState.h"
#include "RPGPlayerState.generated.h"

/** Per-player data every machine can see: chosen class, deathmatch score and respawn countdown. */
UCLASS()
class RPGTEST_API ARPGPlayerState : public APlayerState
{
	GENERATED_BODY()

public:
	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

	/** Id of an entry in URPGGameInstance::GetCharacterClasses(). */
	FName GetCharacterClassId() const { return CharacterClassId; }
	void SetCharacterClassId(FName InClassId);

	int32 GetKills() const { return Kills; }
	int32 GetDeaths() const { return Deaths; }
	void AddKill();
	void AddDeath();

	/** Server world time (AGameStateBase::GetServerWorldTimeSeconds) at which the player respawns; 0 when alive. */
	double GetRespawnTime() const { return RespawnTime; }
	void SetRespawnTime(double InRespawnTime);

protected:
	virtual void CopyProperties(APlayerState* PlayerState) override;

private:
	UPROPERTY(Replicated)
	FName CharacterClassId;

	UPROPERTY(Replicated)
	int32 Kills = 0;

	UPROPERTY(Replicated)
	int32 Deaths = 0;

	UPROPERTY(Replicated)
	double RespawnTime = 0.0;
};
