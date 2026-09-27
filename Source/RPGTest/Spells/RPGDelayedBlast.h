#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "GameplayTagContainer.h"
#include "Abilities/RPGStatusEffects.h"
#include "RPGDelayedBlast.generated.h"

class ARPGCharacterBase;
class UMaterialInstanceDynamic;
class UStaticMeshComponent;

/**
 * Telegraphed area strike: shows a warning circle on the ground, then after a delay calls down a bolt
 * that damages hostiles inside the circle and applies a status (a stun, for Lightning Strike). Can track a target until it detonates.
 * The server detonates it; clients get a replicated copy that draws the warning circle and follows the same target.
 */
UCLASS(NotPlaceable)
class RPGTEST_API ARPGDelayedBlast : public AActor
{
	GENERATED_BODY()

public:
	ARPGDelayedBlast();

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

	/** Call before FinishSpawning. The instigator (spawn parameter) is the caster. */
	void Configure(float InDelay, float InRadius, float InDamage, const FGameplayTag& InDamageType, const FRPGStatusSpec& InStatus, const FLinearColor& InColor, ARPGCharacterBase* InTrackedTarget);

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;

private:
	void Detonate();
	void SnapToGround();

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UStaticMeshComponent> Marker;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> MarkerMaterial;

	UPROPERTY(Replicated)
	TObjectPtr<ARPGCharacterBase> TrackedTarget;

	UPROPERTY(Replicated)
	FLinearColor Color = FLinearColor(0.7f, 0.8f, 1.f);

	UPROPERTY(Replicated)
	float Delay = 0.5f;

	UPROPERTY(Replicated)
	float Radius = 250.f;

	FGameplayTag DamageType;
	FRPGStatusSpec Status;
	float Damage = 50.f;
	float Age = 0.f;
	FTimerHandle DetonateTimer;
};
