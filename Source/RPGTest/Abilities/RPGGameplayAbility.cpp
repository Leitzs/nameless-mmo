#include "Abilities/RPGGameplayAbility.h"

#include "AbilitySystemComponent.h"
#include "Abilities/GameplayAbilityTargetTypes.h"
#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGAttributeSet.h"
#include "Abilities/RPGGameplayEffects.h"
#include "Abilities/RPGGameplayTags.h"
#include "Abilities/Tasks/AbilityTask_WaitDelay.h"
#include "Animation/AnimSequenceBase.h"
#include "Characters/RPGCharacterBase.h"
#include "Engine/World.h"
#include "FX/RPGTransientFX.h"
#include "GameplayPrediction.h"
#include "RPGTest.h"
#include "Spells/RPGProjectile.h"
#include "UObject/ConstructorHelpers.h"

namespace RPGGameplayAbilityPrivate
{
	/** Extra distance the server accepts between a client's aim and the ability range (movement since the client aimed). */
	constexpr float AimRangeTolerance = 600.f;

	/** How long the server waits for a remote client's aim after the cast time before giving up. */
	constexpr float ReleaseTimeout = 1.f;
}

URPGGameplayAbility::URPGGameplayAbility()
{
	InstancingPolicy = EGameplayAbilityInstancingPolicy::InstancedPerActor;
	NetExecutionPolicy = EGameplayAbilityNetExecutionPolicy::LocalPredicted;
}

void URPGGameplayAbility::PostInitProperties()
{
	Super::PostInitProperties();

	// Subclass constructors decide bSlowsWhileCasting, so the tags are derived once they have run.
	ActivationOwnedTags.AddTag(bSlowsWhileCasting ? RPGTags::State_Casting_Slow : RPGTags::State_Casting);
	ActivationBlockedTags.AddTag(RPGTags::State_Casting);
	ActivationBlockedTags.AddTag(RPGTags::State_Dead);
}

ARPGCharacterBase* URPGGameplayAbility::GetCaster() const
{
	return CurrentActorInfo ? Cast<ARPGCharacterBase>(CurrentActorInfo->AvatarActor.Get()) : nullptr;
}

void URPGGameplayAbility::SetCastAnimation(const TCHAR* AnimationPath)
{
	ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Animation(AnimationPath);
	CastAnimation = Animation.Object;
}

bool URPGGameplayAbility::IsServerForRemoteClient(const FGameplayAbilityActorInfo* ActorInfo) const
{
	return ActorInfo && ActorInfo->IsNetAuthority() && !ActorInfo->IsLocallyControlled();
}

ERPGCastResult URPGGameplayAbility::CheckTarget(const ARPGCharacterBase& Caster, const ARPGCharacterBase& Target) const
{
	return ERPGCastResult::Success;
}

bool URPGGameplayAbility::CanActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayTagContainer* SourceTags, const FGameplayTagContainer* TargetTags, FGameplayTagContainer* OptionalRelevantTags) const
{
	if (!Super::CanActivateAbility(Handle, ActorInfo, SourceTags, TargetTags, OptionalRelevantTags))
	{
		return false;
	}

	const ARPGCharacterBase* Caster = ActorInfo ? Cast<ARPGCharacterBase>(ActorInfo->AvatarActor.Get()) : nullptr;
	if (!Caster || !Caster->IsAlive())
	{
		return false;
	}
	if (Caster->IsIncapacitated() && !bUsableWhileIncapacitated)
	{
		return false;
	}
	return CheckCasterState(*Caster) == ERPGCastResult::Success;
}

// ---------------------------------------------------------------------------------------------------------------------
// Cost and cooldown

const FGameplayTagContainer* URPGGameplayAbility::GetCooldownTags() const
{
	CooldownTagContainer.Reset();
	if (CooldownTag.IsValid())
	{
		CooldownTagContainer.AddTag(CooldownTag);
	}
	return &CooldownTagContainer;
}

void URPGGameplayAbility::ApplyCooldown(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo) const
{
	const ARPGCharacterBase* Caster = ActorInfo ? Cast<ARPGCharacterBase>(ActorInfo->AvatarActor.Get()) : nullptr;
	float Duration = GetCooldownDuration(Caster);
	if (IsServerForRemoteClient(ActorInfo))
	{
		Duration -= URPGAbilitySystemComponent::ServerTimeTolerance;
	}
	if (Duration <= 0.f || !CooldownTag.IsValid())
	{
		return;
	}

	const FGameplayEffectSpecHandle Spec = MakeOutgoingGameplayEffectSpec(Handle, ActorInfo, ActivationInfo, URPGEffect_Timed::StaticClass(), GetAbilityLevel(Handle, ActorInfo));
	if (Spec.IsValid())
	{
		Spec.Data->SetSetByCallerMagnitude(RPGTags::Data_Duration, Duration);
		Spec.Data->DynamicGrantedTags.AddTag(CooldownTag);
		ApplyGameplayEffectSpecToOwner(Handle, ActorInfo, ActivationInfo, Spec);
	}
}

