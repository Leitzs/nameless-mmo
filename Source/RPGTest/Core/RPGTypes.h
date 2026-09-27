#pragma once

#include "CoreMinimal.h"
#include "RPGTypes.generated.h"

/** Which side a character fights for. Characters on different non-neutral teams are hostile. */
UENUM(BlueprintType)
enum class ERPGTeam : uint8
{
	Player,
	Enemy,
	Neutral
};

/** Why an ability could not be used. */
UENUM(BlueprintType)
enum class ERPGCastResult : uint8
{
	Success,
	Dead,
	Incapacitated,
	Busy,
	Cooldown,
	NotEnoughResource,
	InvalidSlot,
	Blocked,
	NoTarget,
	OutOfRange,
	/** Cannot hide while hurt (damage over time). */
	InCombat,
	/** Movement abilities while rooted. */
	Rooted
};

/** What a class spends on its abilities. */
UENUM(BlueprintType)
enum class ERPGResourceType : uint8
{
	None,
	/** Large pool that regenerates steadily. */
	Mana,
	/** Small pool that regenerates fast: short bursts, then waiting. */
	Energy,
	/** Starts empty, is gained by dealing and taking damage and drains out of combat. */
	Rage
};

/** How a class's resource behaves. */
USTRUCT(BlueprintType)
struct FRPGResourceConfig
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Resource")
	ERPGResourceType Type = ERPGResourceType::None;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Resource", meta = (ClampMin = "0"))
	float Max = 0.f;

	/** Gained per second, always. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Resource")
	float RegenPerSecond = 0.f;

	/** Lost per second while out of combat. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Resource", meta = (ClampMin = "0"))
	float OutOfCombatDecayPerSecond = 0.f;

	/** Gained per point of damage dealt. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Resource", meta = (ClampMin = "0"))
	float GainPerDamageDealt = 0.f;

	/** Gained per point of damage taken. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Resource", meta = (ClampMin = "0"))
	float GainPerDamageTaken = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Resource")
	bool bStartsFull = true;

	static FRPGResourceConfig MakeMana(float InMax, float InRegenPerSecond);
	static FRPGResourceConfig MakeEnergy(float InMax, float InRegenPerSecond);
	static FRPGResourceConfig MakeRage(float InMax, float InGainPerDamageDealt, float InGainPerDamageTaken, float InDecayPerSecond);

	FText GetDisplayName() const;
	FLinearColor GetColor() const;
};
