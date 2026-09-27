#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemComponent.h"
#include "Core/RPGTypes.h"
#include "RPGAbilitySystemComponent.generated.h"

class ARPGCharacterBase;
class URPGAttributeSet;
class URPGGameplayAbility;
struct FRPGStatusSpec;

/** How several active effects with the same status combine their Data.Magnitude. */
enum class ERPGMagnitudeAggregation : uint8
{
	/** The smallest value wins (slows, healing reduction). */
	Lowest,
	/** The largest value wins (haste). */
	Highest
};

/**
 * The game's ability system component, one per character. On top of the engine component it owns the combat rules
 * that are not tied to a single ability:
 *   - vitals: max health and the class resource (FRPGResourceConfig), regeneration, rage gain/decay, "in combat" timer;
 *   - turning IncomingDamage / IncomingHealing into health changes: shield absorption, god mode, statuses that break
 *     on damage (stealth, fear), death, combat text;
 *   - statuses: applying them with immunities and diminishing returns, and reading their magnitudes (speed, healing);
 *   - the ability hotbar: slot 0 is the basic attack (left mouse), slots 1-5 the numbered keys.
 * Everything that changes gameplay state runs on the server; clients predict ability activation through GAS.
 */
UCLASS(ClassGroup = (RPG))
class RPGTEST_API URPGAbilitySystemComponent : public UAbilitySystemComponent
{
	GENERATED_BODY()

public:
	URPGAbilitySystemComponent();

	virtual void BeginPlay() override;
	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;
	/** Always tick: regeneration runs here. (The gameplay tasks base class would stop ticking once no task needs it.) */
	virtual bool GetShouldTick() const override { return true; }

	/** Class stats. Call on every machine (the HUD reads the resource type); attributes are only set on the server. */
	void InitVitals(float InMaxHealth, float InHealthRegen, const FRPGResourceConfig& InResource);

	/** Server: grants one ability per hotbar slot (index = slot, null entries are skipped). */
	void GrantSlotAbilities(const TArray<TSubclassOf<URPGGameplayAbility>>& AbilityClasses);

	const URPGAttributeSet* GetRPGAttributes() const;
	const FRPGResourceConfig& GetResourceConfig() const { return ResourceConfig; }
	ARPGCharacterBase* GetCharacter() const;

	// Hotbar.
	static constexpr int32 NumSlots = 6;
	/** Checks and starts the ability in Slot on the machine that controls the character. */
	ERPGCastResult TryActivateSlot(int32 Slot);
	ERPGCastResult CanActivateSlot(int32 Slot) const;
	FGameplayAbilitySpec* FindSlotSpec(int32 Slot) const;
	/** The slot's ability: the live instance when there is one, otherwise the class default (enough for display). */
	const URPGGameplayAbility* GetSlotAbility(int32 Slot) const;
	/** Seconds left on the slot's cooldown (0 when ready); OutDuration is the full cooldown. */
	float GetSlotCooldownRemaining(int32 Slot, float& OutDuration) const;
	void ResetCooldowns();

	// Vitals (server).
	void RestoreAll();
	void AddResource(float Amount);
	/** Absorbs up to Amount damage for Duration seconds; a stronger shield replaces a weaker one. */
	void AddShield(float Amount, float Duration);
	void SetInvulnerable(bool bInInvulnerable) { bInvulnerable = bInInvulnerable; }
	bool IsInvulnerable() const { return bInvulnerable; }
	/** Dealt or took damage recently (server). */
	bool IsInCombat() const;
	bool WasDamagedWithin(float Seconds) const;

	// Statuses.
	/** Server: applies a status, honoring immunities and diminishing returns. Returns false if it was resisted. */
	bool ApplyStatus(const FRPGStatusSpec& Status, AActor* SourceActor, AActor* Causer = nullptr);
	/** Server: removes every active status matching any of the tags (children included). */
	void RemoveStatuses(const FGameplayTagContainer& Tags);
	bool HasStatus(const FGameplayTag& Tag) const { return HasMatchingGameplayTag(Tag); }
	/** Combined Data.Magnitude of the active effects granting Tag, or Default when there is none. Server and owning client. */
	float GetStatusMagnitude(const FGameplayTag& Tag, ERPGMagnitudeAggregation Aggregation, float Default) const;
	/** Seconds left on the longest active effect granting Tag (owning client and server). */
	float GetStatusTimeRemaining(const FGameplayTag& Tag) const;
	/** Movement speed multiplier from roots, slows, haste and stealth. Stuns and freezes are handled by the character. */
	float GetMoveSpeedMultiplier() const;
	float GetHealingMultiplier() const;

	// Damage pipeline, called by URPGAttributeSet on the server.
	void HandleIncomingDamage(float Amount, const FGameplayEffectSpec& Spec);
	void HandleIncomingHealing(float Amount, const FGameplayEffectSpec& Spec);

	/** Seconds the server forgives on cast times and cooldowns of abilities cast by remote clients (network jitter). */
	static constexpr float ServerTimeTolerance = 0.12f;

private:
	/** Server: the owner dealt Amount damage to someone else. */
	void NotifyDamageDealt(float Amount);

	/** Returns the duration left after diminishing returns for the category (0 = immune for now). */
	float ScaleCrowdControlDuration(const FGameplayTag& Category, float Duration);

	void OnIncapacitatedChanged(const FGameplayTag Tag, int32 NewCount);
	void OnBarrierChanged(const FGameplayTag Tag, int32 NewCount);

	FRPGResourceConfig ResourceConfig;
	float HealthRegen = 0.f;
	float OutOfCombatDelay = 6.f;
	float RegenAccumulator = 0.f;
	double LastDamagedTime = -1000.0;
	double LastCombatTime = -1000.0;
	bool bInvulnerable = false;

	struct FDiminishingState
	{
		int32 Level = 0;
		double ResetTime = 0.0;
	};
	TMap<FGameplayTag, FDiminishingState> Diminishing;

	/** Damage taken since each break-on-damage status was applied. */
	TMap<FGameplayTag, float> BreakDamageTaken;
};
