#include "Spells/RPGDemonicCircle.h"

#include "Components/StaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"

namespace DemonicCirclePrivate
{
	const FLinearColor RingColor(0.35f, 1.f, 0.2f);
	constexpr float Diameter = 2.2f;
}

ARPGDemonicCircle::ARPGDemonicCircle()
{
	PrimaryActorTick.bCanEverTick = true;
	SetCanBeDamaged(false);
	bReplicates = true;
	bAlwaysRelevant = true;

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CylinderMesh(RPGAssets::CylinderMesh);

	Ring = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Ring"));
	Ring->SetStaticMesh(CylinderMesh.Object);
	Ring->SetRelativeScale3D(FVector(DemonicCirclePrivate::Diameter, DemonicCirclePrivate::Diameter, 0.02f));
	Ring->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Ring->SetCanEverAffectNavigation(false);
	Ring->SetCastShadow(false);
	RootComponent = Ring;

	Core = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Core"));
	Core->SetupAttachment(Ring);
	Core->SetStaticMesh(CylinderMesh.Object);
	Core->SetRelativeLocation(FVector(0.f, 0.f, 60.f));
	Core->SetRelativeScale3D(FVector(0.35f, 0.35f, 40.f));
	Core->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Core->SetCanEverAffectNavigation(false);
	Core->SetCastShadow(false);
}

ARPGDemonicCircle* ARPGDemonicCircle::FindFor(const AActor* Caster)
{
	UWorld* World = Caster ? Caster->GetWorld() : nullptr;
	if (!World)
	{
		return nullptr;
	}

	for (TActorIterator<ARPGDemonicCircle> It(World); It; ++It)
	{
		if (It->GetOwner() == Caster && IsValid(*It) && !It->IsActorBeingDestroyed())
		{
			return *It;
		}
	}
	return nullptr;
}

void ARPGDemonicCircle::BeginPlay()
{
	Super::BeginPlay();

	RingMaterial = RPGAssets::CreateFXMaterial(this, DemonicCirclePrivate::RingColor, 2.f, 0.6f);
	if (RingMaterial)
	{
		Ring->SetMaterial(0, RingMaterial);
	}
	if (UMaterialInstanceDynamic* CoreMaterial = RPGAssets::CreateFXMaterial(this, DemonicCirclePrivate::RingColor, 1.f, 0.3f))
	{
		Core->SetMaterial(0, CoreMaterial);
	}

	if (HasAuthority())
	{
		SetLifeSpan(Lifetime);
	}
}

void ARPGDemonicCircle::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	Age += DeltaSeconds;
	if (RingMaterial)
	{
		RingMaterial->SetScalarParameterValue(TEXT("Intensity"), 1.5f + 0.8f * FMath::Sin(Age * 3.f));
	}
	Ring->AddLocalRotation(FRotator(0.f, 25.f * DeltaSeconds, 0.f));
}
