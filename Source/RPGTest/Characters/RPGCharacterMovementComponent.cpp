#include "Characters/RPGCharacterMovementComponent.h"

#include "Characters/RPGCharacterBase.h"

namespace RPGMovementPrivate
{
	constexpr uint8 SprintFlag = FSavedMove_Character::FLAG_Custom_0;
	constexpr uint8 CastSlowFlag = FSavedMove_Character::FLAG_Custom_1;
}

float URPGCharacterMovementComponent::GetMaxSpeed() const
{
	switch (MovementMode)
	{
	case MOVE_Walking:
	case MOVE_NavWalking:
	case MOVE_Falling:
		if (const ARPGCharacterBase* RPGCharacter = Cast<ARPGCharacterBase>(CharacterOwner))
		{
			return RPGCharacter->GetMoveSpeed();
		}
		break;
	default:
		break;
	}
	return Super::GetMaxSpeed();
}

void URPGCharacterMovementComponent::UpdateFromCompressedFlags(uint8 Flags)
{
	Super::UpdateFromCompressedFlags(Flags);

	bWantsToSprint = (Flags & RPGMovementPrivate::SprintFlag) != 0;
	bCastSlowed = (Flags & RPGMovementPrivate::CastSlowFlag) != 0;
}

FNetworkPredictionData_Client* URPGCharacterMovementComponent::GetPredictionData_Client() const
{
	if (!ClientPredictionData)
	{
		URPGCharacterMovementComponent* MutableThis = const_cast<URPGCharacterMovementComponent*>(this);
		MutableThis->ClientPredictionData = new FNetworkPredictionData_Client_RPGCharacter(*this);
	}
	return ClientPredictionData;
}

// ---------------------------------------------------------------------------------------------------------------------
// Saved move

void FSavedMove_RPGCharacter::Clear()
{
	Super::Clear();
	bSavedWantsToSprint = false;
	bSavedCastSlowed = false;
}

void FSavedMove_RPGCharacter::SetMoveFor(ACharacter* C, float InDeltaTime, FVector const& NewAccel, FNetworkPredictionData_Client_Character& ClientData)
{
	Super::SetMoveFor(C, InDeltaTime, NewAccel, ClientData);

	if (const URPGCharacterMovementComponent* Movement = Cast<URPGCharacterMovementComponent>(C->GetCharacterMovement()))
	{
		bSavedWantsToSprint = Movement->bWantsToSprint;
		bSavedCastSlowed = Movement->bCastSlowed;
	}
}

bool FSavedMove_RPGCharacter::CanCombineWith(const FSavedMovePtr& NewMove, ACharacter* InCharacter, float MaxDelta) const
{
	const FSavedMove_RPGCharacter* Other = static_cast<const FSavedMove_RPGCharacter*>(NewMove.Get());
	if (bSavedWantsToSprint != Other->bSavedWantsToSprint || bSavedCastSlowed != Other->bSavedCastSlowed)
	{
		return false;
	}
	return Super::CanCombineWith(NewMove, InCharacter, MaxDelta);
}

void FSavedMove_RPGCharacter::PrepMoveFor(ACharacter* C)
{
	Super::PrepMoveFor(C);

	if (URPGCharacterMovementComponent* Movement = Cast<URPGCharacterMovementComponent>(C->GetCharacterMovement()))
	{
		Movement->bWantsToSprint = bSavedWantsToSprint;
		Movement->bCastSlowed = bSavedCastSlowed;
	}
}

uint8 FSavedMove_RPGCharacter::GetCompressedFlags() const
{
	uint8 Flags = Super::GetCompressedFlags();
	if (bSavedWantsToSprint)
	{
		Flags |= RPGMovementPrivate::SprintFlag;
	}
	if (bSavedCastSlowed)
	{
		Flags |= RPGMovementPrivate::CastSlowFlag;
	}
	return Flags;
}

FSavedMovePtr FNetworkPredictionData_Client_RPGCharacter::AllocateNewMove()
{
	return MakeShared<FSavedMove_RPGCharacter>();
}
