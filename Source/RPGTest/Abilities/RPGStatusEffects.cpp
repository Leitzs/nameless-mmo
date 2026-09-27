#include "Abilities/RPGStatusEffects.h"

#include "Abilities/RPGGameplayTags.h"

#define LOCTEXT_NAMESPACE "RPGStatusEffects"

namespace RPGStatusEffects
{
	namespace
	{
		TArray<FRPGStatusDefinition> BuildDefinitions()
		{
			using namespace RPGTags;

			TArray<FRPGStatusDefinition> Definitions;
			auto Add = [&Definitions](const FGameplayTag& Tag, const FText& Name, const FLinearColor& Color, bool bHarmful = true) -> FRPGStatusDefinition&
			{
				FRPGStatusDefinition& Definition = Definitions.AddDefaulted_GetRef();
				Definition.Tag = Tag;
				Definition.DisplayName = Name;
				Definition.Color = Color;
				Definition.bHarmful = bHarmful;
				return Definition;
			};

			const FGameplayTagContainer CCImmunity(Status_Immune_CC);
			FGameplayTagContainer MovementImmunity;
			MovementImmunity.AddTag(Status_Immune_CC);
			MovementImmunity.AddTag(Status_Immune_Slow);

			// Incapacitating effects (Status.CC.*). Magnitude unused.
			{
				FRPGStatusDefinition& Stun = Add(Status_CC_Stun, LOCTEXT("Stun", "STUNNED"), FLinearColor(1.f, 0.85f, 0.3f));
				Stun.DiminishingCategory = Status_CC_Stun;
				Stun.BlockedBy = CCImmunity;
				Stun.OverlayPriority = 70;
				Stun.OverlayIntensity = 2.f;

				FRPGStatusDefinition& Freeze = Add(Status_CC_Freeze, LOCTEXT("Freeze", "FROZEN"), FLinearColor(0.3f, 0.75f, 1.f));
				Freeze.DiminishingCategory = Status_CC_Freeze;
				Freeze.BlockedBy = CCImmunity;
				Freeze.OverlayPriority = 100;
				Freeze.OverlayIntensity = 3.f;

				// Runs in a panic; enough damage snaps the target out of it.
				FRPGStatusDefinition& Fear = Add(Status_CC_Fear, LOCTEXT("Fear", "FEARED"), FLinearColor(0.6f, 0.15f, 0.9f));
				Fear.DiminishingCategory = Status_CC_Fear;
				Fear.BlockedBy = CCImmunity;
				Fear.BreakDamageFraction = 0.15f;
				Fear.OverlayPriority = 90;
			}

			// Movement impairment. Slow magnitude is the speed multiplier (the strongest slow wins).
			{
				FRPGStatusDefinition& Root = Add(Status_Root, LOCTEXT("Root", "ROOTED"), FLinearColor(0.55f, 0.8f, 0.35f));
				Root.DiminishingCategory = Status_Root;
				Root.BlockedBy = MovementImmunity;
				Root.OverlayPriority = 40;
				Root.OverlayIntensity = 1.5f;

				FRPGStatusDefinition& Slow = Add(Status_Slow, LOCTEXT("Slow", "SLOWED"), FLinearColor(0.6f, 0.9f, 1.f));
				Slow.BlockedBy = MovementImmunity;
			}

			// Damage over time. Magnitude is damage per second; a new application refreshes the old one.
			{
				FRPGStatusDefinition& Burn = Add(Status_DoT_Burn, LOCTEXT("Burn", "BURNING"), FLinearColor(1.f, 0.35f, 0.05f));
				Burn.DamageOverTimeType = Damage_Fire;
				Burn.bReplaceExisting = true;
				Burn.OverlayPriority = 30;
				Burn.OverlayIntensity = 2.5f;
				Burn.OverlayFresnel = 0.9f;

				FRPGStatusDefinition& Corruption = Add(Status_DoT_Corruption, LOCTEXT("Corruption", "CORRUPTED"), FLinearColor(0.55f, 0.1f, 0.75f));
				Corruption.DamageOverTimeType = Damage_Shadow;
				Corruption.bReplaceExisting = true;
				Corruption.OverlayPriority = 25;
				Corruption.OverlayIntensity = 1.5f;

				FRPGStatusDefinition& Poison = Add(Status_DoT_Poison, LOCTEXT("Poison", "POISONED"), FLinearColor(0.35f, 0.9f, 0.2f));
				Poison.DamageOverTimeType = Damage_Nature;
				Poison.bReplaceExisting = true;
				Poison.OverlayPriority = 20;
				Poison.OverlayIntensity = 1.5f;
			}

			// Other debuffs. Magnitude is the healing multiplier.
			{
				FRPGStatusDefinition& HealingReduced = Add(Status_HealingReduced, LOCTEXT("HealingReduced", "WOUNDED"), FLinearColor(0.85f, 0.2f, 0.2f));
				HealingReduced.bReplaceExisting = true;
			}

			// Buffs.
			{
				// Magnitude is the speed multiplier while hidden.
				FRPGStatusDefinition& Stealth = Add(Status_Stealth, LOCTEXT("Stealth", "STEALTH"), FLinearColor(0.5f, 0.55f, 0.7f), false);
				Stealth.bReplaceExisting = true;
				Stealth.BreakDamageFraction = 0.f;

				// Magnitude is the speed multiplier (the strongest haste wins).
				FRPGStatusDefinition& Haste = Add(Status_Haste, LOCTEXT("Haste", "HASTE"), FLinearColor(1.f, 0.55f, 0.2f), false);
				Haste.bReplaceExisting = true;
				Haste.OverlayPriority = 10;
				Haste.OverlayIntensity = 1.2f;

				// The absorbed amount is the Shield attribute; the status only times it.
				FRPGStatusDefinition& Barrier = Add(Status_Barrier, LOCTEXT("Barrier", "SHIELDED"), FLinearColor(0.6f, 0.3f, 1.f), false);
				Barrier.bReplaceExisting = true;
				Barrier.OverlayPriority = 5;
				Barrier.OverlayIntensity = 1.5f;
				Barrier.OverlayFresnel = 1.f;

				// Immune to damage. Magnitude is the multiplier on the damage the shielded character deals.
				FRPGStatusDefinition& DivineShield = Add(Status_DivineShield, LOCTEXT("DivineShield", "DIVINE SHIELD"), FLinearColor(1.f, 0.85f, 0.35f), false);
				DivineShield.bReplaceExisting = true;
				DivineShield.OverlayPriority = 95;
				DivineShield.OverlayIntensity = 3.f;
				DivineShield.OverlayFresnel = 1.f;

				FRPGStatusDefinition& ImmuneCC = Add(Status_Immune_CC, LOCTEXT("ImmuneCC", "UNSTOPPABLE"), FLinearColor(1.f, 0.95f, 0.7f), false);
				ImmuneCC.bReplaceExisting = true;

				FRPGStatusDefinition& ImmuneSlow = Add(Status_Immune_Slow, LOCTEXT("ImmuneSlow", "FREEDOM"), FLinearColor(1.f, 0.8f, 0.5f), false);
				ImmuneSlow.bReplaceExisting = true;
			}

			return Definitions;
		}
	}

	const TArray<FRPGStatusDefinition>& GetDefinitions()
	{
		static const TArray<FRPGStatusDefinition> Definitions = BuildDefinitions();
		return Definitions;
	}

	const FRPGStatusDefinition* Find(const FGameplayTag& Tag)
	{
		return GetDefinitions().FindByPredicate([&Tag](const FRPGStatusDefinition& Definition) { return Definition.Tag == Tag; });
	}
}

#undef LOCTEXT_NAMESPACE
