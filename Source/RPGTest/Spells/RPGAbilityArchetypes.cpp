#include "Spells/RPGAbilityArchetypes.h"

#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGGameplayTags.h"
#include "Animation/AnimSequenceBase.h"
#include "Characters/RPGCharacterBase.h"
#include "Combat/RPGCombatLibrary.h"
#include "Components/CapsuleComponent.h"
#include "Engine/World.h"
#include "FX/RPGTransientFX.h"
#include "UObject/ConstructorHelpers.h"

// ---------------------------------------------------------------------------------------------------------------------
// FX helpers

namespace RPGAbilityFX
{
	FVector GetFeetLocation(const ARPGCharacterBase& Character)
	{
		return Character.GetActorLocation() - FVector(0.f, 0.f, Character.GetCapsuleComponent()->GetScaledCapsuleHalfHeight());
	}

	void SpawnBeam(const AActor* WorldContext, const FVector& From, const FVector& To, const FLinearColor& Color, float Lifetime, float Thickness)
	{
		const FVector Delta = To - From;
		const float Length = Delta.Size();
		if (Length < 1.f)
		{
			return;
		}

		// The cylinder primitive is 100 units tall along Z.
		FRPGFXParams Beam;
		Beam.Shape = ERPGFXShape::Cylinder;
		Beam.Color = Color;
		Beam.Intensity = 10.f;
		Beam.FresnelAmount = 0.2f;
		Beam.Lifetime = Lifetime;
		Beam.GrowTime = 0.05f;
		Beam.FadeStart = Lifetime * 0.4f;
		Beam.StartScale = FVector(Thickness * 1.6f, Thickness * 1.6f, Length / 100.f);
		Beam.EndScale = FVector(Thickness, Thickness, Length / 100.f);
		Beam.Flicker = 0.3f;
		ARPGTransientFX::SpawnForAll(WorldContext, From + Delta * 0.5f, FRotationMatrix::MakeFromZ(Delta / Length).Rotator(), Beam);
	}

	void SpawnBurst(const AActor* WorldContext, const FVector& Location, const FLinearColor& Color, float Size, AActor* AttachTo)
	{
		FRPGFXParams Burst;
		Burst.Color = Color;
		Burst.Intensity = 8.f;
		Burst.FresnelAmount = 0.7f;
		Burst.Lifetime = 0.4f;
		Burst.StartScale = FVector(Size * 0.2f);
		Burst.EndScale = FVector(Size);
		Burst.LightIntensity = 2500.f;
		Burst.LightRadius = 500.f;
		ARPGTransientFX::SpawnForAll(WorldContext, Location, FRotator::ZeroRotator, Burst, AttachTo);
	}

	void SpawnGroundRing(const ARPGCharacterBase& Character, const FLinearColor& Color, float Radius)
	{
		FRPGFXParams Wave;
		Wave.Shape = ERPGFXShape::Cylinder;
		Wave.Color = Color;
		Wave.Intensity = 5.f;
		Wave.FresnelAmount = 0.7f;
		Wave.Lifetime = 0.6f;
		Wave.GrowTime = 0.25f;
		Wave.FadeStart = 0.2f;
		Wave.StartScale = FVector(1.f, 1.f, 0.5f);
		Wave.EndScale = FVector(Radius * 2.f / 100.f, Radius * 2.f / 100.f, 0.25f);
		Wave.LightIntensity = 6000.f;
		Wave.LightRadius = Radius * 1.6f;
		ARPGTransientFX::SpawnForAll(&Character, GetFeetLocation(Character) + FVector(0.f, 0.f, 20.f), FRotator::ZeroRotator, Wave);
	}

