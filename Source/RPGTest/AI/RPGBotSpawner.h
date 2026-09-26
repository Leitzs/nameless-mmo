#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "RPGBotSpawner.generated.h"

class AEnemyBotCharacter;
class UBillboardComponent;
class UInstancedStaticMeshComponent;

/**
 * Spawns enemy bots around itself when play begins and respawns each one a while after it dies.
 * Can draw the bot's patrol, aggro and leash ranges on the ground as dashed rings (useful on test maps).
 */
UCLASS()
class RPGTEST_API ARPGBotSpawner : public AActor
{
	GENERATED_BODY()

public:
	ARPGBotSpawner();

	virtual void OnConstruction(const FTransform& Transform) override;

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

	/**
	 * Draws flat dashed rings at the spawner's height: patrol radius (green), aggro range (amber) and leash range (red),
	 * read from the bot class defaults. The rings are centered on the spawner, so keep SpawnRadius small when using them.
	 */
	UPROPERTY(EditAnywhere, Category = "Spawner|Debug")
	bool bShowRangeRings = false;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<USceneComponent> SceneRoot;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UInstancedStaticMeshComponent> RangeRings;

#if WITH_EDITORONLY_DATA
	UPROPERTY()
	TObjectPtr<UBillboardComponent> Sprite;
#endif

private:
	void BuildRangeRings();

	UPROPERTY(Transient)
	TArray<TObjectPtr<AEnemyBotCharacter>> Bots;
};
