#pragma once

#include "CoreMinimal.h"
#include "Characters/RPGCharacterBase.h"
#include "RPGPlayerCharacter.generated.h"

class UCameraComponent;
class URPGCharacterMovementComponent;
class USpringArmComponent;

/**
 * Base for every playable class: third-person free-orbit camera, crosshair aiming with soft target lock,
 * sprint and the ability hotbar (left mouse + keys 1-5, see ARPGCharacterBase::AbilityClasses). A class (Mage, ...)
 * derives from it and only sets its abilities, stats and look. Classes are listed in URPGGameInstance.
 */
UCLASS(Abstract)
class RPGTEST_API ARPGPlayerCharacter : public ARPGCharacterBase
{
	GENERATED_BODY()

public:
	explicit ARPGPlayerCharacter(const FObjectInitializer& ObjectInitializer);

	virtual void Tick(float DeltaSeconds) override;

	// Input entry points, called by the player controller.
	void Move(const FVector2D& Axis);
	void Look(const FVector2D& Axis);
	void Zoom(float Axis);
	void SetSprinting(bool bInSprinting);
	/** Uses the ability in a hotbar slot: 0 = basic attack, 1-5 = number keys. */
	ERPGCastResult UseAbility(int32 Slot);

	URPGCharacterMovementComponent* GetRPGMovement() const;
	bool IsSprinting() const;

	virtual void ComputeAim(float MaxRange, FVector& OutAimLocation, ARPGCharacterBase*& OutTarget) const override;

protected:
	virtual void BeginPlay() override;
	virtual bool CanJumpInternal_Implementation() const override;
	virtual float GetDesiredMoveSpeed() const override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USpringArmComponent> CameraBoom;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UCameraComponent> FollowCamera;

	UPROPERTY(EditAnywhere, Category = "Camera", meta = (ClampMin = "100"))
	float MinZoom = 250.f;

	UPROPERTY(EditAnywhere, Category = "Camera", meta = (ClampMin = "100"))
	float MaxZoom = 950.f;

	UPROPERTY(EditAnywhere, Category = "Camera", meta = (ClampMin = "1"))
	float ZoomStep = 70.f;

	UPROPERTY(EditAnywhere, Category = "Camera", meta = (ClampMin = "0.01"))
	float LookSensitivity = 1.f;

	UPROPERTY(EditAnywhere, Category = "Camera")
	bool bInvertLookY = false;

	UPROPERTY(EditAnywhere, Category = "RPG|Movement", meta = (ClampMin = "0"))
	float SprintSpeed = 760.f;

	/** Movement speed multiplier while a cast is in progress. */
	UPROPERTY(EditAnywhere, Category = "RPG|Movement", meta = (ClampMin = "0", ClampMax = "1"))
	float CastingSpeedMultiplier = 0.4f;

	/** Radius of the sweep along the crosshair ray used to soft-lock enemies. */
	UPROPERTY(EditAnywhere, Category = "RPG|Combat", meta = (ClampMin = "0"))
	float AimAssistRadius = 90.f;

private:
	float DesiredArmLength = 550.f;
};
