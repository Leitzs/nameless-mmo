#pragma once

#include "CoreMinimal.h"
#include "Abilities/RPGGameplayAbility.h"
#include "Abilities/RPGStatusEffects.h"
#include "Spells/RPGProjectile.h"
#include "RPGAbilityArchetypes.generated.h"

/*
 * Reusable ability shapes. A class kit mostly consists of subclasses of these that only fill in numbers, colors and
 * statuses in their constructor; bespoke abilities (dashes, channels, teleports) derive from URPGGameplayAbility.
 */

/** Fires a projectile at the crosshair (homing on the soft-locked target). Bolts, fireballs, thrown weapons. */
UCLASS(Abstract)
class RPGTEST_API URPGAbility_Projectile : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	URPGAbility_Projectile();

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	UPROPERTY(EditDefaultsOnly, Category = "Projectile")
	FRPGProjectilePayload Payload;

	UPROPERTY(EditDefaultsOnly, Category = "Projectile", meta = (ClampMin = "100"))
	float ProjectileSpeed = 2800.f;

	/** Steering towards a soft-locked target, in cm/s^2. 0 flies straight. */
	UPROPERTY(EditDefaultsOnly, Category = "Projectile", meta = (ClampMin = "0"))
	float HomingAcceleration = 6000.f;

	UPROPERTY(EditDefaultsOnly, Category = "Projectile", meta = (ClampMin = "0.1"))
	float VisualScale = 1.f;
};

/**
 * A weapon swing in front of the caster. Hits the soft-locked target (or the closest enemy in the arc), or everyone
 * in the arc when bHitAllInArc. Supports bonus damage from behind and from stealth, statuses and resource on hit.
 */
UCLASS(Abstract)
class RPGTEST_API URPGAbility_MeleeStrike : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	URPGAbility_MeleeStrike();

	virtual void ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData) override;

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	/** Called on the server for every enemy the swing damaged. */
	virtual void OnStrikeHit(const FRPGSpellContext& Context, ARPGCharacterBase* Target) {}

	/** Constructor helper: adds an animation to the combo, played in turn by consecutive swings. */
	void AddComboAnimation(const TCHAR* AnimationPath);

	UPROPERTY(EditDefaultsOnly, Category = "Melee")
	TArray<TObjectPtr<UAnimSequenceBase>> ComboAnimations;

	UPROPERTY(EditDefaultsOnly, Category = "Melee", meta = (ClampMin = "0"))
	float Damage = 15.f;

	UPROPERTY(EditDefaultsOnly, Category = "Melee", meta = (Categories = "Damage"))
	FGameplayTag DamageType;

	/** Reach from the caster's center to the target's capsule edge. */
	UPROPERTY(EditDefaultsOnly, Category = "Melee", meta = (ClampMin = "0"))
	float Reach = 200.f;

	UPROPERTY(EditDefaultsOnly, Category = "Melee", meta = (ClampMin = "0", ClampMax = "360"))
	float ArcDegrees = 110.f;

	UPROPERTY(EditDefaultsOnly, Category = "Melee")
	bool bHitAllInArc = false;

	/** Damage multiplier when striking the target's back. */
	UPROPERTY(EditDefaultsOnly, Category = "Melee", meta = (ClampMin = "1"))
	float BehindDamageMultiplier = 1.f;

	UPROPERTY(EditDefaultsOnly, Category = "Melee")
	TArray<FRPGStatusSpec> Statuses;

	/** Class resource gained when the swing connects (rage, mana...). */
	UPROPERTY(EditDefaultsOnly, Category = "Melee")
	float ResourceOnHit = 0.f;

	UPROPERTY(EditDefaultsOnly, Category = "Melee", meta = (ClampMin = "0"))
	float Knockback = 0.f;

private:
	int32 ComboIndex = 0;
};

/** Buffs the caster: removes statuses, applies statuses, heals, shields. Shields, cleanses, sprints, heals. */
UCLASS(Abstract)
class RPGTEST_API URPGAbility_SelfBuff : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	URPGAbility_SelfBuff();

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	/** Removed first (children included), so a cleanse can be followed by an immunity. */
	UPROPERTY(EditDefaultsOnly, Category = "Buff", meta = (Categories = "Status"))
	FGameplayTagContainer RemoveStatuses;

	UPROPERTY(EditDefaultsOnly, Category = "Buff")
	TArray<FRPGStatusSpec> Statuses;

	UPROPERTY(EditDefaultsOnly, Category = "Buff", meta = (ClampMin = "0"))
	float HealAmount = 0.f;

	UPROPERTY(EditDefaultsOnly, Category = "Buff", meta = (ClampMin = "0"))
	float ShieldAmount = 0.f;

	UPROPERTY(EditDefaultsOnly, Category = "Buff", meta = (ClampMin = "0"))
	float ShieldDuration = 0.f;
};

/** Instantly afflicts the soft-locked enemy (needs line of sight): curses, fears. */
UCLASS(Abstract)
class RPGTEST_API URPGAbility_TargetedDebuff : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	URPGAbility_TargetedDebuff();

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	UPROPERTY(EditDefaultsOnly, Category = "Debuff", meta = (ClampMin = "0"))
	float Damage = 0.f;

	UPROPERTY(EditDefaultsOnly, Category = "Debuff", meta = (Categories = "Damage"))
	FGameplayTag DamageType;

	UPROPERTY(EditDefaultsOnly, Category = "Debuff")
	TArray<FRPGStatusSpec> Statuses;
};

/** Burst around the caster that hits every enemy within Radius: frost novas, whirlwinds. */
UCLASS(Abstract)
class RPGTEST_API URPGAbility_Nova : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	URPGAbility_Nova();

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	/** Called on the server for every enemy the nova damaged. */
	virtual void OnNovaHit(const FRPGSpellContext& Context, ARPGCharacterBase* Target) {}

	UPROPERTY(EditDefaultsOnly, Category = "Nova", meta = (ClampMin = "0"))
	float Radius = 500.f;

	UPROPERTY(EditDefaultsOnly, Category = "Nova", meta = (ClampMin = "0"))
	float Damage = 20.f;

	UPROPERTY(EditDefaultsOnly, Category = "Nova", meta = (Categories = "Damage"))
	FGameplayTag DamageType;

	UPROPERTY(EditDefaultsOnly, Category = "Nova")
	TArray<FRPGStatusSpec> Statuses;

	UPROPERTY(EditDefaultsOnly, Category = "Nova", meta = (ClampMin = "0"))
	float Knockback = 0.f;
};

namespace RPGAbilityFX
{
	/** Feet of a character (bottom of its capsule). */
	RPGTEST_API FVector GetFeetLocation(const ARPGCharacterBase& Character);

	/** A short glowing streak between two points (beams, thrown curses). */
	RPGTEST_API void SpawnBeam(const AActor* WorldContext, const FVector& From, const FVector& To, const FLinearColor& Color, float Lifetime, float Thickness = 0.12f);

	/** A burst of light on a character (hit sparks, buff flashes). */
	RPGTEST_API void SpawnBurst(const AActor* WorldContext, const FVector& Location, const FLinearColor& Color, float Size, AActor* AttachTo = nullptr);

	/** An expanding ring on the ground around a character. */
	RPGTEST_API void SpawnGroundRing(const ARPGCharacterBase& Character, const FLinearColor& Color, float Radius);
}
