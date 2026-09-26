#pragma once

#include "CoreMinimal.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "RPGCombatLibrary.generated.h"

class ARPGCharacterBase;
class UDamageType;

/** Stateless combat helpers shared by spells, projectiles and AI. */
UCLASS()
class RPGTEST_API URPGCombatLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/** The character responsible for an actor: itself if it is a character, otherwise its instigator. */
	UFUNCTION(BlueprintPure, Category = "RPG|Combat")
	static ARPGCharacterBase* GetResponsibleCharacter(const AActor* Actor);

	/** Who dealt damage: the instigating controller's pawn if any, otherwise the causer (or its instigator). */
	static AActor* ResolveInstigator(AController* EventInstigator, AActor* DamageCauser);

	/** Characters on different teams are hostile. Unknown actors are treated as hostile. */
	UFUNCTION(BlueprintPure, Category = "RPG|Combat")
	static bool AreHostile(const AActor* A, const AActor* B);

	/** Living characters hostile to Instigator whose capsule overlaps the sphere. */
	UFUNCTION(BlueprintCallable, Category = "RPG|Combat", meta = (WorldContext = "WorldContextObject"))
	static TArray<ARPGCharacterBase*> GetHostilesInRadius(const UObject* WorldContextObject, const AActor* Instigator, FVector Center, float Radius);

	/** Routes damage through the engine damage pipeline with the instigator's controller as event instigator. */
	UFUNCTION(BlueprintCallable, Category = "RPG|Combat")
	static float DealDamage(AActor* Target, float Amount, AActor* InstigatorActor, AActor* DamageCauser, TSubclassOf<UDamageType> DamageType);
};
