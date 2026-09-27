#include "Spells/WarriorSpells.h"

#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGGameplayTags.h"
#include "Abilities/Tasks/AbilityTask_ApplyRootMotionMoveToForce.h"
#include "Abilities/Tasks/AbilityTask_WaitDelay.h"
#include "Characters/RPGCharacterBase.h"
#include "Combat/RPGCombatLibrary.h"
#include "Components/CapsuleComponent.h"
#include "Core/RPGAssets.h"

#define LOCTEXT_NAMESPACE "RPGWarriorSpells"

namespace WarriorSpellTags
{
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Charge, "Cooldown.Warrior.Charge");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_MortalStrike, "Cooldown.Warrior.MortalStrike");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Hamstring, "Cooldown.Warrior.Hamstring");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Whirlwind, "Cooldown.Warrior.Whirlwind");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_BerserkerRush, "Cooldown.Warrior.BerserkerRush");
}

namespace WarriorSpellsPrivate
{
	const FLinearColor SteelColor(0.85f, 0.8f, 0.75f);
	const FLinearColor RageColor(1.f, 0.3f, 0.15f);
}

USpell_SwordSlash::USpell_SwordSlash()
{
	AddComboAnimation(RPGAssets::AttackAnim1);
	AddComboAnimation(RPGAssets::AttackAnim2);
	AddComboAnimation(RPGAssets::AttackAnim3);

	DisplayName = LOCTEXT("SwordSlashName", "Sword Slash");
	Description = LOCTEXT("SwordSlashDesc", "Heavy sword strikes. Every hit builds rage.");
	Color = WarriorSpellsPrivate::SteelColor;
	CastTime = 0.6f;
	ReleaseDelay = 0.25f;
	AnimationPlayRate = 1.4f;

	Damage = 15.f;
	Reach = 220.f;
	ArcDegrees = 120.f;
	ResourceOnHit = 5.f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Charge

USpell_Charge::USpell_Charge()
{
	SetCastAnimation(RPGAssets::DashAnim);

	DisplayName = LOCTEXT("ChargeName", "Charge");
	Description = LOCTEXT("ChargeDesc", "Rush to the target, rooting it for 1 second on arrival and generating 20 rage.");
	Color = WarriorSpellsPrivate::RageColor;
	CooldownTag = WarriorSpellTags::Cooldown_Charge;
	Cooldown = 15.f;
	CastTime = 0.2f;
	ReleaseDelay = 0.f;
	Range = 2500.f;
	AnimationPlayRate = 1.2f;
	bRequiresTarget = true;
	bSlowsWhileCasting = false;
}

ERPGCastResult USpell_Charge::CheckCasterState(const ARPGCharacterBase& Caster) const
{
	return Caster.HasStatus(RPGTags::Status_Root) ? ERPGCastResult::Rooted : ERPGCastResult::Success;
}

ERPGCastResult USpell_Charge::CheckTarget(const ARPGCharacterBase& Caster, const ARPGCharacterBase& Target) const
{
	return FVector::Dist2D(Caster.GetActorLocation(), Target.GetActorLocation()) < MinDistance ? ERPGCastResult::OutOfRange : ERPGCastResult::Success;
}

void USpell_Charge::OnRelease(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	ARPGCharacterBase* Target = Context.Target;
	if (!Caster || !Target)
	{
		return;
	}

	// Stop just in front of the target. Both the owning client and the server run the same root motion.
	const FVector ToTarget = Target->GetActorLocation() - Caster->GetActorLocation();
	const float StopDistance = Caster->GetCapsuleComponent()->GetScaledCapsuleRadius() + Target->GetCapsuleComponent()->GetScaledCapsuleRadius() + 40.f;
	const float TravelDistance = FMath::Max(0.f, ToTarget.Size2D() - StopDistance);
	const FVector Destination = Caster->GetActorLocation() + ToTarget.GetSafeNormal2D() * TravelDistance + FVector(0.f, 0.f, ToTarget.Z);
	const float Duration = FMath::Clamp(TravelDistance / ChargeSpeed, 0.1f, 1.2f);

	ChargeTarget = Target;
	ChargeDestination = Destination;
	HoldOpen();

	UAbilityTask_ApplyRootMotionMoveToForce* Task = UAbilityTask_ApplyRootMotionMoveToForce::ApplyRootMotionMoveToForce(
		this, TEXT("Charge"), Destination, Duration, false, MOVE_Walking, false, nullptr,
		ERootMotionFinishVelocityMode::ClampVelocity, FVector::ZeroVector, 200.f);
	Task->ReadyForActivation();

	// Finish on a timer rather than on the root motion's end: for a remote client the server only advances it as
	// the client's moves arrive, so both sides would disagree on when (or whether) it ended.
	UAbilityTask_WaitDelay* WaitArrival = UAbilityTask_WaitDelay::WaitDelay(this, Duration + 0.05f);
	WaitArrival->OnFinish.AddDynamic(this, &ThisClass::OnChargeFinished);
	WaitArrival->ReadyForActivation();

	if (CurrentActorInfo->IsNetAuthority())
	{
		RPGAbilityFX::SpawnBurst(Caster, RPGAbilityFX::GetFeetLocation(*Caster) + FVector(0.f, 0.f, 30.f), Color, 1.5f);
	}
}

void USpell_Charge::OnChargeFinished()
{
	ARPGCharacterBase* Caster = GetCaster();
	ARPGCharacterBase* Target = ChargeTarget.Get();
	ChargeTarget.Reset();

	if (Caster && Target && CurrentActorInfo->IsNetAuthority())
	{
		// The target must still be where the charge was heading (it may have dodged or blinked away).
		const float Reach = Caster->GetCapsuleComponent()->GetScaledCapsuleRadius() + Target->GetCapsuleComponent()->GetScaledCapsuleRadius() + 150.f;
		const float Distance = FVector::Dist2D(ChargeDestination, Target->GetActorLocation());
		if (Distance <= Reach && URPGCombatLibrary::ApplyDamage(Caster, Target, Damage, RPGTags::Damage_Physical))
		{
			URPGCombatLibrary::ApplyStatus(Caster, Target, FRPGStatusSpec(RPGTags::Status_Root, RootDuration));
			RPGAbilityFX::SpawnBurst(Caster, Target->GetTargetPoint(), Color, 1.8f);
		}
		Caster->GetRPGAbilitySystem()->AddResource(RageGenerated);
	}

	FinishHold();
}

// ---------------------------------------------------------------------------------------------------------------------
// Mortal Strike

USpell_MortalStrike::USpell_MortalStrike()
{
	SetCastAnimation(RPGAssets::ChargedAttackAnim);

	DisplayName = LOCTEXT("MortalStrikeName", "Mortal Strike");
	Description = LOCTEXT("MortalStrikeDesc", "A crushing blow that wounds the target: healing it receives is halved for 8 seconds.");
	Color = FLinearColor(0.85f, 0.15f, 0.1f);
	CooldownTag = WarriorSpellTags::Cooldown_MortalStrike;
	ResourceCost = 30.f;
	Cooldown = 6.f;
	CastTime = 0.65f;
	ReleaseDelay = 0.3f;
	AnimationPlayRate = 1.6f;

	Damage = 36.f;
	Reach = 220.f;
	ArcDegrees = 110.f;
	Statuses.Emplace(RPGTags::Status_HealingReduced, 8.f, 0.5f);
}

// ---------------------------------------------------------------------------------------------------------------------
// Hamstring

USpell_Hamstring::USpell_Hamstring()
{
	SetCastAnimation(RPGAssets::AttackAnim2);

	DisplayName = LOCTEXT("HamstringName", "Hamstring");
	Description = LOCTEXT("HamstringDesc", "A quick cut that slows the target by 50% for 6 seconds.");
	Color = FLinearColor(0.6f, 0.85f, 1.f);
	CooldownTag = WarriorSpellTags::Cooldown_Hamstring;
	ResourceCost = 10.f;
	Cooldown = 1.f;
	CastTime = 0.4f;
	ReleaseDelay = 0.15f;
	AnimationPlayRate = 1.8f;

	Damage = 8.f;
	Reach = 220.f;
	ArcDegrees = 110.f;
	Statuses.Emplace(RPGTags::Status_Slow, 6.f, 0.5f);
}

// ---------------------------------------------------------------------------------------------------------------------
// Whirlwind

USpell_Whirlwind::USpell_Whirlwind()
{
	SetCastAnimation(RPGAssets::ChargedAttackAnim);

	DisplayName = LOCTEXT("WhirlwindName", "Whirlwind");
	Description = LOCTEXT("WhirlwindDesc", "Spin with your sword, hitting every enemy around you.");
	Color = WarriorSpellsPrivate::SteelColor;
	CooldownTag = WarriorSpellTags::Cooldown_Whirlwind;
	ResourceCost = 25.f;
	Cooldown = 8.f;
	CastTime = 0.6f;
	ReleaseDelay = 0.3f;
	Range = 380.f;
	AnimationPlayRate = 1.8f;
	bSlowsWhileCasting = false;

	Radius = 380.f;
	Damage = 22.f;
	DamageType = RPGTags::Damage_Physical;
	Knockback = 250.f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Berserker Rush

USpell_BerserkerRush::USpell_BerserkerRush()
{
	SetCastAnimation(RPGAssets::ChargedAttackAnim);

	DisplayName = LOCTEXT("BerserkerRushName", "Berserker Rush");
	Description = LOCTEXT("BerserkerRushDesc", "Break free of roots and slows, then run 50% faster and ignore slows for 4 seconds.");
	Color = WarriorSpellsPrivate::RageColor;
	CooldownTag = WarriorSpellTags::Cooldown_BerserkerRush;
	Cooldown = 20.f;
	CastTime = 0.2f;
	ReleaseDelay = 0.05f;
	AnimationPlayRate = 2.f;

	RemoveStatuses.AddTag(RPGTags::Status_Root);
	RemoveStatuses.AddTag(RPGTags::Status_Slow);
	Statuses.Emplace(RPGTags::Status_Haste, 4.f, 1.5f);
	Statuses.Emplace(RPGTags::Status_Immune_Slow, 4.f);
}

#undef LOCTEXT_NAMESPACE
