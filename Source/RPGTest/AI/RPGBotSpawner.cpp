#include "AI/RPGBotSpawner.h"

#include "Characters/EnemyBotCharacter.h"
#include "Components/BillboardComponent.h"
#include "Components/CapsuleComponent.h"
#include "Engine/World.h"
#include "RPGTest.h"
#include "TimerManager.h"

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

	BotClass = AEnemyBotCharacter::StaticClass();
}

void ARPGBotSpawner::BeginPlay()
{
	Super::BeginPlay();

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
