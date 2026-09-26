#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RPGMedievalProp.generated.h"

class UInstancedStaticMeshComponent;
class UPointLightComponent;

UENUM(BlueprintType)
enum class ERPGPropType : uint8
{
	Cottage,
	Campfire,
	Watchtower,
	Fence
};

/**
 * A medieval set piece (cottage, campfire, watchtower, fence) assembled from primitive shapes.
 * Pick the type and variant in the details panel. It sits on the terrain automatically and keeps
 * the world generator's trees away from its footprint. Fires and lanterns light up (and flicker).
 */
UCLASS()
class RPGTEST_API ARPGMedievalProp : public AActor
{
	GENERATED_BODY()

public:
	ARPGMedievalProp();

	virtual void OnConstruction(const FTransform& Transform) override;
	virtual void Tick(float DeltaSeconds) override;

	/** Radius kept free of generated vegetation. */
	float GetClearingRadius() const;

	ERPGPropType GetPropType() const { return PropType; }

protected:
	virtual void BeginPlay() override;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Prop")
	ERPGPropType PropType = ERPGPropType::Cottage;

	/** Selects color schemes and random details. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Prop")
	int32 Variant = 0;

	/** Length of fences. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Prop", meta = (ClampMin = "100"))
	float Length = 800.f;

	/** Keep the prop's origin on the world generator's terrain. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Prop")
	bool bSnapToTerrain = true;

	/** Vegetation clearing radius. Negative uses a size-based default. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Prop")
	float ClearingRadiusOverride = -1.f;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<USceneComponent> SceneRoot;

	/** Colliding parts, one component per primitive shape (cube, cylinder, cone, sphere). */
	UPROPERTY(VisibleAnywhere, Category = "Components")
	TArray<TObjectPtr<UInstancedStaticMeshComponent>> SolidParts;

	/** Non-colliding details (flames, cloth, small decorations), same shape order. */
	UPROPERTY(VisibleAnywhere, Category = "Components")
	TArray<TObjectPtr<UInstancedStaticMeshComponent>> DecorParts;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UPointLightComponent> Light;

private:
	void Rebuild();
	void SnapToTerrain();

	float LightBaseIntensity = 0.f;
	float FlickerOffset = 0.f;
	bool bFlicker = false;
};
