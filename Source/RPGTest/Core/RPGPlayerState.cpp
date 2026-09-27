#include "Core/RPGPlayerState.h"

#include "Net/Core/PushModel/PushModel.h"
#include "Net/UnrealNetwork.h"

void ARPGPlayerState::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);

	FDoRepLifetimeParams Params;
	Params.bIsPushBased = true;
	DOREPLIFETIME_WITH_PARAMS_FAST(ARPGPlayerState, CharacterClassId, Params);
	DOREPLIFETIME_WITH_PARAMS_FAST(ARPGPlayerState, Kills, Params);
	DOREPLIFETIME_WITH_PARAMS_FAST(ARPGPlayerState, Deaths, Params);
	DOREPLIFETIME_WITH_PARAMS_FAST(ARPGPlayerState, RespawnTime, Params);
}

void ARPGPlayerState::SetCharacterClassId(FName InClassId)
{
	if (CharacterClassId != InClassId)
	{
		CharacterClassId = InClassId;
		MARK_PROPERTY_DIRTY_FROM_NAME(ARPGPlayerState, CharacterClassId, this);
	}
}

void ARPGPlayerState::AddKill()
{
	++Kills;
	MARK_PROPERTY_DIRTY_FROM_NAME(ARPGPlayerState, Kills, this);
}

void ARPGPlayerState::AddDeath()
{
	++Deaths;
	MARK_PROPERTY_DIRTY_FROM_NAME(ARPGPlayerState, Deaths, this);
}

void ARPGPlayerState::SetRespawnTime(double InRespawnTime)
{
	if (RespawnTime != InRespawnTime)
	{
		RespawnTime = InRespawnTime;
		MARK_PROPERTY_DIRTY_FROM_NAME(ARPGPlayerState, RespawnTime, this);
	}
}

void ARPGPlayerState::CopyProperties(APlayerState* PlayerState)
{
	Super::CopyProperties(PlayerState);

	// Keep the chosen class across seamless travel and reconnects.
	if (ARPGPlayerState* Other = Cast<ARPGPlayerState>(PlayerState))
	{
		Other->SetCharacterClassId(CharacterClassId);
	}
}
