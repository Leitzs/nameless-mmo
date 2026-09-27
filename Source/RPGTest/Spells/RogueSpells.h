#pragma once

#include "CoreMinimal.h"
#include "Spells/RPGAbilityArchetypes.h"
#include "RogueSpells.generated.h"

/** [LMB] Dagger Slash: fast dagger attacks. */
UCLASS()
class RPGTEST_API USpell_DaggerSlash : public URPGAbility_MeleeStrike
{
	GENERATED_BODY()

public:
	USpell_DaggerSlash();
};

/**
 * [1] Stealth: fade from sight (slower while hidden). Attacking or taking any damage reveals you; attacks from
 * stealth hit 50% harder. Enemies right next to you see a shimmer. Cannot be used while taking damage over time.
 * Using it again while hidden reveals you.
 */
UCLASS()
class RPGTEST_API USpell_Stealth : public URPGAbility_SelfBuff
{
	GENERATED_BODY()

public:
	USpell_Stealth();

	virtual ERPGCastResult CheckCasterState(const ARPGCharacterBase& Caster) const override;
	virtual FText GetSlotLabel(const ARPGCharacterBase& Caster) const override;

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;
};

/** [2] Backstab: a vicious stab that deals double damage from behind. */
UCLASS()
class RPGTEST_API USpell_Backstab : public URPGAbility_MeleeStrike
{
	GENERATED_BODY()

public:
	USpell_Backstab();
};

/** [3] Throwing Knife: a fast poisoned knife that slows. */
UCLASS()
class RPGTEST_API USpell_ThrowingKnife : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_ThrowingKnife();
};

/** [4] Kidney Shot: a low blow that stuns. */
UCLASS()
class RPGTEST_API USpell_KidneyShot : public URPGAbility_MeleeStrike
{
	GENERATED_BODY()

public:
	USpell_KidneyShot();
};

/** [5] Shadowstep: teleport behind the target (keeps stealth) and gain a short burst of speed. Sets up Backstab. */
UCLASS()
class RPGTEST_API USpell_Shadowstep : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	USpell_Shadowstep();

	virtual ERPGCastResult CheckCasterState(const ARPGCharacterBase& Caster) const override;

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	/** Distance behind the target's back where the rogue lands. */
	UPROPERTY(EditDefaultsOnly, Category = "Shadowstep", meta = (ClampMin = "50"))
	float BehindDistance = 130.f;
};
