#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RPGDemonicCircle.generated.h"

class UMaterialInstanceDynamic;
class UStaticMeshComponent;

/**
 * A glowing rune circle a warlock leaves on the ground and can teleport back to (USpell_DemonicCircle).
 * Spawned by the server with the warlock as owner; replicated to everyone so enemies can see (and camp) it.
 */
UCLASS(NotPlaceable)
class RPGTEST_API ARPGDemonicCircle : public AActor
{
	GENERATED_BODY()

public:
	ARPGDemonicCircle();

	/** The living circle owned by Caster, if any (works on every machine). */
	static ARPGDemonicCircle* FindFor(const AActor* Caster);

	virtual void Tick(float DeltaSeconds) override;

protected:
	virtual void BeginPlay() override;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UStaticMeshComponent> Ring;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UStaticMeshComponent> Core;

	/** Seconds before the circle fades away. */
	UPROPERTY(EditDefaultsOnly, Category = "Circle", meta = (ClampMin = "1"))
	float Lifetime = 90.f;

private:
	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> RingMaterial;

	float Age = 0.f;
};
