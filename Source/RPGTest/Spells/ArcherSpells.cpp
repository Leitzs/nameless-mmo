#include "Spells/ArcherSpells.h"

#include "Abilities/RPGGameplayTags.h"
#include "Abilities/Tasks/AbilityTask_ApplyRootMotionMoveToForce.h"
#include "Abilities/Tasks/AbilityTask_WaitDelay.h"
#include "Characters/RPGCharacterBase.h"
#include "Components/PrimitiveComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/World.h"
#include "Spells/RPGDelayedBlast.h"

#define LOCTEXT_NAMESPACE "RPGArcherSpells"

namespace ArcherSpellTags
{
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_AimedShot, "Cooldown.Archer.AimedShot");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_MultiShot, "Cooldown.Archer.MultiShot");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_ConcussiveShot, "Cooldown.Archer.ConcussiveShot");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Disengage, "Cooldown.Archer.Disengage");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_RainOfArrows, "Cooldown.Archer.RainOfArrows");
}

namespace ArcherSpellsPrivate
{
	const FLinearColor ArrowColor(0.95f, 0.88f, 0.6f);
	const FLinearColor HuntColor(0.45f, 0.85f, 0.35f);
}

USpell_QuickShot::USpell_QuickShot()
{
	SetCastAnimation(RPGAssets::AttackAnim3);

	DisplayName = LOCTEXT("QuickShotName", "Quick Shot");
	Description = LOCTEXT("QuickShotDesc", "A fast arrow. Costs nothing and can be fired on the move.");
	Color = ArcherSpellsPrivate::ArrowColor;
	CastTime = 0.6f;
	ReleaseDelay = 0.2f;
	Range = 4000.f;
	AnimationPlayRate = 1.8f;
	bSlowsWhileCasting = false;

	Payload.DirectDamage = 12.f;
	Payload.DamageType = RPGTags::Damage_Physical;
	ProjectileSpeed = 5000.f;
	HomingAcceleration = 8000.f;
	VisualScale = 0.35f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Aimed Shot

USpell_AimedShot::USpell_AimedShot()
{
	SetCastAnimation(RPGAssets::ChargedAttackAnim);

	DisplayName = LOCTEXT("AimedShotName", "Aimed Shot");
	Description = LOCTEXT("AimedShotDesc", "Take a moment to draw the bow fully, then release a powerful arrow. You move slower while drawing.");
	Color = FLinearColor(1.f, 0.75f, 0.25f);
	CooldownTag = ArcherSpellTags::Cooldown_AimedShot;
	ResourceCost = 35.f;
	Cooldown = 6.f;
	CastTime = 1.1f;
	ReleaseDelay = 0.9f;
	Range = 5000.f;
	AnimationPlayRate = 1.f;

	Payload.DirectDamage = 48.f;
	Payload.DamageType = RPGTags::Damage_Physical;
	ProjectileSpeed = 6500.f;
	HomingAcceleration = 10000.f;
	VisualScale = 0.6f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Multi-Shot

USpell_MultiShot::USpell_MultiShot()
{
	SetCastAnimation(RPGAssets::AttackAnim1);

	DisplayName = LOCTEXT("MultiShotName", "Multi-Shot");
	Description = LOCTEXT("MultiShotDesc", "Fires a fan of three arrows. The middle one follows the target.");
	Color = ArcherSpellsPrivate::ArrowColor;
	CooldownTag = ArcherSpellTags::Cooldown_MultiShot;
	ResourceCost = 30.f;
	Cooldown = 8.f;
	CastTime = 0.45f;
	ReleaseDelay = 0.2f;
	Range = 3500.f;
	AnimationPlayRate = 1.8f;
	bSlowsWhileCasting = false;

	Payload.DirectDamage = 18.f;
	Payload.DamageType = RPGTags::Damage_Physical;
	ProjectileSpeed = 4800.f;
	HomingAcceleration = 8000.f;
	VisualScale = 0.4f;
}

void USpell_MultiShot::ExecuteSpell(const FRPGSpellContext& Context)
{
	FRPGProjectilePayload FinalPayload = Payload;
	FinalPayload.DirectDamage *= GetStealthMultiplier(Context);

	const FVector AimOffset = Context.AimLocation - Context.Origin;
	TArray<ARPGProjectile*, TInlineAllocator<8>> Arrows;
	for (int32 Index = 0; Index < ArrowCount; ++Index)
	{
		const float Angle = (Index - (ArrowCount - 1) * 0.5f) * SpreadDegrees;
		FRPGSpellContext ArrowContext = Context;
		if (!FMath::IsNearlyZero(Angle))
		{
			ArrowContext.AimLocation = Context.Origin + AimOffset.RotateAngleAxis(Angle, FVector::UpVector);
			ArrowContext.Target = nullptr;
		}
		if (ARPGProjectile* Arrow = SpawnProjectile(ArrowContext, FinalPayload, ProjectileSpeed, HomingAcceleration, VisualScale))
		{
			Arrows.Add(Arrow);
		}
	}

	// The arrows leave from the same point and block world dynamic objects: keep them from hitting each other.
	for (ARPGProjectile* Arrow : Arrows)
	{
		if (UPrimitiveComponent* ArrowCollision = Cast<UPrimitiveComponent>(Arrow->GetRootComponent()))
		{
			for (ARPGProjectile* Other : Arrows)
			{
				if (Other != Arrow)
				{
					ArrowCollision->IgnoreActorWhenMoving(Other, true);
				}
			}
		}
	}

	SpawnCastFlash(Context, 0.9f * VisualScale);
}

// ---------------------------------------------------------------------------------------------------------------------
// Concussive Shot

USpell_ConcussiveShot::USpell_ConcussiveShot()
{
	SetCastAnimation(RPGAssets::AttackAnim2);

	DisplayName = LOCTEXT("ConcussiveShotName", "Concussive Shot");
	Description = LOCTEXT("ConcussiveShotDesc", "An arrow that dazes the target, slowing it by 50% for 5 seconds.");
	Color = FLinearColor(0.45f, 0.7f, 1.f);
	CooldownTag = ArcherSpellTags::Cooldown_ConcussiveShot;
	ResourceCost = 20.f;
	Cooldown = 12.f;
	CastTime = 0.45f;
	ReleaseDelay = 0.2f;
	Range = 4000.f;
	AnimationPlayRate = 1.8f;
	bSlowsWhileCasting = false;

	Payload.DirectDamage = 10.f;
	Payload.DamageType = RPGTags::Damage_Physical;
	Payload.Statuses.Emplace(RPGTags::Status_Slow, 5.f, 0.5f);
	ProjectileSpeed = 5000.f;
	HomingAcceleration = 9000.f;
	VisualScale = 0.45f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Disengage

USpell_Disengage::USpell_Disengage()
{
	// No cast animation: the dash and attack animations carry forward root motion, which would override the leap.
	DisplayName = LOCTEXT("DisengageName", "Disengage");
	Description = LOCTEXT("DisengageDesc", "Leap backwards, away from where you are aiming.");
	Color = ArcherSpellsPrivate::HuntColor;
	CooldownTag = ArcherSpellTags::Cooldown_Disengage;
	ResourceCost = 15.f;
	Cooldown = 16.f;
	CastTime = 0.2f;
	ReleaseDelay = 0.f;
	// Soft-lock distance only (facing); the leap itself ignores the target.
	Range = 450.f;
	bSlowsWhileCasting = false;
}

ERPGCastResult USpell_Disengage::CheckCasterState(const ARPGCharacterBase& Caster) const
{
	return Caster.HasStatus(RPGTags::Status_Root) ? ERPGCastResult::Rooted : ERPGCastResult::Success;
}

void USpell_Disengage::OnRelease(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	if (!Caster)
	{
		return;
	}

	// Away from the aim point (the caster has just turned to face it). Both the owning client and the server run the
	// same root motion; walls stop it.
	FVector Away = (Caster->GetActorLocation() - Context.AimLocation).GetSafeNormal2D();
	if (Away.IsNearlyZero())
	{
		Away = -Caster->GetActorForwardVector().GetSafeNormal2D();
	}
	const FVector Destination = Caster->GetActorLocation() + Away * LeapDistance;

	HoldOpen();

	UAbilityTask_ApplyRootMotionMoveToForce* Task = UAbilityTask_ApplyRootMotionMoveToForce::ApplyRootMotionMoveToForce(
		this, TEXT("Disengage"), Destination, LeapDuration, false, MOVE_Walking, false, nullptr,
		ERootMotionFinishVelocityMode::ClampVelocity, FVector::ZeroVector, 200.f);
	Task->ReadyForActivation();

	// Finish on a timer, like Charge: the server advances a remote client's root motion only as its moves arrive.
	UAbilityTask_WaitDelay* WaitLanding = UAbilityTask_WaitDelay::WaitDelay(this, LeapDuration + 0.05f);
	WaitLanding->OnFinish.AddDynamic(this, &ThisClass::OnLeapFinished);
	WaitLanding->ReadyForActivation();

	if (CurrentActorInfo->IsNetAuthority())
	{
		RPGAbilityFX::SpawnBurst(Caster, RPGAbilityFX::GetFeetLocation(*Caster) + FVector(0.f, 0.f, 30.f), Color, 1.5f);
	}
}

void USpell_Disengage::OnLeapFinished()
{
	FinishHold();
}

// ---------------------------------------------------------------------------------------------------------------------
// Rain of Arrows

USpell_RainOfArrows::USpell_RainOfArrows()
{
	SetCastAnimation(RPGAssets::ChargedAttackAnim);

	DisplayName = LOCTEXT("RainOfArrowsName", "Rain of Arrows");
	Description = LOCTEXT("RainOfArrowsDesc", "Marks an area; a moment later arrows rain down on it, damaging and slowing every enemy inside by 30% for 3 seconds.");
	Color = ArcherSpellsPrivate::HuntColor;
	CooldownTag = ArcherSpellTags::Cooldown_RainOfArrows;
	ResourceCost = 40.f;
	Cooldown = 18.f;
	CastTime = 0.5f;
	ReleaseDelay = 0.25f;
	Range = 3500.f;
	AnimationPlayRate = 1.6f;
}

void USpell_RainOfArrows::ExecuteSpell(const FRPGSpellContext& Context)
{
	UWorld* World = GetWorld();
	ARPGCharacterBase* Caster = Context.Caster;
	if (!World || !Caster)
	{
		return;
	}

	// Lands where the target stood when the arrows were loosed (it does not follow): the warning can be dodged.
	FVector StrikeLocation = Context.Target ? Context.Target->GetActorLocation() : Context.AimLocation;
	const FVector CasterLocation = Caster->GetActorLocation();
	const FVector Offset = StrikeLocation - CasterLocation;
	if (Offset.Size2D() > Range)
	{
		StrikeLocation = CasterLocation + Offset.GetSafeNormal2D() * Range + FVector(0.f, 0.f, Offset.Z);
	}

	const FTransform SpawnTransform(StrikeLocation);
	ARPGDelayedBlast* Blast = World->SpawnActorDeferred<ARPGDelayedBlast>(ARPGDelayedBlast::StaticClass(), SpawnTransform, Caster, Caster, ESpawnActorCollisionHandlingMethod::AlwaysSpawn);
	if (Blast)
	{
		Blast->Configure(Delay, Radius, Damage, RPGTags::Damage_Physical, FRPGStatusSpec(RPGTags::Status_Slow, SlowDuration, SlowMultiplier), Color, nullptr);
		Blast->FinishSpawning(SpawnTransform);
	}

	SpawnCastFlash(Context);
}

#undef LOCTEXT_NAMESPACE
