#pragma once

#include "CoreMinimal.h"
#include "Spells/RPGAbilityArchetypes.h"
#include "WarlockSpells.generated.h"

/** [LMB] Fel Bolt: free, quick bolt of fel fire. */
UCLASS()
class RPGTEST_API USpell_FelBolt : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_FelBolt();
};

/** [1] Shadow Bolt: long wind-up, slow, heavy-hitting projectile. */
UCLASS()
class RPGTEST_API USpell_ShadowBolt : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_ShadowBolt();
};

/** [2] Corruption: instant curse that deals shadow damage over time. Also keeps rogues from vanishing. */
UCLASS()
class RPGTEST_API USpell_Corruption : public URPGAbility_TargetedDebuff
{
	GENERATED_BODY()

public:
	USpell_Corruption();
};

/**
 * [3] Drain Life: channeled beam that damages the target and heals the caster for the damage dealt.
 * Breaks when the caster is interrupted, or the target dies, leaves the range or goes out of sight.
 */
UCLASS()
class RPGTEST_API USpell_DrainLife : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	USpell_DrainLife();

	virtual void EndAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo, bool bReplicateEndAbility, bool bWasCancelled) override;

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	UPROPERTY(EditDefaultsOnly, Category = "Drain Life", meta = (ClampMin = "0.1"))
	float ChannelDuration = 3.f;

	UPROPERTY(EditDefaultsOnly, Category = "Drain Life", meta = (ClampMin = "0.1"))
	float TickInterval = 0.5f;

	UPROPERTY(EditDefaultsOnly, Category = "Drain Life", meta = (ClampMin = "0"))
	float DamagePerTick = 9.f;

	/** Fraction of the damage dealt that heals the caster. */
	UPROPERTY(EditDefaultsOnly, Category = "Drain Life", meta = (ClampMin = "0"))
	float HealFraction = 1.f;

private:
	void DrainTick();

	TWeakObjectPtr<ARPGCharacterBase> DrainTarget;
	FTimerHandle DrainTimer;
	int32 TicksLeft = 0;
};

/** [4] Fear: the target flees in panic for a few seconds; enough damage breaks it. */
UCLASS()
class RPGTEST_API USpell_Fear : public URPGAbility_TargetedDebuff
{
	GENERATED_BODY()

public:
	USpell_Fear();
};

/**
 * [5] Demonic Circle: first use leaves a circle at your feet; the next use teleports you back to it (and consumes it).
 * Placing has a short cooldown, returning a long one. Too far from the circle, the ability places a new one instead.
 */
UCLASS()
class RPGTEST_API USpell_DemonicCircle : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	USpell_DemonicCircle();

	virtual FText GetSlotLabel(const ARPGCharacterBase& Caster) const override;
	virtual float GetCooldownDuration(const ARPGCharacterBase* Caster) const override;

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	bool CanReturn(const ARPGCharacterBase* Caster) const;

	UPROPERTY(EditDefaultsOnly, Category = "Demonic Circle", meta = (ClampMin = "0"))
	float PlaceCooldown = 3.f;

	UPROPERTY(EditDefaultsOnly, Category = "Demonic Circle", meta = (ClampMin = "0"))
	float ReturnCooldown = 20.f;

	UPROPERTY(EditDefaultsOnly, Category = "Demonic Circle", meta = (ClampMin = "100"))
	float MaxReturnDistance = 6000.f;
};
