#include "Spells/RPGDelayedBlast.h"

#include "Characters/RPGCharacterBase.h"
#include "Combat/RPGCombatLibrary.h"
#include "Components/RPGStatusEffectComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "FX/RPGTransientFX.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "TimerManager.h"
#include "UObject/ConstructorHelpers.h"

ARPGDelayedBlast::ARPGDelayedBlast()
{
	PrimaryActorTick.bCanEverTick = true;
	SetCanBeDamaged(false);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CylinderMesh(RPGAssets::CylinderMesh);
	Marker = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Marker"));
	Marker->SetStaticMesh(CylinderMesh.Object);
	Marker->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Marker->SetCanEverAffectNavigation(false);
	Marker->SetCastShadow(false);
	RootComponent = Marker;
}

void ARPGDelayedBlast::Configure(float InDelay, float InRadius, float InDamage, TSubclassOf<UDamageType> InDamageType, float InStunDuration, const FLinearColor& InColor, ARPGCharacterBase* InTrackedTarget)
{
	Delay = FMath::Max(0.05f, InDelay);
	Radius = InRadius;
	Damage = InDamage;
	DamageType = InDamageType;
	StunDuration = InStunDuration;
	Color = InColor;
	TrackedTarget = InTrackedTarget;
}

void ARPGDelayedBlast::BeginPlay()
{
	Super::BeginPlay();

	MarkerMaterial = RPGAssets::CreateFXMaterial(this, Color, 2.f, 0.f);
	if (MarkerMaterial)
	{
		Marker->SetMaterial(0, MarkerMaterial);
	}

	SnapToGround();
	GetWorldTimerManager().SetTimer(DetonateTimer, this, &ThisClass::Detonate, Delay, false);
}

void ARPGDelayedBlast::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	Age += DeltaSeconds;

	if (const ARPGCharacterBase* Target = TrackedTarget.Get(); Target && Target->IsAlive())
	{
		SetActorLocation(Target->GetActorLocation());
		SnapToGround();
	}

	// The warning circle closes in on its final size and blinks faster as the strike approaches.
	const float Alpha = FMath::Clamp(Age / Delay, 0.f, 1.f);
	const float Diameter = Radius * 2.f / 100.f * FMath::Lerp(1.4f, 1.f, Alpha);
	Marker->SetRelativeScale3D(FVector(Diameter, Diameter, 0.03f));
	if (MarkerMaterial)
	{
		MarkerMaterial->SetScalarParameterValue(TEXT("Intensity"), 1.5f + 1.5f * FMath::Abs(FMath::Sin(Age * (8.f + 30.f * Alpha))));
	}
}

void ARPGDelayedBlast::SnapToGround()
{
	FHitResult Hit;
	const FVector Location = GetActorLocation();
	FCollisionQueryParams Params(SCENE_QUERY_STAT(RPGBlastGround), false);
	Params.AddIgnoredActor(this);
	if (const ARPGCharacterBase* Target = TrackedTarget.Get())
	{
		Params.AddIgnoredActor(Target);
	}
	if (GetWorld()->LineTraceSingleByChannel(Hit, Location + FVector(0.f, 0.f, 400.f), Location - FVector(0.f, 0.f, 2000.f), ECC_WorldStatic, Params))
	{
		SetActorLocation(Hit.ImpactPoint + FVector(0.f, 0.f, 3.f));
	}
}

void ARPGDelayedBlast::Detonate()
{
	const FVector Ground = GetActorLocation();
	AActor* InstigatorActor = GetInstigator();

	for (ARPGCharacterBase* Target : URPGCombatLibrary::GetHostilesInRadius(this, InstigatorActor, Ground + FVector(0.f, 0.f, 90.f), Radius))
	{
		URPGCombatLibrary::DealDamage(Target, Damage, InstigatorActor, this, DamageType);
		if (Target->IsAlive() && StunDuration > 0.f)
		{
			Target->GetStatusEffects()->ApplyStun(StunDuration);
		}
	}

	// Bolt from the sky.
	FRPGFXParams Bolt;
	Bolt.Shape = ERPGFXShape::Cylinder;
	Bolt.Color = Color;
	Bolt.Intensity = 40.f;
	Bolt.FresnelAmount = 0.f;
	Bolt.Lifetime = 0.35f;
	Bolt.GrowTime = 0.05f;
	Bolt.StartScale = FVector(0.5f, 0.5f, 40.f);
	Bolt.EndScale = FVector(0.25f, 0.25f, 40.f);
	Bolt.Flicker = 0.7f;
	ARPGTransientFX::Spawn(this, Ground + FVector(0.f, 0.f, 2000.f), FRotator::ZeroRotator, Bolt);

	FRPGFXParams Impact;
	Impact.Color = Color;
	Impact.Intensity = 12.f;
	Impact.FresnelAmount = 0.5f;
	Impact.Lifetime = 0.5f;
	Impact.GrowTime = 0.15f;
	Impact.StartScale = FVector(0.5f);
	Impact.EndScale = FVector(Radius * 2.f / 100.f, Radius * 2.f / 100.f, Radius / 100.f);
	Impact.LightIntensity = 20000.f;
	Impact.LightRadius = Radius * 6.f;
	Impact.Flicker = 0.5f;
	ARPGTransientFX::Spawn(this, Ground, FRotator::ZeroRotator, Impact);

	Destroy();
}
