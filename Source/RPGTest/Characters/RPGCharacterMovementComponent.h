#pragma once

#include "CoreMinimal.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "RPGCharacterMovementComponent.generated.h"

/**
 * Character movement with client-predicted sprint and "casting" slow-down.
 * Both wishes travel inside every saved move (compressed flags), so the server simulates the same speed as the
 * owning client and does not send corrections when the player starts or stops sprinting or casting.
 * The speed itself comes from ARPGCharacterBase::GetMoveSpeed (status effects, class speeds, death).
 */
UCLASS()
class RPGTEST_API URPGCharacterMovementComponent : public UCharacterMovementComponent
{
	GENERATED_BODY()

public:
	virtual float GetMaxSpeed() const override;
	virtual void UpdateFromCompressedFlags(uint8 Flags) override;
	virtual FNetworkPredictionData_Client* GetPredictionData_Client() const override;

	void SetWantsToSprint(bool bInWantsToSprint) { bWantsToSprint = bInWantsToSprint; }
	bool WantsToSprint() const { return bWantsToSprint; }

	void SetCastSlowed(bool bInCastSlowed) { bCastSlowed = bInCastSlowed; }
	bool IsCastSlowed() const { return bCastSlowed; }

	uint8 bWantsToSprint : 1 = false;
	uint8 bCastSlowed : 1 = false;
};

class FSavedMove_RPGCharacter : public FSavedMove_Character
{
public:
	using Super = FSavedMove_Character;

	virtual void Clear() override;
	virtual void SetMoveFor(ACharacter* C, float InDeltaTime, FVector const& NewAccel, FNetworkPredictionData_Client_Character& ClientData) override;
	virtual bool CanCombineWith(const FSavedMovePtr& NewMove, ACharacter* InCharacter, float MaxDelta) const override;
	virtual void PrepMoveFor(ACharacter* C) override;
	virtual uint8 GetCompressedFlags() const override;

	uint8 bSavedWantsToSprint : 1 = false;
	uint8 bSavedCastSlowed : 1 = false;
};

class FNetworkPredictionData_Client_RPGCharacter : public FNetworkPredictionData_Client_Character
{
public:
	using Super = FNetworkPredictionData_Client_Character;

	explicit FNetworkPredictionData_Client_RPGCharacter(const UCharacterMovementComponent& ClientMovement) : Super(ClientMovement) {}

	virtual FSavedMovePtr AllocateNewMove() override;
};
