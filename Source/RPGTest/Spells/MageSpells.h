#pragma once

#include "CoreMinimal.h"
#include "Spells/RPGProjectile.h"
#include "Spells/RPGSpell.h"
#include "MageSpells.generated.h"

class ARPGDelayedBlast;

/** [1] Fireball: homing projectile that explodes for splash damage and sets targets on fire. */
UCLASS()
class RPGTEST_API USpell_Fireball : public URPGSpell
{
	GENERATED_BODY()

public:
	USpell_Fireball();
	virtual void Execute(const FRPGSpellContext& Context) override;

protected:
	UPROPERTY(EditDefaultsOnly, Category = "Fireball")
	TSubclassOf<ARPGProjectile> ProjectileClass;

	UPROPERTY(EditDefaultsOnly, Category = "Fireball")
	FRPGProjectileDamage Damage;

	UPROPERTY(EditDefaultsOnly, Category = "Fireball", meta = (ClampMin = "100"))
	float ProjectileSpeed = 2800.f;

	/** Steering towards a soft-locked target, in cm/s^2. 0 flies straight. */
	UPROPERTY(EditDefaultsOnly, Category = "Fireball", meta = (ClampMin = "0"))
	float HomingAcceleration = 9000.f;
};

/** [2] Frost Nova: burst of cold around the caster that damages, freezes, then slows nearby enemies. */
UCLASS()
class RPGTEST_API USpell_FrostNova : public URPGSpell
{
	GENERATED_BODY()

public:
	USpell_FrostNova();
	virtual void Execute(const FRPGSpellContext& Context) override;

protected:
	UPROPERTY(EditDefaultsOnly, Category = "Frost Nova", meta = (ClampMin = "0"))
	float Radius = 650.f;

	UPROPERTY(EditDefaultsOnly, Category = "Frost Nova", meta = (ClampMin = "0"))
	float Damage = 20.f;

	UPROPERTY(EditDefaultsOnly, Category = "Frost Nova", meta = (ClampMin = "0"))
	float FreezeDuration = 3.f;

	/** Movement multiplier applied once the freeze thaws. */
	UPROPERTY(EditDefaultsOnly, Category = "Frost Nova", meta = (ClampMin = "0.05", ClampMax = "1"))
	float SlowMultiplier = 0.5f;

	UPROPERTY(EditDefaultsOnly, Category = "Frost Nova", meta = (ClampMin = "0"))
	float SlowDuration = 4.f;
};

/** [3] Lightning Strike: calls a bolt down on the target (or the aimed ground) after a short warning, damaging and stunning. */
UCLASS()
class RPGTEST_API USpell_LightningStrike : public URPGSpell
{
	GENERATED_BODY()

public:
	USpell_LightningStrike();
	virtual void Execute(const FRPGSpellContext& Context) override;

protected:
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
class RPGTEST_API USpell_Blink : public URPGSpell
{
	GENERATED_BODY()

public:
	USpell_Blink();
	virtual void Execute(const FRPGSpellContext& Context) override;

protected:
	UPROPERTY(EditDefaultsOnly, Category = "Blink", meta = (ClampMin = "100"))
	float Distance = 900.f;
};

/** [5] Arcane Shield: a barrier that absorbs incoming damage for a while. */
UCLASS()
class RPGTEST_API USpell_ArcaneShield : public URPGSpell
{
	GENERATED_BODY()

public:
	USpell_ArcaneShield();
	virtual void Execute(const FRPGSpellContext& Context) override;

protected:
	UPROPERTY(EditDefaultsOnly, Category = "Arcane Shield", meta = (ClampMin = "0"))
	float AbsorbAmount = 80.f;

	UPROPERTY(EditDefaultsOnly, Category = "Arcane Shield", meta = (ClampMin = "0"))
	float Duration = 10.f;
};
