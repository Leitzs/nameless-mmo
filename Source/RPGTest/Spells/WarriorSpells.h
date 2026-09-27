#pragma once

#include "CoreMinimal.h"
#include "Spells/RPGAbilityArchetypes.h"
#include "WarriorSpells.generated.h"

/** [LMB] Sword Slash: heavy sword combo that builds rage. */
UCLASS()
class RPGTEST_API USpell_SwordSlash : public URPGAbility_MeleeStrike
{
	GENERATED_BODY()

public:
	USpell_SwordSlash();
};

/**
 * [1] Charge: rush to the target (client-predicted root motion), rooting it briefly on arrival and generating rage.
 * Needs some distance to build up speed.
 */
UCLASS()
class RPGTEST_API USpell_Charge : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	USpell_Charge();

	virtual ERPGCastResult CheckCasterState(const ARPGCharacterBase& Caster) const override;
	virtual ERPGCastResult CheckTarget(const ARPGCharacterBase& Caster, const ARPGCharacterBase& Target) const override;

protected:
	virtual void OnRelease(const FRPGSpellContext& Context) override;

	UFUNCTION()
	void OnChargeFinished();

	UPROPERTY(EditDefaultsOnly, Category = "Charge", meta = (ClampMin = "0"))
	float MinDistance = 400.f;

	UPROPERTY(EditDefaultsOnly, Category = "Charge", meta = (ClampMin = "100"))
	float ChargeSpeed = 2600.f;

	UPROPERTY(EditDefaultsOnly, Category = "Charge", meta = (ClampMin = "0"))
	float Damage = 10.f;

	UPROPERTY(EditDefaultsOnly, Category = "Charge", meta = (ClampMin = "0"))
	float RootDuration = 1.f;

	UPROPERTY(EditDefaultsOnly, Category = "Charge", meta = (ClampMin = "0"))
	float RageGenerated = 20.f;

private:
	TWeakObjectPtr<ARPGCharacterBase> ChargeTarget;
	FVector ChargeDestination = FVector::ZeroVector;
};

/** [2] Mortal Strike: a crushing blow that halves the healing the target receives. */
UCLASS()
class RPGTEST_API USpell_MortalStrike : public URPGAbility_MeleeStrike
{
	GENERATED_BODY()

public:
	USpell_MortalStrike();
};

/** [3] Hamstring: a cut that slows the target. */
UCLASS()
class RPGTEST_API USpell_Hamstring : public URPGAbility_MeleeStrike
{
	GENERATED_BODY()

public:
	USpell_Hamstring();
};

/** [4] Whirlwind: spin and hit every enemy around you. */
UCLASS()
class RPGTEST_API USpell_Whirlwind : public URPGAbility_Nova
{
	GENERATED_BODY()

public:
	USpell_Whirlwind();
};

/** [5] Berserker Rush: break roots and slows, then run much faster and ignore slows for a few seconds. */
UCLASS()
class RPGTEST_API USpell_BerserkerRush : public URPGAbility_SelfBuff
{
	GENERATED_BODY()

public:
	USpell_BerserkerRush();
};
