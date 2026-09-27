#pragma once

#include "CoreMinimal.h"
#include "Spells/RPGAbilityArchetypes.h"
#include "MageSpells.generated.h"

/** [LMB] Arcane Bolt: free, quick homing bolt. */
UCLASS()
class RPGTEST_API USpell_ArcaneBolt : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_ArcaneBolt();
};

/** [1] Fireball: homing projectile that explodes for splash damage and sets targets on fire. */
UCLASS()
class RPGTEST_API USpell_Fireball : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_Fireball();
};

/** [2] Frost Nova: burst of cold around the caster that damages, freezes, then slows nearby enemies. */
UCLASS()
class RPGTEST_API USpell_FrostNova : public URPGAbility_Nova
{
	GENERATED_BODY()

public:
	USpell_FrostNova();

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;
	virtual void OnNovaHit(const FRPGSpellContext& Context, ARPGCharacterBase* Target) override;

	UPROPERTY(EditDefaultsOnly, Category = "Frost Nova", meta = (ClampMin = "0"))
	float FreezeDuration = 3.f;
};

/** [3] Lightning Strike: calls a bolt down on the target (or the aimed ground) after a short warning, damaging and stunning. */
UCLASS()
class RPGTEST_API USpell_LightningStrike : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	USpell_LightningStrike();

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	UPROPERTY(EditDefaultsOnly, Category = "Lightning Strike", meta = (ClampMin = "0"))
	float Damage = 60.f;

	UPROPERTY(EditDefaultsOnly, Category = "Lightning Strike", meta = (ClampMin = "0"))
	float Radius = 280.f;

	UPROPERTY(EditDefaultsOnly, Category = "Lightning Strike", meta = (ClampMin = "0"))
	float StrikeDelay = 0.4f;

	UPROPERTY(EditDefaultsOnly, Category = "Lightning Strike", meta = (ClampMin = "0"))
	float StunDuration = 0.9f;
};

/** [4] Blink: short-range teleport in the movement direction (or towards the crosshair when standing still). */
UCLASS()
class RPGTEST_API USpell_Blink : public URPGGameplayAbility
{
	GENERATED_BODY()

public:
	USpell_Blink();

protected:
	virtual void ExecuteSpell(const FRPGSpellContext& Context) override;

	UPROPERTY(EditDefaultsOnly, Category = "Blink", meta = (ClampMin = "100"))
	float Distance = 900.f;
};

/** [5] Arcane Shield: a barrier that absorbs incoming damage for a while. */
UCLASS()
class RPGTEST_API USpell_ArcaneShield : public URPGAbility_SelfBuff
{
	GENERATED_BODY()

public:
	USpell_ArcaneShield();
};

namespace RPGSpellHelpers
{
	/**
	 * Teleports a character towards Destination along the ground, stopping short of walls and falling back to
	 * shorter hops when the spot is blocked. Without bSweep the path is not checked (jumping past a target).
	 * Server only. Returns whether it moved.
	 */
	RPGTEST_API bool TeleportCharacter(ARPGCharacterBase& Character, const FVector& Destination, const FRotator& Facing, bool bSweep = true);
}
