#pragma once

#include "CoreMinimal.h"
#include "Spells/RPGAbilityArchetypes.h"
#include "ArcherSpells.generated.h"

/** [LMB] Quick Shot: free, fast arrow that can be fired on the move. */
UCLASS()
class RPGTEST_API USpell_QuickShot : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_QuickShot();
};

/** [1] Aimed Shot: a slow, carefully drawn arrow that hits very hard. */
UCLASS()
class RPGTEST_API USpell_AimedShot : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_AimedShot();
};

/** [2] Multi-Shot: a fan of arrows; the middle one homes on the target, the others fly straight. */
UCLASS()
class RPGTEST_API USpell_MultiShot : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_MultiShot();

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	UPROPERTY(EditDefaultsOnly, Category = "Multi-Shot", meta = (ClampMin = "1"))
	int32 ArrowCount = 3;

	/** Angle between two neighboring arrows. */
	UPROPERTY(EditDefaultsOnly, Category = "Multi-Shot", meta = (ClampMin = "0"))
	float SpreadDegrees = 12.f;
};

/** [3] Concussive Shot: an arrow that dazes the target, slowing it heavily. */
UCLASS()
class RPGTEST_API USpell_ConcussiveShot : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_ConcussiveShot();
};

/** [4] Disengage: leap backwards, away from where you are aiming (client-predicted root motion). */
UCLASS()
class RPGTEST_API USpell_Disengage : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	USpell_Disengage();

	virtual ERPGCastResult CheckCasterState(const ARPGCharacterBase& Caster) const override;

protected:
	virtual void OnRelease(const FRPGSpellContext& Context) override;

	UFUNCTION()
	void OnLeapFinished();

	UPROPERTY(EditDefaultsOnly, Category = "Disengage", meta = (ClampMin = "100"))
	float LeapDistance = 850.f;

	UPROPERTY(EditDefaultsOnly, Category = "Disengage", meta = (ClampMin = "0.05"))
	float LeapDuration = 0.35f;
};

/** [5] Rain of Arrows: after a short warning, arrows rain down on an area, damaging and slowing everyone inside. */
UCLASS()
class RPGTEST_API USpell_RainOfArrows : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	USpell_RainOfArrows();

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	UPROPERTY(EditDefaultsOnly, Category = "Rain of Arrows", meta = (ClampMin = "0"))
	float Damage = 35.f;

	UPROPERTY(EditDefaultsOnly, Category = "Rain of Arrows", meta = (ClampMin = "0"))
	float Radius = 350.f;

	/** Warning time before the arrows land: enough to step out of the circle. */
	UPROPERTY(EditDefaultsOnly, Category = "Rain of Arrows", meta = (ClampMin = "0"))
	float Delay = 0.9f;

	UPROPERTY(EditDefaultsOnly, Category = "Rain of Arrows", meta = (ClampMin = "0"))
	float SlowDuration = 3.f;

	/** Speed multiplier while slowed. */
	UPROPERTY(EditDefaultsOnly, Category = "Rain of Arrows", meta = (ClampMin = "0", ClampMax = "1"))
	float SlowMultiplier = 0.7f;
};
