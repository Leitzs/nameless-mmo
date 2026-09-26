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

/** Why a spell could not be cast. */
UENUM(BlueprintType)
enum class ERPGCastResult : uint8
{
	Success,
	Dead,
	Incapacitated,
	Busy,
	Cooldown,
	NotEnoughMana,
	InvalidSlot,
	Blocked
};
