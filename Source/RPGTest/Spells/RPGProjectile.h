#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "GameplayTagContainer.h"
#include "Abilities/RPGStatusEffects.h"
#include "RPGProjectile.generated.h"

class UMaterialInstanceDynamic;
class UPointLightComponent;
class UProjectileMovementComponent;
class USphereComponent;
class UStaticMeshComponent;

/** What a projectile does when it lands: damage to the hit target, splash around it, and statuses on everyone damaged. */
USTRUCT(BlueprintType)
struct FRPGProjectilePayload
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Payload")
	float DirectDamage = 30.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Payload")
	float SplashDamage = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Payload")
	float SplashRadius = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Payload", meta = (Categories = "Damage"))
	FGameplayTag DamageType;

	/** Applied to every hostile the projectile damages. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Payload")
	TArray<FRPGStatusSpec> Statuses;
};

/**
 * Glowing projectile that bursts on impact, damaging the hit target and hostiles around it.
 * Spawned and resolved by the server. Clients get a replicated copy that flies with the same movement (and homing
 * target) for the visuals, never collides and never deals damage; the impact effect comes from the server.
 */
UCLASS()
class RPGTEST_API ARPGProjectile : public AActor
{
	GENERATED_BODY()

public:
	ARPGProjectile();

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;

	/** Call before FinishSpawning. MaxRange > 0 makes the projectile fizzle after flying that far. */
	void Configure(const FRPGProjectilePayload& InPayload, const FLinearColor& InColor, float Speed, float MaxRange = 0.f, float InVisualScale = 1.f);

	/** Curves towards Target with the given acceleration (cm/s^2). */
	void SetHomingTarget(AActor* Target, float Acceleration);

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void LifeSpanExpired() override;

	UFUNCTION()
	void OnRep_Homing();

	/** Seconds the projectile flies before fizzling (server), unless Configure was given a range. */
	UPROPERTY(EditAnywhere, Category = "Projectile", meta = (ClampMin = "0.1"))
	float MaxFlightTime = 2.f;

	UFUNCTION()
	void HandleHit(UPrimitiveComponent* HitComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp, FVector NormalImpulse, const FHitResult& Hit);

	void Explode(const FVector& Location, AActor* DirectHitActor);

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<USphereComponent> Collision;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UProjectileMovementComponent> Movement;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UStaticMeshComponent> Core;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UStaticMeshComponent> Glow;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UPointLightComponent> Light;

	UPROPERTY(EditAnywhere, Category = "Projectile")
	FRPGProjectilePayload Payload;

	UPROPERTY(EditAnywhere, Replicated, Category = "Projectile")
	FLinearColor Color = FLinearColor(1.f, 0.4f, 0.08f);

	/** Size of the glowing core and trail. */
	UPROPERTY(EditAnywhere, Replicated, Category = "Projectile")
	float VisualScale = 1.f;

	/** Seconds between trail sparks. */
	UPROPERTY(EditAnywhere, Category = "Projectile")
	float TrailInterval = 0.03f;

private:
	void ApplyHoming();

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> CoreMaterial;

	UPROPERTY(ReplicatedUsing = OnRep_Homing)
	TObjectPtr<AActor> HomingTarget;

	UPROPERTY(ReplicatedUsing = OnRep_Homing)
	float HomingAcceleration = 0.f;

	bool bExploded = false;
	float TrailAccumulator = 0.f;
};
