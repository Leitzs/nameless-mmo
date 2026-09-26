#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "Core/RPGTypes.h"
#include "RPGSpellbookComponent.generated.h"

class ARPGCharacterBase;
class URPGSpell;

DECLARE_DYNAMIC_MULTICAST_DELEGATE_TwoParams(FRPGOnSpellCast, int32, SlotIndex, URPGSpell*, Spell);

/** Holds a character's spells (one per hotbar slot), validates casts and runs them in sync with the cast animation. */
UCLASS(ClassGroup = (RPG), meta = (BlueprintSpawnableComponent))
class RPGTEST_API URPGSpellbookComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	URPGSpellbookComponent();

	/** Replaces the spell classes. Takes effect on BeginPlay. */
	void SetSpellClasses(const TArray<TSubclassOf<URPGSpell>>& InSpellClasses) { SpellClasses = InSpellClasses; }

	/** Checks everything that could prevent casting the spell in SlotIndex. */
	UFUNCTION(BlueprintPure, Category = "Spells")
	ERPGCastResult CanCast(int32 SlotIndex) const;

	/** Starts casting the spell in SlotIndex (0-based). */
	UFUNCTION(BlueprintCallable, Category = "Spells")
	ERPGCastResult TryCast(int32 SlotIndex);

	UFUNCTION(BlueprintPure, Category = "Spells")
	bool IsCasting() const;

	int32 GetNumSpells() const { return Spells.Num(); }
	URPGSpell* GetSpell(int32 SlotIndex) const { return Spells.IsValidIndex(SlotIndex) ? Spells[SlotIndex] : nullptr; }

	/** Clears all cooldowns (debug). */
	void ResetCooldowns();

	UPROPERTY(BlueprintAssignable, Category = "Spells")
	FRPGOnSpellCast OnSpellCast;

protected:
	virtual void BeginPlay() override;

	/** Hotbar order: index 0 is bound to key 1. */
	UPROPERTY(EditDefaultsOnly, Category = "Spells")
	TArray<TSubclassOf<URPGSpell>> SpellClasses;

private:
	void ReleaseSpell(URPGSpell* Spell);
	ARPGCharacterBase* GetCaster() const;

	UPROPERTY(Transient)
	TArray<TObjectPtr<URPGSpell>> Spells;

	double CastEndTime = 0.0;
	FTimerHandle ReleaseTimer;
};