bool URPGGameplayAbility::CheckCost(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, FGameplayTagContainer* OptionalRelevantTags) const
{
	if (ResourceCost <= 0.f)
	{
		return true;
	}

	const UAbilitySystemComponent* AbilitySystem = ActorInfo ? ActorInfo->AbilitySystemComponent.Get() : nullptr;
	const URPGAttributeSet* Attributes = AbilitySystem ? AbilitySystem->GetSet<URPGAttributeSet>() : nullptr;
	return Attributes && Attributes->GetResource() + KINDA_SMALL_NUMBER >= ResourceCost;
}

void URPGGameplayAbility::ApplyCost(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo) const
{
	if (ResourceCost <= 0.f)
	{
		return;
	}

	const FGameplayEffectSpecHandle Spec = MakeOutgoingGameplayEffectSpec(Handle, ActorInfo, ActivationInfo, URPGEffect_Cost::StaticClass(), GetAbilityLevel(Handle, ActorInfo));
	if (Spec.IsValid())
	{
		Spec.Data->SetSetByCallerMagnitude(RPGTags::Data_Cost, -ResourceCost);
		ApplyGameplayEffectSpecToOwner(Handle, ActorInfo, ActivationInfo, Spec);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Activation

void URPGGameplayAbility::ActivateAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo, const FGameplayEventData* TriggerEventData)
{
	bReleased = false;
	bCastTimeElapsed = false;
	bFromStealth = false;
	bHeld = false;

	ARPGCharacterBase* Caster = GetCaster();
	if (!Caster || !CommitAbility(Handle, ActorInfo, ActivationInfo))
	{
		EndAbility(Handle, ActorInfo, ActivationInfo, true, true);
		return;
	}

	bFromStealth = Caster->IsStealthed();
	if (bFromStealth && bBreaksStealth && ActorInfo->IsNetAuthority())
	{
		Caster->GetRPGAbilitySystem()->RemoveStatuses(FGameplayTagContainer(RPGTags::Status_Stealth));
	}

	if (IsLocallyControlled())
	{
		// Read before turning: the camera is attached to the character, so it swings with an instant turn until
		// its next update, and an immediate release must not aim with it.
		ARPGCharacterBase* AimTarget = nullptr;
		Caster->ComputeAim(Range, ActivationAimLocation, AimTarget);
		ActivationAimTarget = AimTarget;
		if (bFaceAim)
		{
			Caster->FaceLocation(ActivationAimLocation, true);
		}
	}

	Caster->PlayActionAnimationForAll(CastAnimation, AnimationPlayRate);

	float EffectiveCastTime = CastTime;
	if (IsServerForRemoteClient(ActorInfo))
	{
		EffectiveCastTime -= URPGAbilitySystemComponent::ServerTimeTolerance;
	}
	else
	{
		EffectiveCastTime = FMath::Max(EffectiveCastTime, ReleaseDelay);
	}

	if (EffectiveCastTime > 0.f)
	{
		UAbilityTask_WaitDelay* WaitCast = UAbilityTask_WaitDelay::WaitDelay(this, EffectiveCastTime);
		WaitCast->OnFinish.AddDynamic(this, &ThisClass::OnCastTimeElapsed);
		WaitCast->ReadyForActivation();
	}
	else
	{
		bCastTimeElapsed = true;
	}

	if (IsLocallyControlled())
	{
		if (ReleaseDelay <= 0.f)
		{
			ReleaseLocal(true);
		}
		else
		{
			UAbilityTask_WaitDelay* WaitRelease = UAbilityTask_WaitDelay::WaitDelay(this, ReleaseDelay);
			WaitRelease->OnFinish.AddDynamic(this, &ThisClass::OnReleaseTimer);
			WaitRelease->ReadyForActivation();
		}
	}
	else if (ActorInfo->IsNetAuthority())
	{
		// A remote client casts: wait for the aim it reads from its own camera at the release point.
		UAbilitySystemComponent* AbilitySystem = ActorInfo->AbilitySystemComponent.Get();
		const FPredictionKey ActivationKey = ActivationInfo.GetActivationPredictionKey();
		TargetDataDelegateHandle = AbilitySystem->AbilityTargetDataSetDelegate(Handle, ActivationKey).AddUObject(this, &ThisClass::OnServerTargetData);
		AbilitySystem->CallReplicatedTargetDataDelegatesIfSet(Handle, ActivationKey);
	}
}

void URPGGameplayAbility::OnReleaseTimer()
{
	ReleaseLocal(false);
}

void URPGGameplayAbility::ReleaseLocal(bool bSameFrameAsActivation)
{
	if (!IsActive() || bReleased)
	{
		return;
	}

	ARPGCharacterBase* Caster = GetCaster();
	if (!Caster || !Caster->IsAlive() || (Caster->IsIncapacitated() && !bUsableWhileIncapacitated))
	{
		// Interrupted during the wind-up: the cost and cooldown stay spent.
		CancelAbility(CurrentSpecHandle, CurrentActorInfo, CurrentActivationInfo, true);
		return;
	}

	FVector AimLocation = ActivationAimLocation;
	ARPGCharacterBase* Target = ActivationAimTarget;
	if (!bSameFrameAsActivation)
	{
		Caster->ComputeAim(Range, AimLocation, Target);
	}

	if (!CurrentActorInfo->IsNetAuthority())
	{
		FGameplayAbilityTargetData_SingleTargetHit* Data = new FGameplayAbilityTargetData_SingleTargetHit();
		Data->HitResult.Location = AimLocation;
		Data->HitResult.ImpactPoint = AimLocation;
		if (Target)
		{
			Data->HitResult.HitObjectHandle = FActorInstanceHandle(Target);
		}
		const FGameplayAbilityTargetDataHandle DataHandle(Data);

		UAbilitySystemComponent* AbilitySystem = CurrentActorInfo->AbilitySystemComponent.Get();
		FScopedPredictionWindow ScopedPrediction(AbilitySystem, IsPredictingClient());
		AbilitySystem->CallServerSetReplicatedTargetData(CurrentSpecHandle, CurrentActivationInfo.GetActivationPredictionKey(), DataHandle, FGameplayTag(), AbilitySystem->ScopedPredictionKey);
	}

	Release(AimLocation, Target);
}

void URPGGameplayAbility::OnServerTargetData(const FGameplayAbilityTargetDataHandle& Data, FGameplayTag ApplicationTag)
{
	using namespace RPGGameplayAbilityPrivate;

	UAbilitySystemComponent* AbilitySystem = CurrentActorInfo ? CurrentActorInfo->AbilitySystemComponent.Get() : nullptr;
	if (AbilitySystem)
	{
		AbilitySystem->ConsumeClientReplicatedTargetData(CurrentSpecHandle, CurrentActivationInfo.GetActivationPredictionKey());
	}

	ARPGCharacterBase* Caster = GetCaster();
	const FGameplayAbilityTargetData* TargetData = Data.Get(0);
	const FHitResult* Hit = TargetData ? TargetData->GetHitResult() : nullptr;
	if (!IsActive() || bReleased || !Caster || !Hit)
	{
		return;
	}
	if (!Caster->IsAlive() || (Caster->IsIncapacitated() && !bUsableWhileIncapacitated))
	{
		EndAbility(CurrentSpecHandle, CurrentActorInfo, CurrentActivationInfo, true, true);
		return;
	}

	// Trust the client's aim within reason: clamp it to the range and drop targets it could not have locked onto.
	const FVector CasterLocation = Caster->GetActorLocation();
	const float MaxDistance = FMath::Max(Range, 100.f) + AimRangeTolerance;
	FVector AimLocation = Hit->Location;
	if (FVector::DistSquared(CasterLocation, AimLocation) > FMath::Square(MaxDistance))
	{
		AimLocation = CasterLocation + (AimLocation - CasterLocation).GetSafeNormal() * MaxDistance;
	}

	ARPGCharacterBase* Target = Cast<ARPGCharacterBase>(Hit->GetActor());
	if (Target && (!Target->IsAlive() || !Caster->IsHostileTo(Target) || !Target->IsVisibleTo(Caster)
		|| FVector::DistSquared(CasterLocation, Target->GetActorLocation()) > FMath::Square(MaxDistance)))
	{
		Target = nullptr;
	}

	Release(AimLocation, Target);
}

void URPGGameplayAbility::Release(const FVector& AimLocation, ARPGCharacterBase* Target)
{
	ARPGCharacterBase* Caster = GetCaster();
	if (!Caster)
	{
		return;
	}

	FRPGSpellContext Context;
	Context.Caster = Caster;
	Context.Origin = Caster->GetSpellOrigin();
	Context.AimLocation = AimLocation;
	Context.Target = Target;
	Context.bFromStealth = bFromStealth;

	bReleased = true;
	OnRelease(Context);
	if (IsActive() && CurrentActorInfo->IsNetAuthority())
	{
		UE_LOG(LogRPG, Verbose, TEXT("%s releases %s at %s, target %s"), *Caster->GetName(), *GetName(), *AimLocation.ToCompactString(), Target ? *Target->GetName() : TEXT("none"));
		ExecuteSpell(Context);
	}
	TryFinish();
}

void URPGGameplayAbility::OnCastTimeElapsed()
{
	bCastTimeElapsed = true;

	if (!bReleased && IsServerForRemoteClient(CurrentActorInfo))
	{
		// The client's aim is late (or lost): give it a moment, then drop the cast.
		UAbilityTask_WaitDelay* WaitTimeout = UAbilityTask_WaitDelay::WaitDelay(this, RPGGameplayAbilityPrivate::ReleaseTimeout);
		WaitTimeout->OnFinish.AddDynamic(this, &ThisClass::OnReleaseTimedOut);
		WaitTimeout->ReadyForActivation();
		return;
	}
	TryFinish();
}

void URPGGameplayAbility::OnReleaseTimedOut()
{
	if (IsActive())
	{
		EndAbility(CurrentSpecHandle, CurrentActorInfo, CurrentActivationInfo, true, true);
	}
}

void URPGGameplayAbility::TryFinish()
{
	if (IsActive() && bReleased && bCastTimeElapsed && !bHeld)
	{
		EndAbility(CurrentSpecHandle, CurrentActorInfo, CurrentActivationInfo, true, false);
	}
}

void URPGGameplayAbility::FinishHold()
{
	bHeld = false;
	bCastTimeElapsed = true;

	if (CurrentActorInfo && !CurrentActorInfo->IsNetAuthority())
	{
		// A remote client lets the server end it: the server resolves the outcome (a dash's hit) and started later,
		// so ending here would cut the server's version short. Fall back to ending locally if that never arrives.
		UAbilityTask_WaitDelay* WaitServer = UAbilityTask_WaitDelay::WaitDelay(this, RPGGameplayAbilityPrivate::ReleaseTimeout);
		WaitServer->OnFinish.AddDynamic(this, &ThisClass::OnReleaseTimedOut);
		WaitServer->ReadyForActivation();
		return;
	}
	TryFinish();
}

void URPGGameplayAbility::EndAbility(const FGameplayAbilitySpecHandle Handle, const FGameplayAbilityActorInfo* ActorInfo, const FGameplayAbilityActivationInfo ActivationInfo, bool bReplicateEndAbility, bool bWasCancelled)
{
	if (TargetDataDelegateHandle.IsValid() && ActorInfo)
	{
		if (UAbilitySystemComponent* AbilitySystem = ActorInfo->AbilitySystemComponent.Get())
		{
			AbilitySystem->AbilityTargetDataSetDelegate(Handle, ActivationInfo.GetActivationPredictionKey()).Remove(TargetDataDelegateHandle);
		}
		TargetDataDelegateHandle.Reset();
	}

	Super::EndAbility(Handle, ActorInfo, ActivationInfo, bReplicateEndAbility, bWasCancelled);
}

// ---------------------------------------------------------------------------------------------------------------------
// Helpers for subclasses

ARPGProjectile* URPGGameplayAbility::SpawnProjectile(const FRPGSpellContext& Context, const FRPGProjectilePayload& Payload, float Speed, float HomingAcceleration, float VisualScale) const
{
	UWorld* World = GetWorld();
	ARPGCharacterBase* Caster = Context.Caster;
	if (!World || !Caster)
	{
		return nullptr;
	}

	FVector Direction = (Context.AimLocation - Context.Origin).GetSafeNormal();
	if (Direction.IsNearlyZero())
	{
		Direction = Caster->GetActorForwardVector();
	}

	const FTransform SpawnTransform(Direction.Rotation(), Context.Origin);
	ARPGProjectile* Projectile = World->SpawnActorDeferred<ARPGProjectile>(ARPGProjectile::StaticClass(), SpawnTransform, Caster, Caster, ESpawnActorCollisionHandlingMethod::AlwaysSpawn);
	if (!Projectile)
	{
		return nullptr;
	}

	Projectile->Configure(Payload, Color, Speed, Range, VisualScale);
	Projectile->FinishSpawning(SpawnTransform);
	Projectile->SetHomingTarget(Context.Target, HomingAcceleration);
	return Projectile;
}

void URPGGameplayAbility::SpawnCastFlash(const FRPGSpellContext& Context, float Size) const
{
	FRPGFXParams Flash;
	Flash.Color = Color;
	Flash.Intensity = 12.f;
	Flash.Lifetime = 0.2f;
	Flash.StartScale = FVector(Size * 0.25f);
	Flash.EndScale = FVector(Size);
	Flash.LightIntensity = 1500.f;
	Flash.LightRadius = 600.f;
	ARPGTransientFX::SpawnForAll(Context.Caster, Context.Origin, FRotator::ZeroRotator, Flash);
}
