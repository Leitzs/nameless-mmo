#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RPGTransientFX.generated.h"

class UMaterialInstanceDynamic;
class UPointLightComponent;
class UStaticMeshComponent;

UENUM(BlueprintType)
enum class ERPGFXShape : uint8
{
	Sphere,
	Cylinder,
	Cone,
	Cube
};

/** Look and timing of a transient glow effect. */
USTRUCT(BlueprintType)
struct FRPGFXParams
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	ERPGFXShape Shape = ERPGFXShape::Sphere;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	FLinearColor Color = FLinearColor::White;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	float Intensity = 8.f;

	/** 0 = uniform glow, 1 = only the silhouette edges glow. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	float FresnelAmount = 0.4f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	float Lifetime = 0.5f;

	/** Seconds to go from StartScale to EndScale. Negative means the whole lifetime. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	float GrowTime = -1.f;

	/** Seconds after spawn at which the glow starts fading out. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	float FadeStart = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	FVector StartScale = FVector(0.2f);

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	FVector EndScale = FVector(2.f);

	/** Point light brightness in candelas. 0 disables the light. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	float LightIntensity = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	float LightRadius = 800.f;

	/** Random brightness jitter, 0..1. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "FX")
	float Flicker = 0.f;
};

/** A short-lived glowing primitive (explosion, shockwave, lightning bolt, sparkle) that scales and fades, then destroys itself. */
UCLASS(NotPlaceable)
class RPGTEST_API ARPGTransientFX : public AActor
{
	GENERATED_BODY()

public:
	ARPGTransientFX();

	/** Spawns an effect. When AttachTo is set, the effect follows that actor. */
	static ARPGTransientFX* Spawn(const UObject* WorldContextObject, const FVector& Location, const FRotator& Rotation, const FRPGFXParams& Params, AActor* AttachTo = nullptr);

	virtual void Tick(float DeltaSeconds) override;

private:
	void Initialize(const FRPGFXParams& InParams);
	void UpdateVisuals();

	UPROPERTY(VisibleAnywhere, Category = "FX")
	TObjectPtr<UStaticMeshComponent> Mesh;

	UPROPERTY(VisibleAnywhere, Category = "FX")
	TObjectPtr<UPointLightComponent> Light;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> Material;

	FRPGFXParams Params;
	float Age = 0.f;
};
