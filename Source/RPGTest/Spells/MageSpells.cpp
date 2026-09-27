#include "Spells/MageSpells.h"

#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGGameplayTags.h"
#include "Characters/RPGCharacterBase.h"
#include "Components/CapsuleComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/World.h"
#include "FX/RPGTransientFX.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Spells/RPGDelayedBlast.h"

#define LOCTEXT_NAMESPACE "RPGMageSpells"

namespace MageSpellTags
{
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Fireball, "Cooldown.Mage.Fireball");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_FrostNova, "Cooldown.Mage.FrostNova");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_LightningStrike, "Cooldown.Mage.LightningStrike");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Blink, "Cooldown.Mage.Blink");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_ArcaneShield, "Cooldown.Mage.ArcaneShield");
}

// ---------------------------------------------------------------------------------------------------------------------
// Shared helpers

bool RPGSpellHelpers::TeleportCharacter(ARPGCharacterBase& Character, const FVector& Destination, const FRotator& Facing, bool bSweep)
{
	UWorld* World = Character.GetWorld();
	if (!World)
	{
		return false;
	}

	const FVector Start = Character.GetActorLocation();
	const UCapsuleComponent* Capsule = Character.GetCapsuleComponent();
	const float HalfHeight = Capsule->GetScaledCapsuleHalfHeight();
	const FCollisionShape Shape = FCollisionShape::MakeCapsule(Capsule->GetScaledCapsuleRadius(), HalfHeight);
	FCollisionQueryParams Params(SCENE_QUERY_STAT(RPGTeleport), false, &Character);

	// Sweep slightly above the ground so small bumps do not cut the move short.
	const FVector Lift(0.f, 0.f, 60.f);
	const FVector Direction = (Destination - Start).GetSafeNormal2D();
	FVector End = Destination;
	FHitResult Hit;
	if (bSweep && World->SweepSingleByChannel(Hit, Start + Lift, End + Lift, FQuat::Identity, ECC_Pawn, Shape, Params))
	{
		End = Hit.Location - Lift - Direction * 10.f;
	}

	if (World->LineTraceSingleByChannel(Hit, End + FVector(0.f, 0.f, 300.f), End - FVector(0.f, 0.f, 1500.f), ECC_WorldStatic, Params))
	{
		End.Z = Hit.ImpactPoint.Z + HalfHeight + 2.f;
	}

	if (!bSweep)
	{
		// TeleportTo nudges the character out of anything it would overlap.
		return Character.TeleportTo(End, Facing);
	}

	// Fall back to shorter hops if the destination is obstructed.
	for (float Fraction = 1.f; Fraction > 0.2f; Fraction -= 0.25f)
	{
		if (Character.TeleportTo(FMath::Lerp(Start, End, Fraction), Facing))
		{
			return true;
		}
	}
	return false;
}

// ---------------------------------------------------------------------------------------------------------------------
// Arcane Bolt

