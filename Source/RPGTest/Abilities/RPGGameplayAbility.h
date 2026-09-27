#pragma once

#include "CoreMinimal.h"
#include "Abilities/GameplayAbility.h"
#include "Core/RPGTypes.h"
#include "RPGGameplayAbility.generated.h"

class ARPGCharacterBase;
class ARPGProjectile;
class UAnimSequenceBase;
struct FRPGProjectilePayload;

/** Everything an ability needs to know at the moment it is released. */
USTRUCT(BlueprintType)
struct FRPGSpellContext
{
	GENERATED_BODY()

	UPROPERTY(BlueprintReadOnly, Category = "Spell")
	TObjectPtr<ARPGCharacterBase> Caster = nullptr;

	/** Where the spell leaves the caster (staff tip, hand). */
	UPROPERTY(BlueprintReadOnly, Category = "Spell")
	FVector Origin = FVector::ZeroVector;

	/** World point under the crosshair, clamped to the ability range. */
	UPROPERTY(BlueprintReadOnly, Category = "Spell")
	FVector AimLocation = FVector::ZeroVector;

	/** Soft-locked hostile under the crosshair, if any. */
	UPROPERTY(BlueprintReadOnly, Category = "Spell")
	TObjectPtr<ARPGCharacterBase> Target = nullptr;

	/** The caster was in stealth when the ability started (ambush bonuses). */
	UPROPERTY(BlueprintReadOnly, Category = "Spell")
	bool bFromStealth = false;
};

/**
 * Base of every ability in the game (basic attacks and spells). A subclass sets costs and presentation in its
 * constructor and implements ExecuteSpell; the reusable archetypes in Spells/RPGAbilityArchetypes.h cover most needs
 * (projectile, melee strike, self buff, targeted debuff, nova) with data only.
 *
 * Flow (GAS local prediction):
 *   1. Activation on the controlling machine: cost, cooldown, facing and animation are predicted right away; the
 *      server repeats the activation, spends the resource and shows the animation to everyone else.
 *   2. After ReleaseDelay the controlling machine reads its aim (camera ray + soft lock) and sends it to the server as
 *      target data. The server clamps it to the range and runs ExecuteSpell. OnRelease runs on both sides first, for
 *      predicted movement (dashes).
 *   3. The ability stays active (busy, "State.Casting") until CastTime has passed, then ends.
 * Crowd control cancels active abilities unless bUsableWhileIncapacitated (URPGAbilitySystemComponent).
 */
UCLASS(Abstract)
class RPGTEST_API URPGGameplayAbility : public UGameplayAbility
{
	GENERATED_BODY()

public:
	URPGGameplayAbility();

	virtual void PostInitProperties() override;

	// UGameplayAbility
	virtual bool CanActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayTagContainer* SourceTags = nullptr, const FGameplayTagContainer* TargetTags = nullptr, FGameplayTagContainer* OptionalRelevantTags = nullptr) const override;
	virtual void ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData) override;
	virtual void EndAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo, bool bReplicateEndAbility, bool bWasCancelled) override;
	virtual const FGameplayTagContainer* GetCooldownTags() const override;
	virtual void ApplyCooldown(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo) const override;
	virtual bool CheckCost(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, FGameplayTagContainer* OptionalRelevantTags = nullptr) const override;
	virtual void ApplyCost(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo) const override;

	/** Ability-specific requirements on the caster (in stealth, not burning...). Checked before activating, on both sides. */
	virtual ERPGCastResult CheckCasterState(const ARPGCharacterBase& Caster) const { return ERPGCastResult::Success; }

	/** Extra checks on the soft-locked target of a RequiresTarget ability (controlling machine only). */
	virtual ERPGCastResult CheckTarget(const ARPGCharacterBase& Caster, const ARPGCharacterBase& Target) const;

	/** Name on the hotbar; abilities with several stages can change it. */
	virtual FText GetSlotLabel(const ARPGCharacterBase& Caster) const { return DisplayName; }

	/** Cooldown started when the ability is used; can depend on the caster's state. */
	virtual float GetCooldownDuration(const ARPGCharacterBase* Caster) const { return Cooldown; }

	const FText& GetDisplayName() const { return DisplayName; }
	const FText& GetDescription() const { return Description; }
	const FLinearColor& GetColor() const { return Color; }
	float GetResourceCost() const { return ResourceCost; }
	float GetCastTime() const { return CastTime; }
	float GetRange() const { return Range; }
	bool RequiresTarget() const { return bRequiresTarget; }
	bool IsUsableWhileIncapacitated() const { return bUsableWhileIncapacitated; }
	const FGameplayTag& GetCooldownTag() const { return CooldownTag; }

