#include "Spells/MageSpells.h"

#include "Animation/AnimSequenceBase.h"
#include "Characters/RPGCharacterBase.h"
#include "Combat/RPGCombatLibrary.h"
#include "Combat/RPGDamageTypes.h"
#include "Components/CapsuleComponent.h"
#include "Components/RPGAttributeComponent.h"
#include "Components/RPGStatusEffectComponent.h"
#include "Engine/World.h"
#include "FX/RPGTransientFX.h"
#include "Spells/RPGDelayedBlast.h"
#include "UObject/ConstructorHelpers.h"

#define LOCTEXT_NAMESPACE "RPGMageSpells"

namespace
{
	const TCHAR* AttackAnimPath1 = TEXT("/Game/Characters/Mannequins/Anims/Unarmed/Attack/MM_Attack_01.MM_Attack_01");
	const TCHAR* AttackAnimPath2 = TEXT("/Game/Characters/Mannequins/Anims/Unarmed/Attack/MM_Attack_02.MM_Attack_02");
	const TCHAR* AttackAnimPath3 = TEXT("/Game/Characters/Mannequins/Anims/Unarmed/Attack/MM_Attack_03.MM_Attack_03");
	const TCHAR* ChargedAnimPath = TEXT("/Game/Characters/Mannequins/Anims/Unarmed/Attack/MM_ChargedAttack.MM_ChargedAttack");
	const TCHAR* DashAnimPath = TEXT("/Game/Characters/Mannequins/Anims/Unarmed/Jump/MM_Dash.MM_Dash");

