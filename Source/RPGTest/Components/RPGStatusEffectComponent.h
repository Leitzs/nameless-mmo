#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "RPGStatusEffectComponent.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FRPGOnStatusChanged);

/**
 * Timed crowd-control and damage-over-time effects: slow, freeze (root + paused animation),
 * stun and burn. The owning character reads the state to limit movement and actions.
 */
UCLASS(ClassGroup = (RPG), meta = (BlueprintSpawnableComponent))
class RPGTEST_API URPGStatusEffectComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	URPGStatusEffectComponent();

	/** Multiplies movement speed by SpeedMultiplier for Duration seconds. The strongest active slow wins. */
	UFUNCTION(BlueprintCallable, Category = "Status")
	void ApplySlow(float SpeedMultiplier, float Duration);

	UFUNCTION(BlueprintCallable, Category = "Status")
	void ApplyFreeze(float Duration);

	UFUNCTION(BlueprintCallable, Category = "Status")
	void ApplyStun(float Duration);

	/** Deals DamagePerSecond as fire damage, in half-second ticks, for Duration seconds. Refreshes an existing burn. */
	UFUNCTION(BlueprintCallable, Category = "Status")
	void ApplyBurn(float DamagePerSecond, float Duration, AController* InstigatorController, AActor* DamageCauser);

	UFUNCTION(BlueprintCallable, Category = "Status")
	void ClearAll();

	UFUNCTION(BlueprintPure, Category = "Status")
	bool IsSlowed() const { return SlowRemaining > 0.f; }

	UFUNCTION(BlueprintPure, Category = "Status")
	bool IsFrozen() const { return FreezeRemaining > 0.f; }

	UFUNCTION(BlueprintPure, Category = "Status")
	bool IsStunned() const { return StunRemaining > 0.f; }

	UFUNCTION(BlueprintPure, Category = "Status")
	bool IsBurning() const { return BurnRemaining > 0.f; }

	/** Frozen or stunned: cannot move, cast or attack. */
	UFUNCTION(BlueprintPure, Category = "Status")
	bool IsIncapacitated() const { return IsFrozen() || IsStunned(); }

	/** 0 while incapacitated, otherwise the active slow multiplier (1 when not slowed). */
	UFUNCTION(BlueprintPure, Category = "Status")
	float GetSpeedMultiplier() const;

	/** Fired whenever an effect starts or ends. */
	UPROPERTY(BlueprintAssignable, Category = "Status")
	FRPGOnStatusChanged OnStatusChanged;

protected:
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
	/** Counts a timer down and reports whether it just expired. */
	static bool TickTimer(float& Remaining, float DeltaTime);

	float SlowRemaining = 0.f;
	float SlowMultiplier = 1.f;
	float FreezeRemaining = 0.f;
	float StunRemaining = 0.f;

	float BurnRemaining = 0.f;
	float BurnDamagePerSecond = 0.f;
	float BurnTickAccumulator = 0.f;
	TWeakObjectPtr<AController> BurnInstigator;
	TWeakObjectPtr<AActor> BurnCauser;
};
