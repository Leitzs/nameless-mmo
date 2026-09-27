#pragma once

#include "CoreMinimal.h"
#include "Characters/RPGPlayerCharacter.h"
#include "WarlockCharacter.generated.h"

class UPointLightComponent;

/** Warlock class: shadow caster (Fel Bolt, Shadow Bolt, Corruption, Drain Life, Fear, Demonic Circle). Horns and a fel orb. */
UCLASS()
class RPGTEST_API AWarlockCharacter : public ARPGPlayerCharacter
{
	GENERATED_BODY()

public:
	explicit AWarlockCharacter(const FObjectInitializer& ObjectInitializer);

	virtual FVector GetSpellOrigin() const override;

protected:
	virtual void HandleDeath(AActor* Killer) override;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> FelOrb;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UPointLightComponent> FelLight;
};
