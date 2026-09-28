#pragma once

#include "CoreMinimal.h"
#include "Characters/RPGPlayerCharacter.h"
#include "ArcherCharacter.generated.h"

/**
 * Archer class: ranged physical damage with a longbow (Quick Shot, Aimed Shot, Multi-Shot, Concussive Shot,
 * Disengage, Rain of Arrows). Kites with slows and a backwards leap. Uses energy.
 */
UCLASS()
class RPGTEST_API AArcherCharacter : public ARPGPlayerCharacter
{
	GENERATED_BODY()

public:
	explicit AArcherCharacter(const FObjectInitializer& ObjectInitializer);
};
