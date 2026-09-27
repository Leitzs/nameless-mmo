#include "Spells/PaladinSpells.h"

#include "Abilities/RPGGameplayTags.h"
#include "Core/RPGAssets.h"

#define LOCTEXT_NAMESPACE "RPGPaladinSpells"

namespace PaladinSpellTags
{
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_CrusaderStrike, "Cooldown.Paladin.CrusaderStrike");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_HammerOfJustice, "Cooldown.Paladin.HammerOfJustice");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_FlashOfLight, "Cooldown.Paladin.FlashOfLight");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Cleanse, "Cooldown.Paladin.Cleanse");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_DivineShield, "Cooldown.Paladin.DivineShield");
}

namespace PaladinSpellsPrivate
{
	const FLinearColor HolyColor(1.f, 0.85f, 0.4f);
}

USpell_SwordSwing::USpell_SwordSwing()
{
	AddComboAnimation(RPGAssets::AttackAnim1);
	AddComboAnimation(RPGAssets::AttackAnim2);

	DisplayName = LOCTEXT("SwordSwingName", "Sword Swing");
	Description = LOCTEXT("SwordSwingDesc", "A two-hit sword combo. Your shield blocks 15% of the damage from attacks in front of you.");
	Color = FLinearColor(0.85f, 0.85f, 0.95f);
	CastTime = 0.6f;
	ReleaseDelay = 0.25f;
	AnimationPlayRate = 1.4f;

	Damage = 14.f;
	Reach = 210.f;
	ArcDegrees = 110.f;
}

USpell_CrusaderStrike::USpell_CrusaderStrike()
{
	SetCastAnimation(RPGAssets::AttackAnim3);

	DisplayName = LOCTEXT("CrusaderStrikeName", "Crusader Strike");
	Description = LOCTEXT("CrusaderStrikeDesc", "A strike infused with holy light. Restores 12 mana when it connects.");
	Color = PaladinSpellsPrivate::HolyColor;
	CooldownTag = PaladinSpellTags::Cooldown_CrusaderStrike;
	Cooldown = 5.f;
	CastTime = 0.6f;
	ReleaseDelay = 0.25f;
	AnimationPlayRate = 1.3f;

	Damage = 26.f;
	DamageType = RPGTags::Damage_Holy;
	Reach = 220.f;
	ArcDegrees = 100.f;
	ResourceOnHit = 12.f;
}

USpell_HammerOfJustice::USpell_HammerOfJustice()
{
	SetCastAnimation(RPGAssets::AttackAnim2);

	DisplayName = LOCTEXT("HammerName", "Hammer of Justice");
	Description = LOCTEXT("HammerDesc", "Throws a hammer of light that stuns the first enemy it hits for 1.5 seconds. Short range.");
	Color = PaladinSpellsPrivate::HolyColor;
	CooldownTag = PaladinSpellTags::Cooldown_HammerOfJustice;
	ResourceCost = 25.f;
	Cooldown = 20.f;
	CastTime = 0.45f;
	ReleaseDelay = 0.2f;
	Range = 1500.f;
	AnimationPlayRate = 1.4f;
	bSlowsWhileCasting = false;

	Payload.DirectDamage = 10.f;
	Payload.DamageType = RPGTags::Damage_Holy;
	Payload.Statuses.Emplace(RPGTags::Status_CC_Stun, 1.5f);
	ProjectileSpeed = 2600.f;
	HomingAcceleration = 14000.f;
	VisualScale = 0.9f;
}

USpell_FlashOfLight::USpell_FlashOfLight()
{
	SetCastAnimation(RPGAssets::ChargedAttackAnim);

	DisplayName = LOCTEXT("FlashName", "Flash of Light");
	Description = LOCTEXT("FlashDesc", "After a short cast, heals you for 70. A stun interrupts it; Mortal Strike halves it.");
	Color = FLinearColor(1.f, 0.95f, 0.6f);
	CooldownTag = PaladinSpellTags::Cooldown_FlashOfLight;
	ResourceCost = 40.f;
	Cooldown = 8.f;
	CastTime = 1.2f;
	ReleaseDelay = 1.f;
	AnimationPlayRate = 0.8f;
	bSlowsWhileCasting = true;

	HealAmount = 70.f;
}

USpell_Cleanse::USpell_Cleanse()
{
	DisplayName = LOCTEXT("CleanseName", "Cleanse");
	Description = LOCTEXT("CleanseDesc", "Breaks free of every stun, freeze, fear, root and slow, and makes you immune to them for 2 seconds. Works while stunned.");
	Color = FLinearColor(1.f, 1.f, 0.85f);
	CooldownTag = PaladinSpellTags::Cooldown_Cleanse;
	ResourceCost = 20.f;
	Cooldown = 25.f;
	CastTime = 0.15f;
	ReleaseDelay = 0.f;
	bUsableWhileIncapacitated = true;

	RemoveStatuses.AddTag(RPGTags::Status_CC);
	RemoveStatuses.AddTag(RPGTags::Status_Root);
	RemoveStatuses.AddTag(RPGTags::Status_Slow);
	Statuses.Emplace(RPGTags::Status_Immune_CC, 2.f);
}

USpell_DivineShield::USpell_DivineShield()
{
	SetCastAnimation(RPGAssets::AttackAnim3);

	DisplayName = LOCTEXT("DivineShieldName", "Divine Shield");
	Description = LOCTEXT("DivineShieldDesc", "Immune to all damage for 4 seconds and purges damage over time, but you deal 50% less damage meanwhile.");
	Color = PaladinSpellsPrivate::HolyColor;
	CooldownTag = PaladinSpellTags::Cooldown_DivineShield;
	ResourceCost = 30.f;
	Cooldown = 45.f;
	CastTime = 0.3f;
	ReleaseDelay = 0.1f;

	RemoveStatuses.AddTag(RPGTags::Status_DoT);
	// Magnitude: multiplier on the damage you deal while shielded.
	Statuses.Emplace(RPGTags::Status_DivineShield, 4.f, 0.5f);
}

#undef LOCTEXT_NAMESPACE
