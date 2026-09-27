#pragma once

#include "CoreMinimal.h"
#include "Characters/RPGPlayerCharacter.h"
#include "RogueCharacter.generated.h"

/**
 * Rogue class: fast melee assassin with two daggers (Dagger Slash, Stealth, Backstab, Throwing Knife,
 * Kidney Shot, Shadowstep). Uses energy: small pool, fast regeneration.
 */
UCLASS()
class RPGTEST_API ARogueCharacter : public ARPGPlayerCharacter
{
	GENERATED_BODY()

public:
	explicit ARogueCharacter(const FObjectInitializer& ObjectInitializer);
};
