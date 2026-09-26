#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RPGProjectile.generated.h"

class UDamageType;
class UMaterialInstanceDynamic;
class UPointLightComponent;
class UProjectileMovementComponent;
class USphereComponent;
class UStaticMeshComponent;

/** Damage payload carried by a projectile. */
USTRUCT(BlueprintType)
struct FRPGProjectileDamage
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Damage")
	float DirectDamage = 30.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Damage")
	float SplashDamage = 10.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Damage")
	float SplashRadius = 250.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Damage")
	float BurnDamagePerSecond = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Damage")
	float BurnDuration = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Damage")
	TSubclassOf<UDamageType> DamageType;
};

/** Glowing spell projectile that explodes on impact, damaging the hit target and hostiles around it. */
UCLASS()
class RPGTEST_API ARPGProjectile : public AActor
{
	GENERATED_BODY()

public:
	ARPGProjectile();

	/** Call before FinishSpawning. */
	void Configure(const FRPGProjectileDamage& InDamage, const FLinearColor& InColor, float Speed);

	/** Curves towards Target with the given acceleration (cm/s^2). */
	void SetHomingTarget(AActor* Target, float Acceleration);

protected:
	virtual void BeginPlay() override;
	virtual void Tick(float DeltaSeconds) override;
	virtual void LifeSpanExpired() override;

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
	FRPGProjectileDamage Damage;

	UPROPERTY(EditAnywhere, Category = "Projectile")
	FLinearColor Color = FLinearColor(1.f, 0.4f, 0.08f);

	/** Seconds between trail sparks. */
	UPROPERTY(EditAnywhere, Category = "Projectile")
	float TrailInterval = 0.03f;

private:
	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> CoreMaterial;

	bool bExploded = false;
	float TrailAccumulator = 0.f;
};
