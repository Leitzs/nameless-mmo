#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "RPGStatusEffects.generated.h"

/**
 * A status an ability wants to put on a character: which one (a Status.* tag), for how long, and how strong.
 * What Magnitude means depends on the status (see the definition table in RPGStatusEffects.cpp):
 * a speed multiplier for slows and haste, damage per second for damage over time, a healing multiplier, etc.
 * Duration <= 0 means the status lasts until something removes it.
 */
USTRUCT(BlueprintType)
struct FRPGStatusSpec
{
	GENERATED_BODY()

	FRPGStatusSpec() = default;
	FRPGStatusSpec(const FGameplayTag& InStatus, float InDuration, float InMagnitude = 0.f)
		: Status(InStatus), Duration(InDuration), Magnitude(InMagnitude)
	{
	}

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Status", meta = (Categories = "Status"))
	FGameplayTag Status;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Status")
	float Duration = 1.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Status")
	float Magnitude = 0.f;
};

/**
 * Rules and presentation of one status. The whole game shares one table, so adding a status is one row there
 * (plus a native tag); the HUD, overlays, immunities and diminishing returns pick it up automatically.
 */
struct FRPGStatusDefinition
{
	FGameplayTag Tag;
	FText DisplayName;
	/** HUD text and body overlay color. */
	FLinearColor Color = FLinearColor::White;
	bool bHarmful = true;

	/** Deals Magnitude damage per second of this type while active. */
	FGameplayTag DamageOverTimeType;

	/** A new application replaces the active one (refresh) instead of running alongside it. */
	bool bReplaceExisting = false;

	/** Statuses sharing a category get shorter on repeated applications (see URPGAbilitySystemComponent::ScaleCrowdControlDuration). */
	FGameplayTag DiminishingCategory;

	/** The status is not applied while the target has any of these tags (immunities). */
	FGameplayTagContainer BlockedBy;

	/** Ends early once the target has taken this fraction of its max health in damage. 0 = any damage, < 0 = never. */
	float BreakDamageFraction = -1.f;

	/** Body overlay: the active status with the highest priority is drawn. 0 = no overlay. */
	int32 OverlayPriority = 0;
	float OverlayIntensity = 2.5f;
	float OverlayFresnel = 0.85f;
};

namespace RPGStatusEffects
{
	RPGTEST_API const TArray<FRPGStatusDefinition>& GetDefinitions();
	RPGTEST_API const FRPGStatusDefinition* Find(const FGameplayTag& Tag);
}
