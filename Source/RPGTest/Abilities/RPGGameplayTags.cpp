#include "Abilities/RPGGameplayTags.h"

namespace RPGTags
{
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Dead, "State.Dead", "Health reached zero.");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Casting, "State.Casting", "An ability is being cast or channeled.");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(State_Casting_Slow, "State.Casting.Slow", "Casting an ability that slows the caster.");

	UE_DEFINE_GAMEPLAY_TAG(Cooldown, "Cooldown");

	UE_DEFINE_GAMEPLAY_TAG(Status, "Status");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Status_CC,"Status.CC", "Incapacitated: cannot move, cast or attack.");
	UE_DEFINE_GAMEPLAY_TAG(Status_CC_Stun, "Status.CC.Stun");
	UE_DEFINE_GAMEPLAY_TAG(Status_CC_Freeze, "Status.CC.Freeze");
	UE_DEFINE_GAMEPLAY_TAG(Status_CC_Fear, "Status.CC.Fear");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Status_Root, "Status.Root", "Cannot move but can still cast.");
	UE_DEFINE_GAMEPLAY_TAG(Status_Slow, "Status.Slow");
	UE_DEFINE_GAMEPLAY_TAG(Status_Haste, "Status.Haste");
	UE_DEFINE_GAMEPLAY_TAG(Status_Stealth, "Status.Stealth");
	UE_DEFINE_GAMEPLAY_TAG_COMMENT(Status_Barrier, "Status.Barrier", "A damage-absorbing shield is up (the amount is the Shield attribute).");
	UE_DEFINE_GAMEPLAY_TAG(Status_DivineShield, "Status.DivineShield");
	UE_DEFINE_GAMEPLAY_TAG(Status_HealingReduced, "Status.HealingReduced");
	UE_DEFINE_GAMEPLAY_TAG(Status_DoT, "Status.DoT");
	UE_DEFINE_GAMEPLAY_TAG(Status_DoT_Burn, "Status.DoT.Burn");
	UE_DEFINE_GAMEPLAY_TAG(Status_DoT_Corruption, "Status.DoT.Corruption");
	UE_DEFINE_GAMEPLAY_TAG(Status_DoT_Poison, "Status.DoT.Poison");
	UE_DEFINE_GAMEPLAY_TAG(Status_Immune_CC, "Status.Immune.CC");
	UE_DEFINE_GAMEPLAY_TAG(Status_Immune_Slow, "Status.Immune.Slow");

	UE_DEFINE_GAMEPLAY_TAG(Trait_FrontalBlock, "Trait.FrontalBlock");

	UE_DEFINE_GAMEPLAY_TAG(Damage, "Damage");
	UE_DEFINE_GAMEPLAY_TAG(Damage_Physical, "Damage.Physical");
	UE_DEFINE_GAMEPLAY_TAG(Damage_Fire, "Damage.Fire");
	UE_DEFINE_GAMEPLAY_TAG(Damage_Frost, "Damage.Frost");
	UE_DEFINE_GAMEPLAY_TAG(Damage_Lightning, "Damage.Lightning");
	UE_DEFINE_GAMEPLAY_TAG(Damage_Arcane, "Damage.Arcane");
	UE_DEFINE_GAMEPLAY_TAG(Damage_Shadow, "Damage.Shadow");
	UE_DEFINE_GAMEPLAY_TAG(Damage_Holy, "Damage.Holy");
	UE_DEFINE_GAMEPLAY_TAG(Damage_Nature, "Damage.Nature");

	UE_DEFINE_GAMEPLAY_TAG(Data_Damage, "Data.Damage");
	UE_DEFINE_GAMEPLAY_TAG(Data_Heal, "Data.Heal");
	UE_DEFINE_GAMEPLAY_TAG(Data_Cost, "Data.Cost");
	UE_DEFINE_GAMEPLAY_TAG(Data_Duration, "Data.Duration");
	UE_DEFINE_GAMEPLAY_TAG(Data_Magnitude, "Data.Magnitude");

	FLinearColor GetDamageTypeColor(const FGameplayTag& DamageType)
	{
		struct FEntry
		{
			FGameplayTag Tag;
			FLinearColor Color;
		};
		static const FEntry Colors[] =
		{
			{ Damage_Physical, FLinearColor(1.f, 0.35f, 0.3f) },
			{ Damage_Fire, FLinearColor(1.f, 0.55f, 0.1f) },
			{ Damage_Frost, FLinearColor(0.45f, 0.85f, 1.f) },
			{ Damage_Lightning, FLinearColor(0.95f, 0.95f, 0.4f) },
			{ Damage_Arcane, FLinearColor(0.85f, 0.55f, 1.f) },
			{ Damage_Shadow, FLinearColor(0.7f, 0.35f, 0.95f) },
			{ Damage_Holy, FLinearColor(1.f, 0.9f, 0.45f) },
			{ Damage_Nature, FLinearColor(0.45f, 0.95f, 0.3f) },
		};
		for (const FEntry& Entry : Colors)
		{
			if (DamageType.MatchesTag(Entry.Tag))
			{
				return Entry.Color;
			}
		}
		return FLinearColor::White;
	}
}
