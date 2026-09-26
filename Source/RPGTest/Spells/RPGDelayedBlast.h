#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RPGDelayedBlast.generated.h"

class ARPGCharacterBase;
class UDamageType;
class UMaterialInstanceDynamic;
class UStaticMeshComponent;

/**
 * Telegraphed area strike: shows a warning circle on the ground, then after a delay calls down a bolt
 * that damages and stuns hostiles inside the circle. Can track a target until it detonates.
 */
UCLASS(NotPlaceable)
class RPGTEST_API ARPGDelayedBlast : public AActor
{
	GENERATED_BODY()

public:
	ARPGDelayedBlast();

	/** Call before FinishSpawning. The instigator (spawn parameter) is the caster. */
	void Configure(float InDelay, float InRadius, float InDamage, TSubclassOf<UDamageType> InDamageType, float InStunDuration, const FLinearColor& InColor, ARPGCharacterBase* InTrackedTarget);

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

	TWeakObjectPtr<ARPGCharacterBase> TrackedTarget;
	TSubclassOf<UDamageType> DamageType;
	FLinearColor Color = FLinearColor(0.7f, 0.8f, 1.f);
	float Delay = 0.5f;
	float Radius = 250.f;
	float Damage = 50.f;
	float StunDuration = 0.5f;
	float Age = 0.f;
	FTimerHandle DetonateTimer;
};
