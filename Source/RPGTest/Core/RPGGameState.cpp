#include "Core/RPGGameState.h"

#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerState.h"
#include "Net/Core/PushModel/PushModel.h"
#include "Net/UnrealNetwork.h"
#include "UI/RPGHUD.h"

ARPGGameState::ARPGGameState()
{
	// Kill feed and spell effects should arrive quickly even when nothing else changes.
	SetNetUpdateFrequency(30.f);
}

void ARPGGameState::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);

	FDoRepLifetimeParams Params;
	Params.bIsPushBased = true;
	DOREPLIFETIME_WITH_PARAMS_FAST(ARPGGameState, bPlayersHostile, Params);
}

void ARPGGameState::SetPlayersHostile(bool bInPlayersHostile)
{
	if (bPlayersHostile != bInPlayersHostile)
	{
		bPlayersHostile = bInPlayersHostile;
		MARK_PROPERTY_DIRTY_FROM_NAME(ARPGGameState, bPlayersHostile, this);
	}
}

void ARPGGameState::MulticastSpawnFX_Implementation(FVector_NetQuantize Location, FRotator Rotation, const FRPGFXParams& Params, AActor* AttachTo)
{
	ARPGTransientFX::Spawn(this, Location, Rotation, Params, AttachTo);
}

void ARPGGameState::MulticastKillMessage_Implementation(APlayerState* Killer, APlayerState* Victim)
{
	const UWorld* World = GetWorld();
	const APlayerController* LocalController = World ? World->GetFirstPlayerController() : nullptr;
	ARPGHUD* HUD = LocalController ? LocalController->GetHUD<ARPGHUD>() : nullptr;
	if (!HUD || !Victim)
	{
		return;
	}

	const bool bLocalInvolved = LocalController->PlayerState == Killer || LocalController->PlayerState == Victim;
	HUD->AddKillMessage(Killer ? Killer->GetPlayerName() : FString(), Victim->GetPlayerName(), bLocalInvolved);
}
