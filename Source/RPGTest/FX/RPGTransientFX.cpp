#include "FX/RPGTransientFX.h"

#include "Components/PointLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/World.h"
#include "Materials/MaterialInstanceDynamic.h"

namespace
{
	const TCHAR* GetShapeMeshPath(ERPGFXShape Shape)
	{
		switch (Shape)
		{
		case ERPGFXShape::Cylinder: return RPGAssets::CylinderMesh;
		case ERPGFXShape::Cone: return RPGAssets::ConeMesh;
		case ERPGFXShape::Cube: return RPGAssets::CubeMesh;
		default: return RPGAssets::SphereMesh;
		}
	}
}

ARPGTransientFX::ARPGTransientFX()
{
	PrimaryActorTick.bCanEverTick = true;
	SetCanBeDamaged(false);

	Mesh = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Mesh"));
	Mesh->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Mesh->SetGenerateOverlapEvents(false);
	Mesh->SetCanEverAffectNavigation(false);
	Mesh->SetCastShadow(false);
	Mesh->bReceivesDecals = false;
	RootComponent = Mesh;

	Light = CreateDefaultSubobject<UPointLightComponent>(TEXT("Light"));
	Light->SetupAttachment(Mesh);
	Light->SetCastShadows(false);
	Light->SetIntensityUnits(ELightUnits::Candelas);
	Light->SetVisibility(false);
}

ARPGTransientFX* ARPGTransientFX::Spawn(const UObject* WorldContextObject, const FVector& Location, const FRotator& Rotation, const FRPGFXParams& Params, AActor* AttachTo)
{
	UWorld* World = WorldContextObject ? WorldContextObject->GetWorld() : nullptr;
	if (!World)
	{
		return nullptr;
	}

	FActorSpawnParameters SpawnParams;
	SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	ARPGTransientFX* Effect = World->SpawnActor<ARPGTransientFX>(ARPGTransientFX::StaticClass(), Location, Rotation, SpawnParams);
	if (Effect)
	{
		Effect->Initialize(Params);
		if (AttachTo)
		{
			Effect->AttachToActor(AttachTo, FAttachmentTransformRules::KeepWorldTransform);
		}
	}
	return Effect;
}

void ARPGTransientFX::Initialize(const FRPGFXParams& InParams)
{
	Params = InParams;
	Params.Lifetime = FMath::Max(0.05f, Params.Lifetime);
	if (Params.GrowTime < 0.f)
	{
		Params.GrowTime = Params.Lifetime;
	}

	Mesh->SetStaticMesh(RPGAssets::LoadMesh(GetShapeMeshPath(Params.Shape)));
	Material = RPGAssets::CreateFXMaterial(this, Params.Color, Params.Intensity, Params.FresnelAmount);
	if (Material)
	{
		Mesh->SetMaterial(0, Material);
	}

	if (Params.LightIntensity > 0.f)
	{
		Light->SetLightColor(Params.Color);
		Light->SetAttenuationRadius(Params.LightRadius);
		Light->SetVisibility(true);
	}

	UpdateVisuals();
}

void ARPGTransientFX::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	Age += DeltaSeconds;
	if (Age >= Params.Lifetime)
	{
		Destroy();
		return;
	}

	UpdateVisuals();
}

void ARPGTransientFX::UpdateVisuals()
{
	const float GrowAlpha = Params.GrowTime > 0.f ? FMath::Clamp(Age / Params.GrowTime, 0.f, 1.f) : 1.f;
	const float EasedGrow = 1.f - FMath::Square(1.f - GrowAlpha);
	Mesh->SetRelativeScale3D(FMath::Lerp(Params.StartScale, Params.EndScale, EasedGrow));

	float Fade = 1.f;
	if (Age > Params.FadeStart)
	{
		const float FadeDuration = FMath::Max(0.01f, Params.Lifetime - Params.FadeStart);
		Fade = FMath::Square(1.f - FMath::Clamp((Age - Params.FadeStart) / FadeDuration, 0.f, 1.f));
	}

	const float Jitter = Params.Flicker > 0.f ? 1.f - Params.Flicker * FMath::FRand() : 1.f;

	if (Material)
	{
		Material->SetScalarParameterValue(TEXT("Intensity"), Params.Intensity * Fade * Jitter);
	}
	if (Params.LightIntensity > 0.f)
	{
		Light->SetIntensity(Params.LightIntensity * Fade * Jitter);
	}
}
