#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RPGBotSpawner.generated.h"

class AEnemyBotCharacter;
class UBillboardComponent;

/** Spawns enemy bots around itself when play begins and respawns each one a while after it dies. */
UCLASS()
class RPGTEST_API ARPGBotSpawner : public AActor
{
	GENERATED_BODY()

public:
	ARPGBotSpawner();

	UFUNCTION(BlueprintCallable, Category = "Spawner")
	AEnemyBotCharacter* SpawnBot();

	const TArray<TObjectPtr<AEnemyBotCharacter>>& GetBots() const { return Bots; }

protected:
	virtual void BeginPlay() override;

	UFUNCTION()
	void HandleBotDestroyed(AActor* DestroyedActor);

	UPROPERTY(EditAnywhere, Category = "Spawner")
	TSubclassOf<AEnemyBotCharacter> BotClass;

	UPROPERTY(EditAnywhere, Category = "Spawner", meta = (ClampMin = "0"))
	int32 BotCount = 1;

	/** Seconds after a bot's body disappears before a replacement spawns. */
	UPROPERTY(EditAnywhere, Category = "Spawner", meta = (ClampMin = "0"))
	float RespawnDelay = 5.f;

	UPROPERTY(EditAnywhere, Category = "Spawner", meta = (ClampMin = "0"))
	float SpawnRadius = 250.f;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<USceneComponent> SceneRoot;

#if WITH_EDITORONLY_DATA
	UPROPERTY()
	TObjectPtr<UBillboardComponent> Sprite;
#endif

private:
	UPROPERTY(Transient)
	TArray<TObjectPtr<AEnemyBotCharacter>> Bots;
};
