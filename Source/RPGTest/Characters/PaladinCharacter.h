#pragma once

#include "CoreMinimal.h"
#include "Characters/RPGPlayerCharacter.h"
#include "PaladinCharacter.generated.h"

/**
 * Paladin class: armored melee hybrid with sword and shield (Sword Swing, Crusader Strike, Hammer of Justice,
 * Flash of Light, Cleanse, Divine Shield). The shield blocks part of frontal damage (Trait.FrontalBlock).
 */
UCLASS()
class RPGTEST_API APaladinCharacter : public ARPGPlayerCharacter
{
	GENERATED_BODY()

public:
	explicit APaladinCharacter(const FObjectInitializer& ObjectInitializer);
};
