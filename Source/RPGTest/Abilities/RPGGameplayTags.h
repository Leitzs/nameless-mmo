#pragma once

#include "CoreMinimal.h"
#include "NativeGameplayTags.h"

/**
 * Native gameplay tags shared by the whole combat system. Defining them in C++ means no tag tables or .ini entries
 * are needed. Class kits define their own cooldown tags next to their abilities (Cooldown.<Class>.<Ability>).
 */
namespace RPGTags
{
	// Character state.
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(State_Dead);
	/** Owned while an ability is being cast or channeled: blocks other abilities. */
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(State_Casting);
	/** Child of State.Casting for abilities that also slow the caster down while casting. */
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(State_Casting_Slow);

	/** Parent of every ability cooldown tag (Cooldown.<Class>.<Ability>). */
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Cooldown);

	// Status effects (granted by the effects in RPGStatusEffects.h).
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status);
	/** Parent of every incapacitating effect: cannot move, cast or attack. */
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_CC);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_CC_Stun);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_CC_Freeze);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_CC_Fear);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_Root);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_Slow);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_Haste);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_Stealth);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_Barrier);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_DivineShield);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_HealingReduced);
	/** Parent of every damage-over-time effect. */
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_DoT);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_DoT_Burn);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_DoT_Corruption);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_DoT_Poison);
	/** Immune to incapacitating effects, roots and slows. */
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_Immune_CC);
	/** Immune to roots and slows. */
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Status_Immune_Slow);

	// Passive traits, granted as loose tags by a class.
	/** Takes less damage from attacks coming from the front (shield bearer). */
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Trait_FrontalBlock);

	// Damage types. They color the floating combat text.
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Damage);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Damage_Physical);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Damage_Fire);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Damage_Frost);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Damage_Lightning);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Damage_Arcane);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Damage_Shadow);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Damage_Holy);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Damage_Nature);

	// Set-by-caller magnitudes.
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Data_Damage);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Data_Heal);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Data_Cost);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Data_Duration);
	RPGTEST_API UE_DECLARE_GAMEPLAY_TAG_EXTERN(Data_Magnitude);

	/** Floating text color for a damage type tag (white when unknown). */
	RPGTEST_API FLinearColor GetDamageTypeColor(const FGameplayTag& DamageType);
}