	/** A quick horizontal streak in front of the caster, showing the swing's reach. */
	void SpawnSwing(const ARPGCharacterBase& Caster, const FLinearColor& Color, float Reach, float ArcDegrees)
	{
		const bool bSpin = ArcDegrees >= 300.f;
		FRPGFXParams Swing;
		Swing.Color = Color;
		Swing.Intensity = 6.f;
		Swing.FresnelAmount = 0.5f;
		Swing.Lifetime = bSpin ? 0.3f : 0.18f;
		Swing.GrowTime = 0.1f;
		Swing.FadeStart = 0.05f;
		Swing.StartScale = bSpin ? FVector(0.5f, 0.5f, 0.1f) : FVector(0.15f, 0.6f, 0.08f);
		Swing.EndScale = bSpin ? FVector(Reach * 2.f / 100.f, Reach * 2.f / 100.f, 0.15f) : FVector(0.35f, Reach / 55.f, 0.12f);
		const FVector Location = Caster.GetActorLocation() + FVector(0.f, 0.f, 10.f) + (bSpin ? FVector::ZeroVector : Caster.GetActorForwardVector() * Reach * 0.55f);
		ARPGTransientFX::SpawnForAll(&Caster, Location, Caster.GetActorRotation(), Swing);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Projectile

URPGAbility_Projectile::URPGAbility_Projectile()
{
	Payload.DamageType = RPGTags::Damage_Arcane;
}

void URPGAbility_Projectile::ExecuteSpell(const FRPGSpellContext& Context)
{
	FRPGProjectilePayload FinalPayload = Payload;
	FinalPayload.DirectDamage *= GetStealthMultiplier(Context);
	SpawnProjectile(Context, FinalPayload, ProjectileSpeed, HomingAcceleration, VisualScale);
	SpawnCastFlash(Context, 0.9f * VisualScale);
}

// ---------------------------------------------------------------------------------------------------------------------
// Melee strike

URPGAbility_MeleeStrike::URPGAbility_MeleeStrike()
{
	DamageType = RPGTags::Damage_Physical;
	bSlowsWhileCasting = false;
	CastTime = 0.5f;
	ReleaseDelay = 0.2f;
	AnimationPlayRate = 1.5f;
	Range = 450.f; // soft-lock distance for facing; the hit itself uses Reach
}

void URPGAbility_MeleeStrike::AddComboAnimation(const TCHAR* AnimationPath)
{
	ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Animation(AnimationPath);
	if (Animation.Succeeded())
	{
		ComboAnimations.Add(Animation.Object);
	}
}

void URPGAbility_MeleeStrike::ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData)
{
	if (ComboAnimations.Num() > 0)
	{
		CastAnimation = ComboAnimations[ComboIndex % ComboAnimations.Num()];
		ComboIndex = (ComboIndex + 1) % ComboAnimations.Num();
	}
	Super::ActivateAbility(Handle, ActorInfo, ActivationInfo, TriggerEventData);
}

void URPGAbility_MeleeStrike::ExecuteSpell(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	if (!Caster)
	{
		return;
	}

	// The client faced its target when the swing started; the server turns the same way before resolving the arc.
	if (Context.Target)
	{
		Caster->FaceLocation(Context.Target->GetActorLocation(), true);
	}
	RPGAbilityFX::SpawnSwing(*Caster, Color, Reach, bHitAllInArc ? ArcDegrees : FMath::Min(ArcDegrees, 120.f));

	TArray<ARPGCharacterBase*> Targets;
	if (bHitAllInArc)
	{
		Targets = URPGCombatLibrary::GetHostilesInArc(Caster, Reach, ArcDegrees);
	}
	else if (ARPGCharacterBase* Target = URPGCombatLibrary::FindMeleeTarget(Caster, Context.Target, Reach, ArcDegrees))
	{
		Targets.Add(Target);
	}

	bool bConnected = false;
	for (ARPGCharacterBase* Target : Targets)
	{
		float Amount = Damage * GetStealthMultiplier(Context);
		if (BehindDamageMultiplier > 1.f && URPGCombatLibrary::IsBehind(Caster, Target))
		{
			Amount *= BehindDamageMultiplier;
			Target->ShowCombatText(NSLOCTEXT("RPGAbilities", "Backstab", "BEHIND!"), FLinearColor(1.f, 0.85f, 0.3f));
		}

		if (!URPGCombatLibrary::ApplyDamage(Caster, Target, Amount, DamageType))
		{
			continue;
		}
		bConnected = true;

		URPGCombatLibrary::ApplyStatuses(Caster, Target, Statuses);
		if (Knockback > 0.f)
		{
			Target->ApplyKnockback(Target->GetActorLocation() - Caster->GetActorLocation(), Knockback, 80.f);
		}
		RPGAbilityFX::SpawnBurst(Caster, Target->GetTargetPoint(), Color, 0.7f);
		OnStrikeHit(Context, Target);
	}

	if (bConnected && ResourceOnHit != 0.f)
	{
		Caster->GetRPGAbilitySystem()->AddResource(ResourceOnHit);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Self buff

URPGAbility_SelfBuff::URPGAbility_SelfBuff()
{
	bFaceAim = false;
	bBreaksStealth = false;
	bSlowsWhileCasting = false;
	CastTime = 0.3f;
	ReleaseDelay = 0.1f;
	Range = 0.f;
	AnimationPlayRate = 1.5f;
}

void URPGAbility_SelfBuff::ExecuteSpell(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	URPGAbilitySystemComponent* AbilitySystem = Caster ? Caster->GetRPGAbilitySystem() : nullptr;
	if (!AbilitySystem)
	{
		return;
	}

	AbilitySystem->RemoveStatuses(RemoveStatuses);
	for (const FRPGStatusSpec& Status : Statuses)
	{
		AbilitySystem->ApplyStatus(Status, Caster);
	}
	if (HealAmount > 0.f)
	{
		URPGCombatLibrary::ApplyHeal(Caster, Caster, HealAmount);
	}
	if (ShieldAmount > 0.f)
	{
		AbilitySystem->AddShield(ShieldAmount, ShieldDuration);
	}

	RPGAbilityFX::SpawnBurst(Caster, Caster->GetActorLocation(), Color, 3.f, Caster);
}

// ---------------------------------------------------------------------------------------------------------------------
// Targeted debuff

URPGAbility_TargetedDebuff::URPGAbility_TargetedDebuff()
{
	bRequiresTarget = true;
	DamageType = RPGTags::Damage_Shadow;
	CastTime = 0.45f;
	ReleaseDelay = 0.2f;
	Range = 2500.f;
}

void URPGAbility_TargetedDebuff::ExecuteSpell(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	ARPGCharacterBase* Target = Context.Target;
	if (!Caster || !Target)
	{
		return;
	}

	FCollisionQueryParams Params(SCENE_QUERY_STAT(RPGDebuffSight), false, Caster);
	Params.AddIgnoredActor(Target);
	if (GetWorld()->LineTraceTestByChannel(Context.Origin, Target->GetTargetPoint(), ECC_Visibility, Params))
	{
		// Out of sight since the client aimed: the spell fizzles.
		RPGAbilityFX::SpawnBurst(Caster, Context.Origin, Color, 0.6f);
		return;
	}

	RPGAbilityFX::SpawnBeam(Caster, Context.Origin, Target->GetTargetPoint(), Color, 0.25f);
	RPGAbilityFX::SpawnBurst(Caster, Target->GetTargetPoint(), Color, 1.6f, Target);

	if (Damage > 0.f)
	{
		URPGCombatLibrary::ApplyDamage(Caster, Target, Damage * GetStealthMultiplier(Context), DamageType);
	}
	URPGCombatLibrary::ApplyStatuses(Caster, Target, Statuses);
}

// ---------------------------------------------------------------------------------------------------------------------
// Nova

URPGAbility_Nova::URPGAbility_Nova()
{
	DamageType = RPGTags::Damage_Physical;
	bFaceAim = false;
}

void URPGAbility_Nova::ExecuteSpell(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	if (!Caster)
	{
		return;
	}

	RPGAbilityFX::SpawnGroundRing(*Caster, Color, Radius);

	for (ARPGCharacterBase* Target : URPGCombatLibrary::GetHostilesInRadius(Caster, Caster, Caster->GetActorLocation(), Radius))
	{
		if (!URPGCombatLibrary::ApplyDamage(Caster, Target, Damage * GetStealthMultiplier(Context), DamageType))
		{
			continue;
		}
		URPGCombatLibrary::ApplyStatuses(Caster, Target, Statuses);
		if (Knockback > 0.f)
		{
			Target->ApplyKnockback(Target->GetActorLocation() - Caster->GetActorLocation(), Knockback, 120.f);
		}
		OnNovaHit(Context, Target);
	}
}
