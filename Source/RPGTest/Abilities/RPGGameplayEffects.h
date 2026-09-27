#pragma once

#include "CoreMinimal.h"
#include "GameplayEffect.h"
#include "GameplayEffectExecutionCalculation.h"
#include "RPGGameplayEffects.generated.h"

/*
 * A handful of generic, code-defined gameplay effects. Nothing gameplay-specific is baked in: amounts, durations,
 * granted tags and damage types are set on the effect spec when it is applied (set-by-caller magnitudes with the
 * Data.* tags, DynamicGrantedTags, dynamic asset tags). So a new spell or status rarely needs a new effect class.
 * The helpers that build these specs live in URPGCombatLibrary.
 */

/** Instant damage. Data.Damage is the base amount; the damage type is a Damage.* asset tag on the spec. */
UCLASS()
class RPGTEST_API URPGEffect_Damage : public UGameplayEffect
{
	GENERATED_BODY()

public:
	URPGEffect_Damage();
};

/** Instant healing of Data.Heal. */
UCLASS()
class RPGTEST_API URPGEffect_Heal : public UGameplayEffect
{
	GENERATED_BODY()

public:
	URPGEffect_Heal();
};

/** Instant change of the class resource by Data.Cost (negative to spend). Used as every ability's cost. */
UCLASS()
class RPGTEST_API URPGEffect_Cost : public UGameplayEffect
{
	GENERATED_BODY()

public:
	URPGEffect_Cost();
};

/** Lasts Data.Duration seconds and grants the tags put in the spec's DynamicGrantedTags (cooldowns, statuses). */
UCLASS()
class RPGTEST_API URPGEffect_Timed : public UGameplayEffect
{
	GENERATED_BODY()

public:
	URPGEffect_Timed();
};

/** Lasts until removed and grants the spec's DynamicGrantedTags (stealth, auras). */
UCLASS()
class RPGTEST_API URPGEffect_Infinite : public UGameplayEffect
{
	GENERATED_BODY()

public:
	URPGEffect_Infinite();
};

/** Lasts Data.Duration seconds and deals Data.Damage every TickInterval seconds (burns, poisons, curses). */
UCLASS()
class RPGTEST_API URPGEffect_DamageOverTime : public UGameplayEffect
{
	GENERATED_BODY()

public:
	URPGEffect_DamageOverTime();

	static constexpr float TickInterval = 0.5f;
};

/**
 * Turns Data.Damage into IncomingDamage, applying the combat rules that depend on both sides:
 * damage immunity (Divine Shield), reduced outgoing damage while shielded, and frontal blocking.
 */
UCLASS()
class RPGTEST_API URPGDamageExecution : public UGameplayEffectExecutionCalculation
{
	GENERATED_BODY()

public:
	virtual void Execute_Implementation(const FGameplayEffectCustomExecutionParameters& ExecutionParams, FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const override;

	/** Damage multiplier for attacks hitting a Trait.FrontalBlock character from the front. */
	static constexpr float FrontalBlockMultiplier = 0.85f;
};
