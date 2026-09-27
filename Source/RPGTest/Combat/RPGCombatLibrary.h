#pragma once

#include "CoreMinimal.h"
#include "GameplayTagContainer.h"
#include "Kismet/BlueprintFunctionLibrary.h"
#include "Abilities/RPGStatusEffects.h"
#include "RPGCombatLibrary.generated.h"

class ARPGCharacterBase;

/**
 * Stateless combat helpers shared by abilities, projectiles and AI. The Apply* functions are the only way gameplay
 * code deals damage, heals or applies statuses: they build gameplay effect specs so every rule (shields, immunities,
 * diminishing returns, rage, kill credit) runs in one place. Call them on the server.
 */
UCLASS()
class RPGTEST_API URPGCombatLibrary : public UBlueprintFunctionLibrary
{
	GENERATED_BODY()

public:
	/** The character responsible for an actor: itself if it is a character, otherwise its instigator. */
	UFUNCTION(BlueprintPure, Category = "RPG|Combat")
	static ARPGCharacterBase* GetResponsibleCharacter(const AActor* Actor);

	/** Characters on different teams are hostile, and so are two player characters in deathmatch (ARPGGameState). Unknown actors are treated as hostile. */
	UFUNCTION(BlueprintPure, Category = "RPG|Combat")
	static bool AreHostile(const AActor* A, const AActor* B);

	/** Living characters hostile to Instigator whose capsule overlaps the sphere. */
	UFUNCTION(BlueprintCallable, Category = "RPG|Combat", meta = (WorldContext = "WorldContextObject"))
	static TArray<ARPGCharacterBase*> GetHostilesInRadius(const UObject* WorldContextObject, const AActor* Instigator, FVector Center, float Radius);

	/** Living hostiles within Range (to their capsule edge) and inside a horizontal cone of ArcDegrees in front of Attacker. */
	static TArray<ARPGCharacterBase*> GetHostilesInArc(const ARPGCharacterBase* Attacker, float Range, float ArcDegrees);

	/**
	 * The enemy a melee swing connects with: Preferred (the soft-locked target) when it is in reach, otherwise the
	 * closest hostile in the arc. Null when the swing whiffs.
	 */
	static ARPGCharacterBase* FindMeleeTarget(const ARPGCharacterBase* Attacker, ARPGCharacterBase* Preferred, float Range, float ArcDegrees);

	/** Attacker stands behind Victim (within MaxAngleDegrees of the victim's back direction). */
	UFUNCTION(BlueprintPure, Category = "RPG|Combat")
	static bool IsBehind(const AActor* Attacker, const AActor* Victim, float MaxAngleDegrees = 70.f);

	/** Deals damage of a Damage.* type. Source is the attacking character, Causer the projectile/actor that hit (optional). */
	static bool ApplyDamage(AActor* Source, ARPGCharacterBase* Target, float Amount, const FGameplayTag& DamageType, AActor* Causer = nullptr);

	static bool ApplyHeal(AActor* Source, ARPGCharacterBase* Target, float Amount);

	static bool ApplyStatus(AActor* Source, ARPGCharacterBase* Target, const FRPGStatusSpec& Status, AActor* Causer = nullptr);
	static void ApplyStatuses(AActor* Source, ARPGCharacterBase* Target, const TArray<FRPGStatusSpec>& Statuses, AActor* Causer = nullptr);
};