	FVector GetFeetLocation(const ARPGCharacterBase& Character)
	{
		return Character.GetActorLocation() - FVector(0.f, 0.f, Character.GetCapsuleComponent()->GetScaledCapsuleHalfHeight());
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Fireball

USpell_Fireball::USpell_Fireball()
{
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Animation(AttackAnimPath1);
	CastAnimation = Animation.Object;

	DisplayName = LOCTEXT("FireballName", "Fireball");
	Description = LOCTEXT("FireballDesc", "Hurls a homing ball of fire that explodes on impact and sets enemies ablaze.");
	Color = FLinearColor(1.f, 0.38f, 0.06f);
	ManaCost = 15.f;
	Cooldown = 0.8f;
	CastTime = 0.45f;
	ReleaseDelay = 0.2f;
	Range = 4500.f;
	AnimationPlayRate = 1.4f;

	ProjectileClass = ARPGProjectile::StaticClass();
	Damage.DirectDamage = 32.f;
	Damage.SplashDamage = 12.f;
	Damage.SplashRadius = 280.f;
	Damage.BurnDamagePerSecond = 5.f;
	Damage.BurnDuration = 4.f;
	Damage.DamageType = UDamageType_Fire::StaticClass();
}

void USpell_Fireball::Execute(const FRPGSpellContext& Context)
{
	UWorld* World = GetWorld();
	ARPGCharacterBase* Caster = Context.Caster;
	if (!World || !Caster || !ProjectileClass)
	{
		return;
	}

	FVector Direction = (Context.AimLocation - Context.Origin).GetSafeNormal();
	if (Direction.IsNearlyZero())
	{
		Direction = Caster->GetActorForwardVector();
	}

	const FTransform SpawnTransform(Direction.Rotation(), Context.Origin);
	ARPGProjectile* Projectile = World->SpawnActorDeferred<ARPGProjectile>(ProjectileClass, SpawnTransform, Caster, Caster, ESpawnActorCollisionHandlingMethod::AlwaysSpawn);
	if (!Projectile)
	{
		return;
	}

	Projectile->Configure(Damage, Color, ProjectileSpeed);
	Projectile->FinishSpawning(SpawnTransform);
	Projectile->SetHomingTarget(Context.Target, HomingAcceleration);

	FRPGFXParams Flash;
	Flash.Color = Color;
	Flash.Intensity = 12.f;
	Flash.Lifetime = 0.2f;
	Flash.StartScale = FVector(0.2f);
	Flash.EndScale = FVector(0.9f);
	Flash.LightIntensity = 1500.f;
	Flash.LightRadius = 600.f;
	ARPGTransientFX::Spawn(Caster, Context.Origin, FRotator::ZeroRotator, Flash);
}

// ---------------------------------------------------------------------------------------------------------------------
// Frost Nova

USpell_FrostNova::USpell_FrostNova()
{
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Animation(ChargedAnimPath);
	CastAnimation = Animation.Object;

	DisplayName = LOCTEXT("FrostNovaName", "Frost Nova");
	Description = LOCTEXT("FrostNovaDesc", "Releases a wave of frost that damages and freezes nearby enemies, then slows them.");
	Color = FLinearColor(0.45f, 0.85f, 1.f);
	ManaCost = 30.f;
	Cooldown = 12.f;
	CastTime = 0.5f;
	ReleaseDelay = 0.25f;
	Range = 650.f;
	AnimationPlayRate = 1.8f;
	bFaceAim = false;
}

void USpell_FrostNova::Execute(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	if (!Caster)
	{
		return;
	}

	const FVector Center = Caster->GetActorLocation();
	const FVector Feet = GetFeetLocation(*Caster);

	FRPGFXParams Wave;
	Wave.Shape = ERPGFXShape::Cylinder;
	Wave.Color = Color;
	Wave.Intensity = 5.f;
	Wave.FresnelAmount = 0.7f;
	Wave.Lifetime = 0.7f;
	Wave.GrowTime = 0.3f;
	Wave.FadeStart = 0.25f;
	Wave.StartScale = FVector(1.f, 1.f, 0.6f);
	Wave.EndScale = FVector(Radius * 2.f / 100.f, Radius * 2.f / 100.f, 0.3f);
	Wave.LightIntensity = 8000.f;
	Wave.LightRadius = Radius * 1.6f;
	ARPGTransientFX::Spawn(Caster, Feet + FVector(0.f, 0.f, 20.f), FRotator::ZeroRotator, Wave);

	FRPGFXParams Burst;
	Burst.Color = FLinearColor(0.8f, 0.95f, 1.f);
	Burst.Intensity = 8.f;
	Burst.FresnelAmount = 0.8f;
	Burst.Lifetime = 0.35f;
	Burst.StartScale = FVector(0.5f);
	Burst.EndScale = FVector(3.5f);
	ARPGTransientFX::Spawn(Caster, Center, FRotator::ZeroRotator, Burst);

	for (ARPGCharacterBase* Target : URPGCombatLibrary::GetHostilesInRadius(Caster, Caster, Center, Radius))
	{
		URPGCombatLibrary::DealDamage(Target, Damage, Caster, Caster, UDamageType_Frost::StaticClass());
		if (!Target->IsAlive())
		{
			continue;
		}

		Target->GetStatusEffects()->ApplyFreeze(FreezeDuration);
		Target->GetStatusEffects()->ApplySlow(SlowMultiplier, FreezeDuration + SlowDuration);

		// Ice crystal encasing the frozen target.
		FRPGFXParams Ice;
		Ice.Shape = ERPGFXShape::Cone;
		Ice.Color = Color;
		Ice.Intensity = 1.5f;
		Ice.FresnelAmount = 0.6f;
		Ice.Lifetime = FreezeDuration;
		Ice.GrowTime = 0.15f;
		Ice.FadeStart = FMath::Max(0.f, FreezeDuration - 0.4f);
		Ice.StartScale = FVector(0.3f);
		Ice.EndScale = FVector(1.3f, 1.3f, 2.4f);
		ARPGTransientFX::Spawn(Caster, GetFeetLocation(*Target) + FVector(0.f, 0.f, 110.f), FRotator::ZeroRotator, Ice, Target);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Lightning Strike

USpell_LightningStrike::USpell_LightningStrike()
{
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Animation(AttackAnimPath2);
	CastAnimation = Animation.Object;

	DisplayName = LOCTEXT("LightningName", "Lightning Strike");
	Description = LOCTEXT("LightningDesc", "Calls down a lightning bolt on the target area after a brief warning, damaging and stunning enemies.");
	Color = FLinearColor(0.65f, 0.75f, 1.f);
	ManaCost = 30.f;
	Cooldown = 6.f;
	CastTime = 0.45f;
	ReleaseDelay = 0.2f;
	Range = 2800.f;
	AnimationPlayRate = 1.3f;
}

void USpell_LightningStrike::Execute(const FRPGSpellContext& Context)
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
		Blast->Configure(StrikeDelay, Radius, Damage, UDamageType_Lightning::StaticClass(), StunDuration, Color, Context.Target);
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
	ARPGTransientFX::Spawn(Caster, Context.Origin, FRotator::ZeroRotator, Spark);
}

// ---------------------------------------------------------------------------------------------------------------------
// Blink

USpell_Blink::USpell_Blink()
{
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Animation(DashAnimPath);
	CastAnimation = Animation.Object;

	DisplayName = LOCTEXT("BlinkName", "Blink");
	Description = LOCTEXT("BlinkDesc", "Teleports a short distance in the direction you are moving (or aiming when standing still).");
	Color = FLinearColor(0.7f, 0.35f, 1.f);
	ManaCost = 20.f;
	Cooldown = 6.f;
	CastTime = 0.25f;
	ReleaseDelay = 0.05f;
	Range = 900.f;
	AnimationPlayRate = 1.6f;
	bFaceAim = false;
}

void USpell_Blink::Execute(const FRPGSpellContext& Context)
{
	UWorld* World = GetWorld();
	ARPGCharacterBase* Caster = Context.Caster;
	if (!World || !Caster)
	{
		return;
	}

	const FVector Start = Caster->GetActorLocation();

	FVector Direction = Caster->GetLastMovementInputVector().GetSafeNormal2D();
	if (Direction.IsNearlyZero())
	{
		Direction = (Context.AimLocation - Start).GetSafeNormal2D();
	}
	if (Direction.IsNearlyZero())
	{
		Direction = Caster->GetActorForwardVector().GetSafeNormal2D();
	}

	const UCapsuleComponent* Capsule = Caster->GetCapsuleComponent();
	const float HalfHeight = Capsule->GetScaledCapsuleHalfHeight();
	const FCollisionShape Shape = FCollisionShape::MakeCapsule(Capsule->GetScaledCapsuleRadius(), HalfHeight);
	FCollisionQueryParams Params(SCENE_QUERY_STAT(RPGBlink), false, Caster);

	// Sweep slightly above the ground so small bumps do not cut the blink short.
	const FVector Lift(0.f, 0.f, 60.f);
	FVector Destination = Start + Direction * Distance;
	FHitResult Hit;
	if (World->SweepSingleByChannel(Hit, Start + Lift, Destination + Lift, FQuat::Identity, ECC_Pawn, Shape, Params))
	{
		Destination = Hit.Location - Lift - Direction * 10.f;
	}

	if (World->LineTraceSingleByChannel(Hit, Destination + FVector(0.f, 0.f, 300.f), Destination - FVector(0.f, 0.f, 1500.f), ECC_WorldStatic, Params))
	{
		Destination.Z = Hit.ImpactPoint.Z + HalfHeight + 2.f;
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
	ARPGTransientFX::Spawn(Caster, Start, FRotator::ZeroRotator, Puff);

	// Fall back to shorter hops if the destination is obstructed.
	const FRotator Facing = Direction.Rotation();
	bool bTeleported = false;
	for (float Fraction = 1.f; Fraction > 0.2f && !bTeleported; Fraction -= 0.25f)
	{
		const FVector Candidate = FMath::Lerp(Start, Destination, Fraction);
		bTeleported = Caster->TeleportTo(Candidate, Facing);
	}

	if (bTeleported)
	{
		FRPGFXParams Arrive = Puff;
		Arrive.StartScale = FVector(0.1f, 0.1f, 2.6f);
		Arrive.EndScale = FVector(1.4f, 1.4f, 2.f);
		ARPGTransientFX::Spawn(Caster, Caster->GetActorLocation(), FRotator::ZeroRotator, Arrive);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Arcane Shield

USpell_ArcaneShield::USpell_ArcaneShield()
{
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Animation(AttackAnimPath3);
	CastAnimation = Animation.Object;

	DisplayName = LOCTEXT("ShieldName", "Arcane Shield");
	Description = LOCTEXT("ShieldDesc", "Surrounds you with a barrier that absorbs incoming damage.");
	Color = FLinearColor(0.6f, 0.35f, 1.f);
	ManaCost = 35.f;
	Cooldown = 18.f;
	CastTime = 0.35f;
	ReleaseDelay = 0.1f;
	Range = 0.f;
	AnimationPlayRate = 1.5f;
	bFaceAim = false;
}

void USpell_ArcaneShield::Execute(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	if (!Caster)
	{
		return;
	}

	Caster->GetAttributes()->AddShield(AbsorbAmount, Duration);

	FRPGFXParams Burst;
	Burst.Color = Color;
	Burst.Intensity = 6.f;
	Burst.FresnelAmount = 0.9f;
	Burst.Lifetime = 0.45f;
	Burst.StartScale = FVector(0.6f);
	Burst.EndScale = FVector(3.f);
	Burst.LightIntensity = 3000.f;
	Burst.LightRadius = 700.f;
	ARPGTransientFX::Spawn(Caster, Caster->GetActorLocation(), FRotator::ZeroRotator, Burst, Caster);
}

#undef LOCTEXT_NAMESPACE
