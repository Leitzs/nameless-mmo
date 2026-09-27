#include "AI/RPGBotSpawner.h"

#include "Characters/EnemyBotCharacter.h"
#include "Components/BillboardComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "RPGTest.h"
#include "TimerManager.h"
#include "UObject/ConstructorHelpers.h"

ARPGBotSpawner::ARPGBotSpawner()
{
	PrimaryActorTick.bCanEverTick = false;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	RootComponent = SceneRoot;

#if WITH_EDITORONLY_DATA
	Sprite = CreateEditorOnlyDefaultSubobject<UBillboardComponent>(TEXT("Sprite"));
	if (Sprite)
	{
		Sprite->SetupAttachment(SceneRoot);
	}
#endif

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMesh(RPGAssets::CubeMesh);
	RangeRings = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("RangeRings"));
	RangeRings->SetupAttachment(SceneRoot);
	RangeRings->SetStaticMesh(CubeMesh.Object);
	RangeRings->SetUsingAbsoluteRotation(true);
	RangeRings->SetUsingAbsoluteScale(true);
	RangeRings->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	RangeRings->SetCanEverAffectNavigation(false);
	RangeRings->SetCastShadow(false);

	BotClass = AEnemyBotCharacter::StaticClass();
}

void ARPGBotSpawner::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);

	BuildRangeRings();
}

void ARPGBotSpawner::BuildRangeRings()
{
	RangeRings->ClearInstances();

	const AEnemyBotCharacter* BotDefaults = BotClass ? BotClass->GetDefaultObject<AEnemyBotCharacter>() : nullptr;
	if (!bShowRangeRings || !BotDefaults)
	{
		return;
	}

	TArray<FTransform> Transforms;
	TArray<float> CustomData;
	auto AddRing = [&Transforms, &CustomData](float Radius, float Width, const FLinearColor& Color)
	{
		// Dashes about 1.5 m long with equal gaps, 2 cm tall so they sit on the floor without z-fighting.
		const int32 Dashes = FMath::Max(12, FMath::RoundToInt(UE_TWO_PI * Radius / 300.f));
		const float DashLength = UE_PI * Radius / Dashes;
		for (int32 Index = 0; Index < Dashes; ++Index)
		{
			const float Angle = UE_TWO_PI * Index / Dashes;
			Transforms.Emplace(FRotator(0.f, FMath::RadiansToDegrees(Angle) + 90.f, 0.f), FVector(FMath::Cos(Angle) * Radius, FMath::Sin(Angle) * Radius, 1.f),
				FVector(DashLength / 100.f, Width / 100.f, 0.02f));
			CustomData.Append(RPGAssets::MakeInstanceData(Color, 0.6f, 1.5f));
		}
	};
	AddRing(BotDefaults->GetPatrolRadius(), 16.f, FLinearColor(0.1f, 0.55f, 0.12f));
	AddRing(BotDefaults->GetAggroRange(), 24.f, FLinearColor(0.9f, 0.5f, 0.04f));
	AddRing(BotDefaults->GetLeashRange(), 24.f, FLinearColor(0.75f, 0.07f, 0.05f));

	RangeRings->SetNumCustomDataFloats(RPGAssets::NumInstanceDataFloats);
	if (UMaterialInterface* Surface = RPGAssets::LoadMaterial(RPGAssets::SurfaceMaterial))
	{
		RangeRings->SetMaterial(0, Surface);
	}
	RangeRings->AddInstances(Transforms, false, false);
	for (int32 Index = 0; Index < Transforms.Num(); ++Index)
	{
		RangeRings->SetCustomData(Index, MakeArrayView(CustomData.GetData() + Index * RPGAssets::NumInstanceDataFloats, RPGAssets::NumInstanceDataFloats), false);
	}
	RangeRings->MarkRenderStateDirty();
}

void ARPGBotSpawner::BeginPlay()
{
	Super::BeginPlay();

	// Bots are server actors; clients receive them through replication.
	if (!HasAuthority())
	{
		return;
	}

	for (int32 Index = 0; Index < BotCount; ++Index)
	{
		SpawnBot();
	}
}

AEnemyBotCharacter* ARPGBotSpawner::SpawnBot()
{
	UWorld* World = GetWorld();
	if (!World || !BotClass)
	{
		return nullptr;
	}

	const AEnemyBotCharacter* BotDefaults = BotClass->GetDefaultObject<AEnemyBotCharacter>();
	const float HalfHeight = BotDefaults->GetCapsuleComponent()->GetScaledCapsuleHalfHeight();

	FVector Location = GetActorLocation() + FVector(FMath::RandPointInCircle(SpawnRadius), 0.f);
	FHitResult Hit;
	FCollisionQueryParams Params(SCENE_QUERY_STAT(RPGBotSpawn), false, this);
	if (World->LineTraceSingleByChannel(Hit, Location + FVector(0.f, 0.f, 1000.f), Location - FVector(0.f, 0.f, 3000.f), ECC_WorldStatic, Params))
	{
		Location = Hit.ImpactPoint + FVector(0.f, 0.f, HalfHeight + 5.f);
	}

	FActorSpawnParameters SpawnParams;
	SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;
	const FRotator Rotation(0.f, GetActorRotation().Yaw + FMath::FRandRange(-45.f, 45.f), 0.f);

	AEnemyBotCharacter* Bot = World->SpawnActor<AEnemyBotCharacter>(BotClass, Location, Rotation, SpawnParams);
	if (!Bot)
	{
		UE_LOG(LogRPG, Warning, TEXT("%s failed to spawn a bot"), *GetName());
		return nullptr;
	}

	Bot->SetHomeLocation(Location);
	Bot->OnDestroyed.AddDynamic(this, &ThisClass::HandleBotDestroyed);
	Bots.Add(Bot);
	return Bot;
}

void ARPGBotSpawner::HandleBotDestroyed(AActor* DestroyedActor)
{
	Bots.RemoveAll([DestroyedActor](const TObjectPtr<AEnemyBotCharacter>& Bot) { return Bot == DestroyedActor; });

	if (!GetWorld() || GetWorld()->bIsTearingDown || IsActorBeingDestroyed())
	{
		return;
	}

	FTimerHandle RespawnTimer;
	GetWorldTimerManager().SetTimer(RespawnTimer, FTimerDelegate::CreateWeakLambda(this, [this]() { SpawnBot(); }), FMath::Max(0.1f, RespawnDelay), false);
}
