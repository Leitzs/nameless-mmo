#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "RPGAttributeComponent.generated.h"

class URPGAttributeComponent;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_FourParams(FRPGOnDamaged, URPGAttributeComponent*, Attributes, float, HealthDamage, float, AbsorbedDamage, AActor*, InstigatorActor);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FRPGOnDeath, AActor*, Killer);

/** Health, mana and damage-absorbing shield for a character. */
UCLASS(ClassGroup = (RPG), meta = (BlueprintSpawnableComponent))
class RPGTEST_API URPGAttributeComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	URPGAttributeComponent();

	/** Sets the base values. Intended for owner constructors; runtime values reset in BeginPlay. */
	void SetDefaults(float InMaxHealth, float InMaxMana, float InHealthRegen, float InManaRegen);

	/** Applies damage, shield first. Returns the health actually lost. */
	UFUNCTION(BlueprintCallable, Category = "Attributes")
	float ApplyDamage(float Amount, AActor* InstigatorActor);

	UFUNCTION(BlueprintCallable, Category = "Attributes")
	void Heal(float Amount);

	/** Spends mana if there is enough. Returns false and spends nothing otherwise. */
	UFUNCTION(BlueprintCallable, Category = "Attributes")
	bool TryConsumeMana(float Amount);

	UFUNCTION(BlueprintCallable, Category = "Attributes")
	void AddShield(float Amount, float Duration);

	UFUNCTION(BlueprintCallable, Category = "Attributes")
	void RestoreAll();

	/** Prevents health from dropping below 1 (debug "god mode"). */
	void SetInvulnerable(bool bInInvulnerable) { bInvulnerable = bInInvulnerable; }
	bool IsInvulnerable() const { return bInvulnerable; }

	UFUNCTION(BlueprintPure, Category = "Attributes")
	bool IsAlive() const { return Health > 0.f; }

	UFUNCTION(BlueprintPure, Category = "Attributes")
	float GetHealth() const { return Health; }

	UFUNCTION(BlueprintPure, Category = "Attributes")
	float GetMaxHealth() const { return MaxHealth; }

	UFUNCTION(BlueprintPure, Category = "Attributes")
	float GetMana() const { return Mana; }

	UFUNCTION(BlueprintPure, Category = "Attributes")
	float GetMaxMana() const { return MaxMana; }

	UFUNCTION(BlueprintPure, Category = "Attributes")
	float GetShield() const { return Shield; }

	float GetShieldTimeRemaining() const { return ShieldTimeRemaining; }
	bool IsInCombat() const;

	UPROPERTY(BlueprintAssignable, Category = "Attributes")
	FRPGOnDamaged OnDamaged;

	UPROPERTY(BlueprintAssignable, Category = "Attributes")
	FRPGOnDeath OnDeath;

protected:
	virtual void BeginPlay() override;
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	UPROPERTY(EditAnywhere, Category = "Attributes", meta = (ClampMin = "1"))
	float MaxHealth = 300.f;

	UPROPERTY(EditAnywhere, Category = "Attributes", meta = (ClampMin = "0"))
	float MaxMana = 0.f;

	/** Health regained per second while out of combat. */
	UPROPERTY(EditAnywhere, Category = "Attributes", meta = (ClampMin = "0"))
	float HealthRegen = 3.f;

	/** Mana regained per second, always. */
	UPROPERTY(EditAnywhere, Category = "Attributes", meta = (ClampMin = "0"))
	float ManaRegen = 0.f;

	/** Seconds without taking damage before health regeneration starts. */
	UPROPERTY(EditAnywhere, Category = "Attributes", meta = (ClampMin = "0"))
	float OutOfCombatDelay = 6.f;

private:
	UPROPERTY(VisibleInstanceOnly, Category = "Attributes")
	float Health = 0.f;

	UPROPERTY(VisibleInstanceOnly, Category = "Attributes")
	float Mana = 0.f;

	UPROPERTY(VisibleInstanceOnly, Category = "Attributes")
	float Shield = 0.f;

	float ShieldTimeRemaining = 0.f;
	double LastDamageTime = -1000.0;
	bool bInvulnerable = false;
};
