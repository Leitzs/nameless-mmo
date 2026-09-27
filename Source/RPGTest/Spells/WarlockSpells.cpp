#include "Spells/WarlockSpells.h"

#include "Abilities/RPGGameplayTags.h"
#include "Characters/RPGCharacterBase.h"
#include "Combat/RPGCombatLibrary.h"
#include "Core/RPGAssets.h"
#include "Engine/World.h"
#include "FX/RPGTransientFX.h"
#include "Spells/MageSpells.h"
#include "Spells/RPGDemonicCircle.h"
#include "TimerManager.h"

#define LOCTEXT_NAMESPACE "RPGWarlockSpells"

namespace WarlockSpellTags
{
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_ShadowBolt, "Cooldown.Warlock.ShadowBolt");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_DrainLife, "Cooldown.Warlock.DrainLife");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_Fear, "Cooldown.Warlock.Fear");
	UE_DEFINE_GAMEPLAY_TAG_STATIC(Cooldown_DemonicCircle, "Cooldown.Warlock.DemonicCircle");
}

namespace WarlockSpellsPrivate
{
	const FLinearColor ShadowColor(0.6f, 0.2f, 1.f);
	const FLinearColor FelColor(0.4f, 1.f, 0.2f);
}

// ---------------------------------------------------------------------------------------------------------------------
// Fel Bolt