USpell_ArcaneBolt::USpell_ArcaneBolt()
{
	SetCastAnimation(RPGAssets::AttackAnim3);

	DisplayName = LOCTEXT("ArcaneBoltName", "Arcane Bolt");
	Description = LOCTEXT("ArcaneBoltDesc", "A quick bolt of raw arcane energy. Costs nothing.");
	Color = FLinearColor(0.8f, 0.5f, 1.f);
	CastTime = 0.55f;
	ReleaseDelay = 0.15f;
	Range = 3500.f;
	AnimationPlayRate = 1.8f;

	Payload.DirectDamage = 11.f;
	Payload.DamageType = RPGTags::Damage_Arcane;
	ProjectileSpeed = 3600.f;
	HomingAcceleration = 7000.f;
	VisualScale = 0.6f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Fireball

USpell_Fireball::USpell_Fireball()
{
	SetCastAnimation(RPGAssets::AttackAnim1);

	DisplayName = LOCTEXT("FireballName", "Fireball");
	Description = LOCTEXT("FireballDesc", "Hurls a homing ball of fire that explodes on impact and sets enemies ablaze.");
	Color = FLinearColor(1.f, 0.38f, 0.06f);
	CooldownTag = MageSpellTags::Cooldown_Fireball;
	ResourceCost = 15.f;
	Cooldown = 0.8f;
	CastTime = 0.45f;
	ReleaseDelay = 0.2f;
	Range = 4500.f;
	AnimationPlayRate = 1.4f;

	Payload.DirectDamage = 32.f;
	Payload.SplashDamage = 12.f;
	Payload.SplashRadius = 280.f;
	Payload.DamageType = RPGTags::Damage_Fire;
	Payload.Statuses.Emplace(RPGTags::Status_DoT_Burn, 4.f, 5.f);
	ProjectileSpeed = 2800.f;
	HomingAcceleration = 9000.f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Frost Nova

USpell_FrostNova::USpell_FrostNova()
{
	SetCastAnimation(RPGAssets::ChargedAttackAnim);

	DisplayName = LOCTEXT("FrostNovaName", "Frost Nova");
	Description = LOCTEXT("FrostNovaDesc", "Releases a wave of frost that damages and freezes nearby enemies, then slows them.");
	Color = FLinearColor(0.45f, 0.85f, 1.f);
	CooldownTag = MageSpellTags::Cooldown_FrostNova;
	ResourceCost = 30.f;
	Cooldown = 12.f;
	CastTime = 0.5f;
	ReleaseDelay = 0.25f;
	Range = 650.f;
	AnimationPlayRate = 1.8f;

	Radius = 650.f;
	Damage = 20.f;
	DamageType = RPGTags::Damage_Frost;
	Statuses.Emplace(RPGTags::Status_CC_Freeze, FreezeDuration);
	// The slow outlasts the freeze by four seconds.
	Statuses.Emplace(RPGTags::Status_Slow, FreezeDuration + 4.f, 0.5f);
}

void USpell_FrostNova::ExecuteSpell(const FRPGSpellContext& Context)
{
	Super::ExecuteSpell(Context);

	if (Context.Caster)
	{
		RPGAbilityFX::SpawnBurst(Context.Caster, Context.Caster->GetActorLocation(), FLinearColor(0.8f, 0.95f, 1.f), 3.5f);
	}
}

void USpell_FrostNova::OnNovaHit(const FRPGSpellContext& Context, ARPGCharacterBase* Target)
{
	if (!Target->IsAlive() || !Target->HasStatus(RPGTags::Status_CC_Freeze))
	{
		return;
	}

	// Ice crystal encasing the frozen target, for as long as the freeze lasts (it may be shortened by diminishing returns).
	const float Duration = FMath::Max(0.3f, Target->GetRPGAbilitySystem()->GetStatusTimeRemaining(RPGTags::Status_CC_Freeze));
	FRPGFXParams Ice;
	Ice.Shape = ERPGFXShape::Cone;
	Ice.Color = Color;
	Ice.Intensity = 1.5f;
	Ice.FresnelAmount = 0.6f;
	Ice.Lifetime = Duration;
	Ice.GrowTime = 0.15f;
	Ice.FadeStart = FMath::Max(0.f, Duration - 0.4f);
	Ice.StartScale = FVector(0.3f);
	Ice.EndScale = FVector(1.3f, 1.3f, 2.4f);
	ARPGTransientFX::SpawnForAll(Context.Caster, RPGAbilityFX::GetFeetLocation(*Target) + FVector(0.f, 0.f, 110.f), FRotator::ZeroRotator, Ice, Target);
}

// ---------------------------------------------------------------------------------------------------------------------
// Lightning Strike

USpell_LightningStrike::USpell_LightningStrike()
{
	SetCastAnimation(RPGAssets::AttackAnim2);

	DisplayName = LOCTEXT("LightningName", "Lightning Strike");
	Description = LOCTEXT("LightningDesc", "Calls down a lightning bolt on the target area after a brief warning, damaging and stunning enemies.");
	Color = FLinearColor(0.65f, 0.75f, 1.f);
	CooldownTag = MageSpellTags::Cooldown_LightningStrike;
	ResourceCost = 30.f;
	Cooldown = 6.f;
	CastTime = 0.45f;
	ReleaseDelay = 0.2f;
	Range = 2800.f;
	AnimationPlayRate = 1.3f;
}

void USpell_LightningStrike::ExecuteSpell(const FRPGSpellContext& Context)
{
	UWorld* World = GetWorld();
	ARPGCharacterBase* Caster = Context.Caster;
	if (!World || !Caster)
	{
		return;
	}

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
		Blast->Configure(StrikeDelay, Radius, Damage, RPGTags::Damage_Lightning, FRPGStatusSpec(RPGTags::Status_CC_Stun, StunDuration), Color, Context.Target);
		Blast->FinishSpawning(SpawnTransform);
	}

	FRPGFXParams Spark;
	Spark.Color = Color;
	Spark.Intensity = 15.f;
	Spark.Lifetime = 0.25f;
	Spark.StartScale = FVector(0.2f);
	Spark.EndScale = FVector(0.8f);
	Spark.Flicker = 0.6f;
	Spark.LightIntensity = 2000.f;
	Spark.LightRadius = 500.f;
	ARPGTransientFX::SpawnForAll(Caster, Context.Origin, FRotator::ZeroRotator, Spark);
}

// ---------------------------------------------------------------------------------------------------------------------
// Blink

USpell_Blink::USpell_Blink()
{
	SetCastAnimation(RPGAssets::DashAnim);

	DisplayName = LOCTEXT("BlinkName", "Blink");
	Description = LOCTEXT("BlinkDesc", "Teleports a short distance in the direction you are moving (or aiming when standing still).");
	Color = FLinearColor(0.7f, 0.35f, 1.f);
	CooldownTag = MageSpellTags::Cooldown_Blink;
	ResourceCost = 20.f;
	Cooldown = 6.f;
	CastTime = 0.25f;
	ReleaseDelay = 0.05f;
	Range = 900.f;
	AnimationPlayRate = 1.6f;
	bFaceAim = false;
	bSlowsWhileCasting = false;
}

void USpell_Blink::ExecuteSpell(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	if (!Caster)
	{
		return;
	}

	const FVector Start = Caster->GetActorLocation();

	// Acceleration is the movement input as the server sees it (it arrives with the client's moves).
	FVector Direction = Caster->GetCharacterMovement()->GetCurrentAcceleration().GetSafeNormal2D();
	if (Direction.IsNearlyZero())
	{
		Direction = (Context.AimLocation - Start).GetSafeNormal2D();
	}
	if (Direction.IsNearlyZero())
	{
		Direction = Caster->GetActorForwardVector().GetSafeNormal2D();
	}

	FRPGFXParams Puff;
	Puff.Color = Color;
	Puff.Intensity = 8.f;
	Puff.FresnelAmount = 0.6f;
	Puff.Lifetime = 0.4f;
	Puff.StartScale = FVector(1.2f, 1.2f, 2.f);
	Puff.EndScale = FVector(0.1f, 0.1f, 2.6f);
	Puff.LightIntensity = 2500.f;
	Puff.LightRadius = 600.f;
	ARPGTransientFX::SpawnForAll(Caster, Start, FRotator::ZeroRotator, Puff);

	if (RPGSpellHelpers::TeleportCharacter(*Caster, Start + Direction * Distance, Direction.Rotation()))
	{
		FRPGFXParams Arrive = Puff;
		Arrive.StartScale = FVector(0.1f, 0.1f, 2.6f);
		Arrive.EndScale = FVector(1.4f, 1.4f, 2.f);
		ARPGTransientFX::SpawnForAll(Caster, Caster->GetActorLocation(), FRotator::ZeroRotator, Arrive);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Arcane Shield

USpell_ArcaneShield::USpell_ArcaneShield()
{
	SetCastAnimation(RPGAssets::AttackAnim3);

	DisplayName = LOCTEXT("ShieldName", "Arcane Shield");
	Description = LOCTEXT("ShieldDesc", "Surrounds you with a barrier that absorbs incoming damage.");
	Color = FLinearColor(0.6f, 0.35f, 1.f);
	CooldownTag = MageSpellTags::Cooldown_ArcaneShield;
	ResourceCost = 35.f;
	Cooldown = 18.f;
	CastTime = 0.35f;
	ReleaseDelay = 0.1f;
	AnimationPlayRate = 1.5f;

	ShieldAmount = 80.f;
	ShieldDuration = 10.f;
}

#undef LOCTEXT_NAMESPACE
