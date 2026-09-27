#include "Spells/RogueSpells.h"

#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGGameplayTags.h"
#include "Characters/RPGCharacterBase.h"
#include "Core/RPGAssets.h"
#include "Spells/MageSpells.h"

#define LOCTEXT_NAMESPACE "RPGRogueSpells"

namespace RogueSpellTags
{
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Stealth, "Cooldown.Rogue.Stealth");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Backstab, "Cooldown.Rogue.Backstab");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_ThrowingKnife, "Cooldown.Rogue.ThrowingKnife");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_KidneyShot, "Cooldown.Rogue.KidneyShot");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Shadowstep, "Cooldown.Rogue.Shadowstep");
}

namespace RogueSpellsPrivate
{
	const FLinearColor BladeColor(0.8f, 0.85f, 0.9f);
	const FLinearColor ShadowColor(0.35f, 0.3f, 0.55f);
	const FLinearColor PoisonColor(0.4f, 0.95f, 0.25f);
}

USpell_DaggerSlash::USpell_DaggerSlash()
{
	AddComboAnimation(RPGAssets::AttackAnim1);
	AddComboAnimation(RPGAssets::AttackAnim2);
	AddComboAnimation(RPGAssets::AttackAnim3);

	DisplayName = LOCTEXT("DaggerSlashName", "Dagger Slash");
	Description = LOCTEXT("DaggerSlashDesc", "Quick dagger strikes.");
	Color = RogueSpellsPrivate::BladeColor;
	CastTime = 0.38f;
	ReleaseDelay = 0.12f;
	AnimationPlayRate = 2.f;

	Damage = 9.f;
	Reach = 190.f;
	ArcDegrees = 100.f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Stealth

USpell_Stealth::USpell_Stealth()
{
	DisplayName = LOCTEXT("StealthName", "Stealth");
	Description = LOCTEXT("StealthDesc", "Fade from sight, moving 25% slower. Attacking or taking damage reveals you; your first attack hits 50% harder. Enemies right next to you notice a shimmer. Not usable while taking damage over time.");
	Color = RogueSpellsPrivate::ShadowColor;
	CooldownTag = RogueSpellTags::Cooldown_Stealth;
	Cooldown = 6.f;
	CastTime = 0.2f;
	ReleaseDelay = 0.05f;

	// Magnitude: speed multiplier while hidden. No duration: lasts until broken.
	Statuses.Emplace(RPGTags::Status_Stealth, 0.f, 0.75f);
}

ERPGCastResult USpell_Stealth::CheckCasterState(const ARPGCharacterBase& Caster) const
{
	// Burning, poisoned or cursed characters would be revealed by the next tick anyway.
	return !Caster.IsStealthed() && Caster.HasStatus(RPGTags::Status_DoT) ? ERPGCastResult::InCombat : ERPGCastResult::Success;
}

FText USpell_Stealth::GetSlotLabel(const ARPGCharacterBase& Caster) const
{
	return Caster.IsStealthed() ? LOCTEXT("StealthLeave", "Reveal") : DisplayName;
}

void USpell_Stealth::ExecuteSpell(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	if (!Caster)
	{
		return;
	}

	if (Caster->IsStealthed())
	{
		Caster->GetRPGAbilitySystem()->RemoveStatuses(FGameplayTagContainer(RPGTags::Status_Stealth));
		return;
	}
	Super::ExecuteSpell(Context);
}

// ---------------------------------------------------------------------------------------------------------------------
// Backstab

USpell_Backstab::USpell_Backstab()
{
	SetCastAnimation(RPGAssets::AttackAnim3);

	DisplayName = LOCTEXT("BackstabName", "Backstab");
	Description = LOCTEXT("BackstabDesc", "A vicious stab. Deals double damage when you strike the target's back.");
	Color = FLinearColor(0.95f, 0.3f, 0.3f);
	CooldownTag = RogueSpellTags::Cooldown_Backstab;
	ResourceCost = 35.f;
	Cooldown = 3.f;
	CastTime = 0.45f;
	ReleaseDelay = 0.15f;
	AnimationPlayRate = 1.8f;

	Damage = 26.f;
	Reach = 190.f;
	ArcDegrees = 90.f;
	BehindDamageMultiplier = 2.f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Throwing Knife

USpell_ThrowingKnife::USpell_ThrowingKnife()
{
	SetCastAnimation(RPGAssets::AttackAnim2);

	DisplayName = LOCTEXT("KnifeName", "Throwing Knife");
	Description = LOCTEXT("KnifeDesc", "Throws a poisoned knife: poison damage over 8 seconds and a 30% slow for 3 seconds.");
	Color = RogueSpellsPrivate::PoisonColor;
	CooldownTag = RogueSpellTags::Cooldown_ThrowingKnife;
	ResourceCost = 25.f;
	Cooldown = 5.f;
	CastTime = 0.35f;
	ReleaseDelay = 0.15f;
	Range = 2500.f;
	AnimationPlayRate = 1.8f;
	bSlowsWhileCasting = false;

	Payload.DirectDamage = 14.f;
	Payload.DamageType = RPGTags::Damage_Physical;
	Payload.Statuses.Emplace(RPGTags::Status_DoT_Poison, 8.f, 4.f);
	Payload.Statuses.Emplace(RPGTags::Status_Slow, 3.f, 0.7f);
	ProjectileSpeed = 4200.f;
	HomingAcceleration = 9000.f;
	VisualScale = 0.45f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Kidney Shot

USpell_KidneyShot::USpell_KidneyShot()
{
	SetCastAnimation(RPGAssets::AttackAnim1);

	DisplayName = LOCTEXT("KidneyShotName", "Kidney Shot");
	Description = LOCTEXT("KidneyShotDesc", "A low blow that stuns the target for 1.75 seconds.");
	Color = FLinearColor(1.f, 0.75f, 0.3f);
	CooldownTag = RogueSpellTags::Cooldown_KidneyShot;
	ResourceCost = 30.f;
	Cooldown = 20.f;
	CastTime = 0.4f;
	ReleaseDelay = 0.15f;
	AnimationPlayRate = 1.8f;

	Damage = 8.f;
	Reach = 200.f;
	ArcDegrees = 100.f;
	Statuses.Emplace(RPGTags::Status_CC_Stun, 1.75f);
}

// ---------------------------------------------------------------------------------------------------------------------
// Shadowstep

USpell_Shadowstep::USpell_Shadowstep()
{
	SetCastAnimation(RPGAssets::DashAnim);

	DisplayName = LOCTEXT("ShadowstepName", "Shadowstep");
	Description = LOCTEXT("ShadowstepDesc", "Step through the shadows to appear behind the target, moving 30% faster for 2 seconds. Does not break stealth.");
	Color = RogueSpellsPrivate::ShadowColor;
	CooldownTag = RogueSpellTags::Cooldown_Shadowstep;
	ResourceCost = 15.f;
	Cooldown = 18.f;
	CastTime = 0.25f;
	ReleaseDelay = 0.05f;
	Range = 2500.f;
	AnimationPlayRate = 1.6f;
	bRequiresTarget = true;
	bBreaksStealth = false;
	bSlowsWhileCasting = false;
}

ERPGCastResult USpell_Shadowstep::CheckCasterState(const ARPGCharacterBase& Caster) const
{
	return Caster.HasStatus(RPGTags::Status_Root) ? ERPGCastResult::Rooted : ERPGCastResult::Success;
}

void USpell_Shadowstep::ExecuteSpell(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	ARPGCharacterBase* Target = Context.Target;
	if (!Caster || !Target)
	{
		return;
	}

	const FVector TargetBack = -Target->GetActorForwardVector().GetSafeNormal2D();
	const FVector Destination = Target->GetActorLocation() + TargetBack * BehindDistance;
	const FRotator Facing = (-TargetBack).Rotation();

	RPGAbilityFX::SpawnBurst(Caster, Caster->GetActorLocation(), Color, 2.f);
	if (RPGSpellHelpers::TeleportCharacter(*Caster, Destination, Facing, false))
	{
		RPGAbilityFX::SpawnBurst(Caster, Caster->GetActorLocation(), Color, 2.f);
		Caster->GetRPGAbilitySystem()->ApplyStatus(FRPGStatusSpec(RPGTags::Status_Haste, 2.f, 1.3f), Caster);
	}
}

#undef LOCTEXT_NAMESPACE