USpell_FelBolt::USpell_FelBolt()
{
	SetCastAnimation(RPGAssets::AttackAnim3);

	DisplayName = LOCTEXT("FelBoltName", "Fel Bolt");
	Description = LOCTEXT("FelBoltDesc", "A quick bolt of fel fire. Costs nothing.");
	Color = WarlockSpellsPrivate::FelColor;
	CastTime = 0.6f;
	ReleaseDelay = 0.15f;
	Range = 3200.f;
	AnimationPlayRate = 1.8f;

	Payload.DirectDamage = 10.f;
	Payload.DamageType = RPGTags::Damage_Shadow;
	ProjectileSpeed = 3300.f;
	HomingAcceleration = 7000.f;
	VisualScale = 0.6f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Shadow Bolt

USpell_ShadowBolt::USpell_ShadowBolt()
{
	SetCastAnimation(RPGAssets::ChargedAttackAnim);

	DisplayName = LOCTEXT("ShadowBoltName", "Shadow Bolt");
	Description = LOCTEXT("ShadowBoltDesc", "Gathers darkness for a moment, then hurls a slow bolt of shadow that hits very hard.");
	Color = WarlockSpellsPrivate::ShadowColor;
	CooldownTag = WarlockSpellTags::Cooldown_ShadowBolt;
	ResourceCost = 25.f;
	Cooldown = 3.f;
	CastTime = 1.f;
	ReleaseDelay = 0.7f;
	Range = 4000.f;
	AnimationPlayRate = 1.f;

	Payload.DirectDamage = 50.f;
	Payload.SplashDamage = 10.f;
	Payload.SplashRadius = 200.f;
	Payload.DamageType = RPGTags::Damage_Shadow;
	ProjectileSpeed = 1900.f;
	HomingAcceleration = 5000.f;
	VisualScale = 1.4f;
}

// ---------------------------------------------------------------------------------------------------------------------
// Corruption

USpell_Corruption::USpell_Corruption()
{
	SetCastAnimation(RPGAssets::AttackAnim2);

	DisplayName = LOCTEXT("CorruptionName", "Corruption");
	Description = LOCTEXT("CorruptionDesc", "Corrupts the target, dealing shadow damage over 12 seconds. Targets taking damage over time cannot enter stealth.");
	Color = FLinearColor(0.5f, 0.1f, 0.7f);
	ResourceCost = 20.f;
	CastTime = 0.4f;
	ReleaseDelay = 0.15f;
	Range = 3000.f;
	AnimationPlayRate = 1.6f;
	bSlowsWhileCasting = false;

	Statuses.Emplace(RPGTags::Status_DoT_Corruption, 12.f, 8.f);
}

// ---------------------------------------------------------------------------------------------------------------------
// Drain Life

USpell_DrainLife::USpell_DrainLife()
{
	SetCastAnimation(RPGAssets::ChargedAttackAnim);

	DisplayName = LOCTEXT("DrainLifeName", "Drain Life");
	Description = LOCTEXT("DrainLifeDesc", "Channels a beam that drains the target's life for 3 seconds, healing you for the damage dealt. Stuns and line of sight break it.");
	Color = FLinearColor(0.3f, 0.95f, 0.35f);
	CooldownTag = WarlockSpellTags::Cooldown_DrainLife;
	ResourceCost = 30.f;
	Cooldown = 10.f;
	ReleaseDelay = 0.2f;
	CastTime = ReleaseDelay + ChannelDuration;
	Range = 2500.f;
	AnimationPlayRate = 0.6f;
	bRequiresTarget = true;
}

void USpell_DrainLife::ExecuteSpell(const FRPGSpellContext& Context)
{
	if (!Context.Target)
	{
		EndAbility(CurrentSpecHandle, CurrentActorInfo, CurrentActivationInfo, true, true);
		return;
	}

	DrainTarget = Context.Target;
	TicksLeft = FMath::Max(1, FMath::RoundToInt(ChannelDuration / TickInterval));
	GetWorld()->GetTimerManager().SetTimer(DrainTimer, FTimerDelegate::CreateUObject(this, &ThisClass::DrainTick), TickInterval, true, 0.f);
}

void USpell_DrainLife::DrainTick()
{
	ARPGCharacterBase* Caster = GetCaster();
	ARPGCharacterBase* Target = DrainTarget.Get();
	if (!IsActive() || !Caster || !Caster->IsAlive())
	{
		return;
	}

	bool bValid = Target && Target->IsAlive() && FVector::Dist(Caster->GetActorLocation(), Target->GetActorLocation()) <= Range + 300.f;
	if (bValid)
	{
		FCollisionQueryParams Params(SCENE_QUERY_STAT(RPGDrainSight), false, Caster);
		Params.AddIgnoredActor(Target);
		bValid = !GetWorld()->LineTraceTestByChannel(Caster->GetSpellOrigin(), Target->GetTargetPoint(), ECC_Visibility, Params);
	}
	if (!bValid)
	{
		EndAbility(CurrentSpecHandle, CurrentActorInfo, CurrentActivationInfo, true, true);
		return;
	}

	RPGAbilityFX::SpawnBeam(Caster, Caster->GetSpellOrigin(), Target->GetTargetPoint(), Color, TickInterval + 0.05f, 0.1f);

	// Heal for what actually got through (shields and immunities count as nothing drained).
	const float Before = Target->GetHealth();
	URPGCombatLibrary::ApplyDamage(Caster, Target, DamagePerTick, RPGTags::Damage_Shadow);
	const float Drained = FMath::Max(0.f, Before - Target->GetHealth());
	if (Drained > 0.f)
	{
		URPGCombatLibrary::ApplyHeal(Caster, Caster, Drained * HealFraction);
	}

	if (--TicksLeft <= 0)
	{
		GetWorld()->GetTimerManager().ClearTimer(DrainTimer);
	}
}

void USpell_DrainLife::EndAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo, bool bReplicateEndAbility, bool bWasCancelled)
{
	if (UWorld* World = GetWorld())
	{
		World->GetTimerManager().ClearTimer(DrainTimer);
	}
	DrainTarget.Reset();

	Super::EndAbility(Handle, ActorInfo, ActivationInfo, bReplicateEndAbility, bWasCancelled);
}

// ---------------------------------------------------------------------------------------------------------------------
// Fear

