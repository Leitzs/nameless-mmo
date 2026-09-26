#include "Spells/RPGProjectile.h"

#include "Characters/RPGCharacterBase.h"
#include "Combat/RPGCombatLibrary.h"
#include "Combat/RPGDamageTypes.h"
#include "Components/PointLightComponent.h"
#include "Components/RPGStatusEffectComponent.h"
#include "Components/SphereComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/StaticMesh.h"
#include "FX/RPGTransientFX.h"
#include "GameFramework/ProjectileMovementComponent.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"

ARPGProjectile::ARPGProjectile()
{
	PrimaryActorTick.bCanEverTick = true;
	SetCanBeDamaged(false);
	InitialLifeSpan = 2.f;

	Collision = CreateDefaultSubobject<USphereComponent>(TEXT("Collision"));
	Collision->InitSphereRadius(16.f);
	Collision->SetCollisionObjectType(ECC_WorldDynamic);
	Collision->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
	Collision->SetCollisionResponseToAllChannels(ECR_Ignore);
	Collision->SetCollisionResponseToChannel(ECC_WorldStatic, ECR_Block);
	Collision->SetCollisionResponseToChannel(ECC_WorldDynamic, ECR_Block);
	Collision->SetCollisionResponseToChannel(ECC_Pawn, ECR_Block);
	Collision->SetNotifyRigidBodyCollision(true);
	Collision->SetCanEverAffectNavigation(false);
	RootComponent = Collision;

	static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(RPGAssets::SphereMesh);

	Core = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Core"));
	Core->SetupAttachment(Collision);
	Core->SetStaticMesh(SphereMesh.Object);
	Core->SetRelativeScale3D(FVector(0.34f));
	Core->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Core->SetCastShadow(false);

	Glow = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Glow"));
	Glow->SetupAttachment(Collision);
	Glow->SetStaticMesh(SphereMesh.Object);
	Glow->SetRelativeScale3D(FVector(0.7f));
	Glow->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Glow->SetCastShadow(false);

	Light = CreateDefaultSubobject<UPointLightComponent>(TEXT("Light"));
	Light->SetupAttachment(Collision);
	Light->SetIntensityUnits(ELightUnits::Candelas);
	Light->SetIntensity(400.f);
	Light->SetAttenuationRadius(700.f);
	Light->SetCastShadows(false);

	Movement = CreateDefaultSubobject<UProjectileMovementComponent>(TEXT("Movement"));
	Movement->UpdatedComponent = Collision;
	Movement->InitialSpeed = 2600.f;
	Movement->MaxSpeed = 2600.f;
	Movement->bRotationFollowsVelocity = true;
	Movement->bShouldBounce = false;
	Movement->ProjectileGravityScale = 0.f;

	Damage.DamageType = UDamageType_Fire::StaticClass();
}

void ARPGProjectile::Configure(const FRPGProjectileDamage& InDamage, const FLinearColor& InColor, float Speed)
{
	Damage = InDamage;
	Color = InColor;
	Movement->InitialSpeed = Speed;
	Movement->MaxSpeed = Speed;
}

void ARPGProjectile::SetHomingTarget(AActor* Target, float Acceleration)
{
	if (Target && Acceleration > 0.f)
	{
		Movement->bIsHomingProjectile = true;
		Movement->HomingTargetComponent = Target->GetRootComponent();
		Movement->HomingAccelerationMagnitude = Acceleration;
	}
}

void ARPGProjectile::BeginPlay()
{
	Super::BeginPlay();

	if (AActor* InstigatorActor = GetInstigator())
	{
		Collision->IgnoreActorWhenMoving(InstigatorActor, true);
	}
	Collision->OnComponentHit.AddDynamic(this, &ThisClass::HandleHit);

	CoreMaterial = RPGAssets::CreateFXMaterial(this, FLinearColor::LerpUsingHSV(Color, FLinearColor(1.f, 0.9f, 0.6f), 0.5f), 25.f, 0.1f);
	if (CoreMaterial)
	{
		Core->SetMaterial(0, CoreMaterial);
	}
	if (UMaterialInstanceDynamic* GlowMaterial = RPGAssets::CreateFXMaterial(this, Color, 6.f, 0.8f))
	{
		Glow->SetMaterial(0, GlowMaterial);
	}
	Light->SetLightColor(Color);
}

