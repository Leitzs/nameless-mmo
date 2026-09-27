#pragma once

#include "CoreMinimal.h"
#include "Characters/RPGPlayerCharacter.h"
#include "MageCharacter.generated.h"

class UPointLightComponent;

/** Mage class: ranged caster (Arcane Bolt, Fireball, Frost Nova, Lightning Strike, Blink, Arcane Shield), pointed hat and staff. */
UCLASS()
class RPGTEST_API AMageCharacter : public ARPGPlayerCharacter
{
	GENERATED_BODY()

public:
	explicit AMageCharacter(const FObjectInitializer& ObjectInitializer);

	virtual FVector GetSpellOrigin() const override;

protected:
	virtual void HandleDeath(AActor* Killer) override;
	virtual void AlignCosmetics() override;
	virtual void ApplyCosmeticMaterials() override;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> HatCone;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> HatBrim;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> HatBand;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> StaffShaft;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> StaffOrb;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UPointLightComponent> StaffLight;
};
