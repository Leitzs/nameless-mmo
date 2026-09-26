#pragma once

#include "CoreMinimal.h"
#include "Characters/RPGCharacterBase.h"
#include "MageCharacter.generated.h"

class UCameraComponent;
class UPointLightComponent;
class URPGSpellbookComponent;
class USpringArmComponent;

/**
 * The player's Mage: third-person free-orbit camera, crosshair aiming with soft target lock,
 * and five spells on the hotbar (keys 1-5).
 */
UCLASS()
class RPGTEST_API AMageCharacter : public ARPGCharacterBase
{
	GENERATED_BODY()

public:
	AMageCharacter();

	virtual void Tick(float DeltaSeconds) override;

	// Input entry points, called by the player controller.
	void Move(const FVector2D& Axis);
	void Look(const FVector2D& Axis);
	void Zoom(float Axis);
	void SetSprinting(bool bInSprinting) { bSprinting = bInSprinting; }
	ERPGCastResult CastSpell(int32 SlotIndex);

	URPGSpellbookComponent* GetSpellbook() const { return Spellbook; }
	bool IsSprinting() const { return bSprinting; }

	virtual FVector GetSpellOrigin() const override;
	virtual void ComputeAim(float MaxRange, FVector& OutAimLocation, ARPGCharacterBase*& OutTarget) const override;

protected:
	virtual void BeginPlay() override;
	virtual bool CanJumpInternal_Implementation() const override;
	virtual float GetDesiredMoveSpeed() const override;
	virtual void HandleDeath(AActor* Killer) override;
	virtual void AlignCosmetics() override;
	virtual void ApplyCosmeticMaterials() override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<USpringArmComponent> CameraBoom;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UCameraComponent> FollowCamera;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<URPGSpellbookComponent> Spellbook;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> HatCone;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> HatBrim;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> HatBand;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> StaffShaft;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> StaffOrb;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UPointLightComponent> StaffLight;

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
	bool bSprinting = false;
};
