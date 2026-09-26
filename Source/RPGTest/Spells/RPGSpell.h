#pragma once

#include "CoreMinimal.h"
#include "UObject/Object.h"
#include "Core/RPGTypes.h"
#include "RPGSpell.generated.h"

class ARPGCharacterBase;
class UAnimSequenceBase;

/** Everything a spell needs to know at the moment it is released. */
USTRUCT(BlueprintType)
struct FRPGSpellContext
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "Spell")
	TObjectPtr<ARPGCharacterBase> Caster = nullptr;

	/** Where the spell leaves the caster (staff tip). */
	UPROPERTY(BlueprintReadOnly, Category = "Spell")
	FVector Origin = FVector::ZeroVector;

	/** World point under the crosshair, clamped to the spell range. */
	UPROPERTY(BlueprintReadOnly, Category = "Spell")
	FVector AimLocation = FVector::ZeroVector;

	/** Soft-locked hostile under the crosshair, if any. */
	UPROPERTY(BlueprintReadOnly, Category = "Spell")
	TObjectPtr<ARPGCharacterBase> Target = nullptr;
};

/**
 * A castable ability. Subclasses configure costs and presentation in their constructor and implement Execute.
 * Instances live in a spellbook component and keep their own cooldown.
 */
UCLASS(Abstract, Blueprintable)
class RPGTEST_API URPGSpell : public UObject
{
	GENERATED_BODY()

public:
	virtual UWorld* GetWorld() const override;

	/** Extra spell-specific checks before the cast starts (mana, cooldown and caster state are checked by the spellbook). */
	virtual ERPGCastResult CanCast(const ARPGCharacterBase& Caster) const { return ERPGCastResult::Success; }

	/** Performs the spell effect. Called when the cast animation reaches its release point. */
	virtual void Execute(const FRPGSpellContext& Context) {}

	void StartCooldown();
	void ResetCooldown() { CooldownEndTime = 0.0; }
	float GetCooldownRemaining() const;

	const FText& GetDisplayName() const { return DisplayName; }
	const FText& GetDescription() const { return Description; }
	const FLinearColor& GetColor() const { return Color; }
	float GetManaCost() const { return ManaCost; }
	float GetCooldown() const { return Cooldown; }
	float GetCastTime() const { return CastTime; }
	float GetReleaseDelay() const { return ReleaseDelay; }
	float GetRange() const { return Range; }
	bool ShouldFaceAim() const { return bFaceAim; }
	UAnimSequenceBase* GetCastAnimation() const { return CastAnimation; }
	float GetAnimationPlayRate() const { return AnimationPlayRate; }

protected:
	UPROPERTY(EditDefaultsOnly, Category = "Spell")
	FText DisplayName;

	UPROPERTY(EditDefaultsOnly, Category = "Spell", meta = (MultiLine = true))
	FText Description;

	/** Theme color used by the HUD and effects. */
	UPROPERTY(EditDefaultsOnly, Category = "Spell")
	FLinearColor Color = FLinearColor::White;

	UPROPERTY(EditDefaultsOnly, Category = "Spell|Cost", meta = (ClampMin = "0"))
	float ManaCost = 10.f;

	UPROPERTY(EditDefaultsOnly, Category = "Spell|Cost", meta = (ClampMin = "0"))
	float Cooldown = 1.f;

	/** Seconds the caster is busy (cannot cast again, moves slowly). */
	UPROPERTY(EditDefaultsOnly, Category = "Spell|Casting", meta = (ClampMin = "0"))
	float CastTime = 0.45f;

	/** Seconds after the cast starts at which Execute runs, to match the animation. */
	UPROPERTY(EditDefaultsOnly, Category = "Spell|Casting", meta = (ClampMin = "0"))
	float ReleaseDelay = 0.15f;

	UPROPERTY(EditDefaultsOnly, Category = "Spell|Casting", meta = (ClampMin = "0"))
	float Range = 3000.f;

	/** Turn the caster towards the aim point when the cast starts. */
	UPROPERTY(EditDefaultsOnly, Category = "Spell|Casting")
	bool bFaceAim = true;

	UPROPERTY(EditDefaultsOnly, Category = "Spell|Casting")
	TObjectPtr<UAnimSequenceBase> CastAnimation;

	UPROPERTY(EditDefaultsOnly, Category = "Spell|Casting", meta = (ClampMin = "0.1"))
	float AnimationPlayRate = 1.3f;

private:
	double CooldownEndTime = 0.0;
};