void ARPGProjectile::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (bExploded)
	{
		return;
	}

	if (CoreMaterial)
	{
		CoreMaterial->SetScalarParameterValue(TEXT("Intensity"), 20.f + 10.f * FMath::FRand());
	}

	TrailAccumulator += DeltaSeconds;
	while (TrailAccumulator >= TrailInterval)
	{
		TrailAccumulator -= TrailInterval;

		FRPGFXParams Spark;
		Spark.Color = Color;
		Spark.Intensity = 10.f;
		Spark.FresnelAmount = 0.3f;
		Spark.Lifetime = 0.3f;
		Spark.StartScale = FVector(0.32f);
		Spark.EndScale = FVector(0.04f);
		ARPGTransientFX::Spawn(this, GetActorLocation() + FMath::VRand() * 6.f, FRotator::ZeroRotator, Spark);
	}
}

void ARPGProjectile::LifeSpanExpired()
{
	// Reached max range: burst harmlessly in the air.
	FRPGFXParams Fizzle;
	Fizzle.Color = Color;
	Fizzle.Intensity = 6.f;
	Fizzle.Lifetime = 0.25f;
	Fizzle.StartScale = FVector(0.4f);
	Fizzle.EndScale = FVector(1.2f);
	ARPGTransientFX::Spawn(this, GetActorLocation(), FRotator::ZeroRotator, Fizzle);

	Super::LifeSpanExpired();
}

void ARPGProjectile::HandleHit(UPrimitiveComponent* HitComponent, AActor* OtherActor, UPrimitiveComponent* OtherComp, FVector NormalImpulse, const FHitResult& Hit)
{
	Explode(Hit.ImpactPoint, OtherActor);
}

void ARPGProjectile::Explode(const FVector& Location, AActor* DirectHitActor)
{
	if (bExploded)
	{
		return;
	}
	bExploded = true;

	AActor* InstigatorActor = GetInstigator();
	AController* InstigatorController = GetInstigatorController();

	auto ApplyBurn = [this, InstigatorController](ARPGCharacterBase* Target)
	{
		if (Damage.BurnDamagePerSecond > 0.f && Damage.BurnDuration > 0.f && Target->IsAlive())
		{
			Target->GetStatusEffects()->ApplyBurn(Damage.BurnDamagePerSecond, Damage.BurnDuration, InstigatorController, this);
		}
	};

	ARPGCharacterBase* DirectTarget = Cast<ARPGCharacterBase>(DirectHitActor);
	if (DirectTarget && DirectTarget->IsAlive() && URPGCombatLibrary::AreHostile(InstigatorActor, DirectTarget))
	{
		URPGCombatLibrary::DealDamage(DirectTarget, Damage.DirectDamage, InstigatorActor, this, Damage.DamageType);
		ApplyBurn(DirectTarget);
	}
	else
	{
		DirectTarget = nullptr;
	}

	for (ARPGCharacterBase* Target : URPGCombatLibrary::GetHostilesInRadius(this, InstigatorActor, Location, Damage.SplashRadius))
	{
		if (Target != DirectTarget)
		{
			URPGCombatLibrary::DealDamage(Target, Damage.SplashDamage, InstigatorActor, this, Damage.DamageType);
			ApplyBurn(Target);
		}
	}

	FRPGFXParams Blast;
	Blast.Color = Color;
	Blast.Intensity = 14.f;
	Blast.FresnelAmount = 0.35f;
	Blast.Lifetime = 0.45f;
	Blast.GrowTime = 0.2f;
	Blast.StartScale = FVector(0.3f);
	Blast.EndScale = FVector(Damage.SplashRadius * 2.f / 100.f);
	Blast.LightIntensity = 6000.f;
	Blast.LightRadius = Damage.SplashRadius * 4.f;
	ARPGTransientFX::Spawn(this, Location, FRotator::ZeroRotator, Blast);

	FRPGFXParams Flash;
	Flash.Color = FLinearColor(1.f, 0.85f, 0.5f);
	Flash.Intensity = 30.f;
	Flash.FresnelAmount = 0.f;
	Flash.Lifetime = 0.15f;
	Flash.StartScale = FVector(0.8f);
	Flash.EndScale = FVector(1.6f);
	ARPGTransientFX::Spawn(this, Location, FRotator::ZeroRotator, Flash);

	Destroy();
}
