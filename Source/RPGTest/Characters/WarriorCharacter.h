#pragma once

#include "CoreMinimal.h"
#include "Characters/RPGPlayerCharacter.h"
#include "WarriorCharacter.generated.h"

/**
 * Warrior class: the toughest melee fighter, with a big sword (Sword Slash, Charge, Mortal Strike, Hamstring,
 * Whirlwind, Berserker Rush). Uses rage: gained by dealing and taking damage, drains out of combat.
 */
UCLASS()
class RPGTEST_API AWarriorCharacter : public ARPGPlayerCharacter
{
	GENERATED_BODY()

public:
	explicit AWarriorCharacter(const FObjectInitializer& ObjectInitializer);
};