USpell_Fear::USpell_Fear()
{
	SetCastAnimation(RPGAssets::AttackAnim1);

	DisplayName = LOCTEXT("FearName", "Fear");
	Description = LOCTEXT("FearDesc", "Strikes terror into the target, who runs in panic for 3 seconds. Heavy damage breaks the effect.");
	Color = FLinearColor(0.55f, 0.1f, 0.85f);
	CooldownTag = WarlockSpellTags::Cooldown_Fear;
	ResourceCost = 30.f;
	Cooldown = 20.f;
	CastTime = 0.6f;
	ReleaseDelay = 0.35f;
	Range = 2000.f;
	AnimationPlayRate = 1.4f;

	Statuses.Emplace(RPGTags::Status_CC_Fear, 3.f);
}

// ---------------------------------------------------------------------------------------------------------------------
// Demonic Circle

USpell_DemonicCircle::USpell_DemonicCircle()
{
	SetCastAnimation(RPGAssets::DashAnim);

	DisplayName = LOCTEXT("CircleName", "Demonic Circle");
	Description = LOCTEXT("CircleDesc", "Leaves a demonic circle at your feet. Use it again to teleport back to the circle.");
	Color = WarlockSpellsPrivate::FelColor;
	CooldownTag = WarlockSpellTags::Cooldown_DemonicCircle;
	ResourceCost = 15.f;
	CastTime = 0.3f;
	ReleaseDelay = 0.05f;
	Range = 0.f;
	AnimationPlayRate = 1.6f;
	bFaceAim = false;
	bSlowsWhileCasting = false;
	bBreaksStealth = false;
}

bool USpell_DemonicCircle::CanReturn(const ARPGCharacterBase* Caster) const
{
	const ARPGDemonicCircle* Circle = ARPGDemonicCircle::FindFor(Caster);
	return Circle && FVector::Dist(Circle->GetActorLocation(), Caster->GetActorLocation()) <= MaxReturnDistance;
}

FText USpell_DemonicCircle::GetSlotLabel(const ARPGCharacterBase& Caster) const
{
	return CanReturn(&Caster) ? LOCTEXT("CircleReturn", "Return") : DisplayName;
}

float USpell_DemonicCircle::GetCooldownDuration(const ARPGCharacterBase* Caster) const
{
	return CanReturn(Caster) ? ReturnCooldown : PlaceCooldown;
}

void USpell_DemonicCircle::ExecuteSpell(const FRPGSpellContext& Context)
{
	ARPGCharacterBase* Caster = Context.Caster;
	UWorld* World = GetWorld();
	if (!Caster || !World)
	{
		return;
	}

	ARPGDemonicCircle* Circle = ARPGDemonicCircle::FindFor(Caster);
	if (Circle && CanReturn(Caster))
	{
		RPGAbilityFX::SpawnBurst(Caster, Caster->GetActorLocation(), Color, 2.5f);
		const FVector Destination = Circle->GetActorLocation() + FVector(0.f, 0.f, 100.f);
		Circle->Destroy();
		if (RPGSpellHelpers::TeleportCharacter(*Caster, Destination, Caster->GetActorRotation(), false))
		{
			RPGAbilityFX::SpawnBurst(Caster, Caster->GetActorLocation(), Color, 2.5f);
		}
		return;
	}

	if (Circle)
	{
		Circle->Destroy();
	}

	FActorSpawnParameters SpawnParams;
	SpawnParams.Owner = Caster;
	SpawnParams.Instigator = Caster;
	SpawnParams.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	World->SpawnActor<ARPGDemonicCircle>(ARPGDemonicCircle::StaticClass(), RPGAbilityFX::GetFeetLocation(*Caster) + FVector(0.f, 0.f, 3.f), FRotator::ZeroRotator, SpawnParams);
	RPGAbilityFX::SpawnGroundRing(*Caster, Color, 150.f);
}

#undef LOCTEXT_NAMESPACE