protected:
	/** Runs at the release point on the controlling machine and on the server (predicted movement). */
	virtual void OnRelease(const FRPGSpellContext& Context) {}

	/**
	 * Performs the ability's effect. Server only. Anything visible must be replicated: spawn replicated actors,
	 * change replicated state, apply effects, or use ARPGTransientFX::SpawnForAll.
	 */
	virtual void ExecuteSpell(const FRPGSpellContext& Context) {}

	ARPGCharacterBase* GetCaster() const;

	/** Keeps the ability active past its cast time (dashes waiting to arrive). Call from OnRelease; end with FinishHold. */
	void HoldOpen() { bHeld = true; }
	void FinishHold();

	/** Multiplier for damage dealt by an ability started from stealth. */
	float GetStealthMultiplier(const FRPGSpellContext& Context) const { return Context.bFromStealth ? StealthDamageMultiplier : 1.f; }

	/** Constructor helper: sets CastAnimation from an asset path (see RPGAssets). */
	void SetCastAnimation(const TCHAR* AnimationPath);

	/** Fires a projectile from the context's origin towards its aim point, homing on its target. Server only. */
	ARPGProjectile* SpawnProjectile(const FRPGSpellContext& Context, const FRPGProjectilePayload& Payload, float Speed, float HomingAcceleration, float VisualScale = 1.f) const;

	/** Small flash in the ability color at the context's origin. */
	void SpawnCastFlash(const FRPGSpellContext& Context, float Size = 0.9f) const;

	UPROPERTY(EditDefaultsOnly, Category = "Ability")
	FText DisplayName;

	UPROPERTY(EditDefaultsOnly, Category = "Ability", meta = (MultiLine = true))
	FText Description;

	/** Theme color used by the HUD and effects. */
	UPROPERTY(EditDefaultsOnly, Category = "Ability")
	FLinearColor Color = FLinearColor::White;

	/** Amount of the class resource (mana, energy or rage) spent on use. */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Cost", meta = (ClampMin = "0"))
	float ResourceCost = 0.f;

	UPROPERTY(EditDefaultsOnly, Category = "Ability|Cost", meta = (ClampMin = "0"))
	float Cooldown = 0.f;

	/** Granted while the cooldown runs. Every ability needs its own (Cooldown.<Class>.<Ability>). */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Cost", meta = (Categories = "Cooldown"))
	FGameplayTag CooldownTag;

	/** Seconds the caster is busy (cannot use another ability). */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting", meta = (ClampMin = "0"))
	float CastTime = 0.45f;

	/** Seconds after activation at which the effect happens, to match the animation. */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting", meta = (ClampMin = "0"))
	float ReleaseDelay = 0.15f;

	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting", meta = (ClampMin = "0"))
	float Range = 3000.f;

	/** Turn the caster towards the aim point when the ability starts. */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting")
	bool bFaceAim = true;

	/** Casting slows the caster down (the character's CastingSpeedMultiplier). Off for melee swings and instant abilities. */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting")
	bool bSlowsWhileCasting = true;

	/** Can only be used with a soft-locked enemy under the crosshair. */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting")
	bool bRequiresTarget = false;

	/** Using the ability ends the caster's stealth. */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting")
	bool bBreaksStealth = true;

	/** Can be used (and keeps running) while stunned, frozen or feared: crowd-control breakers. */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting")
	bool bUsableWhileIncapacitated = false;

	/** Damage multiplier when the ability was started from stealth (see GetStealthMultiplier). */
	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting", meta = (ClampMin = "1"))
	float StealthDamageMultiplier = 1.5f;

	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting")
	TObjectPtr<UAnimSequenceBase> CastAnimation;

	UPROPERTY(EditDefaultsOnly, Category = "Ability|Casting", meta = (ClampMin = "0.1"))
	float AnimationPlayRate = 1.3f;

private:
	UFUNCTION()
	void OnReleaseTimer();

	UFUNCTION()
	void OnCastTimeElapsed();

	UFUNCTION()
	void OnReleaseTimedOut();

	/** Controlling machine: reads the aim (or reuses the activation's), sends it to the server if needed and releases. */
	void ReleaseLocal(bool bSameFrameAsActivation);

	/** Server: the owning client's aim arrived. */
	void OnServerTargetData(const FGameplayAbilityTargetDataHandle& Data, FGameplayTag ApplicationTag);

	void Release(const FVector& AimLocation, ARPGCharacterBase* Target);

	/** Ends the ability once it has been released and its cast time has passed. */
	void TryFinish();

	/** Casts by remote clients run on the server slightly shorter, so the client's next cast is not refused because of jitter. */
	bool IsServerForRemoteClient(const FGameplayAbilityActorInfo* ActorInfo) const;

	mutable FGameplayTagContainer CooldownTagContainer;
	FDelegateHandle TargetDataDelegateHandle;

	/** Aim read by the controlling machine when the ability started. */
	FVector ActivationAimLocation = FVector::ZeroVector;
	UPROPERTY(Transient)
	TObjectPtr<ARPGCharacterBase> ActivationAimTarget;

	bool bReleased = false;
	bool bCastTimeElapsed = false;
	bool bFromStealth = false;
	bool bHeld = false;
};
