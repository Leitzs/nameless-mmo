#include "Abilities/RPGAbilitySystemComponent.h"

#include "AbilitySystemGlobals.h"
#include "Abilities/RPGAttributeSet.h"
#include "Abilities/RPGGameplayAbility.h"
#include "Abilities/RPGGameplayEffects.h"
#include "Abilities/RPGGameplayTags.h"
#include "Abilities/RPGStatusEffects.h"
#include "Characters/RPGCharacterBase.h"
#include "Engine/World.h"
#include "RPGTest.h"

#define LOCTEXT_NAMESPACE "RPGAbilitySystem"

namespace RPGAbilitySystemPrivate
{
	constexpr float RegenInterval = 0.1f;

	/** Diminishing returns: each repeated crowd control in the same category lasts this fraction; after the last one the target is immune. */
	constexpr float DiminishingFactors[] = { 1.f, 0.5f, 0.25f };
	constexpr float DiminishingResetSeconds = 15.f;

	const FLinearColor ImmuneColor(1.f, 0.9f, 0.55f);
}

URPGAbilitySystemComponent::URPGAbilitySystemComponent()
{
	SetIsReplicatedByDefault(true);
	// Players get their own effects in full and everyone else's as tags; see ARPGCharacterBase for bots.
	SetReplicationMode(EGameplayEffectReplicationMode::Mixed);
}

void URPGAbilitySystemComponent::BeginPlay()
{
	Super::BeginPlay();

	RegisterGameplayTagEvent(RPGTags::Status_CC, EGameplayTagEventType::NewOrRemoved).AddUObject(this, &ThisClass::OnIncapacitatedChanged);
	RegisterGameplayTagEvent(RPGTags::Status_Barrier, EGameplayTagEventType::NewOrRemoved).AddUObject(this, &ThisClass::OnBarrierChanged);
}

ARPGCharacterBase* URPGAbilitySystemComponent::GetCharacter() const
{
	return Cast<ARPGCharacterBase>(GetAvatarActor_Direct());
}

const URPGAttributeSet* URPGAbilitySystemComponent::GetRPGAttributes() const
{
	return GetSet<URPGAttributeSet>();
}

void URPGAbilitySystemComponent::InitVitals(float InMaxHealth, float InHealthRegen, const FRPGResourceConfig& InResource)
{
	HealthRegen = InHealthRegen;
	ResourceConfig = InResource;

	if (GetOwner() && GetOwner()->HasAuthority())
	{
		SetNumericAttributeBase(URPGAttributeSet::GetMaxHealthAttribute(), FMath::Max(1.f, InMaxHealth));
		SetNumericAttributeBase(URPGAttributeSet::GetMaxResourceAttribute(), FMath::Max(0.f, InResource.Max));
		RestoreAll();
	}
}

void URPGAbilitySystemComponent::GrantSlotAbilities(const TArray<TSubclassOf<URPGGameplayAbility>>& AbilityClasses)
{
	if (!GetOwner() || !GetOwner()->HasAuthority())
	{
		return;
	}

	for (int32 Slot = 0; Slot < AbilityClasses.Num(); ++Slot)
	{
		if (AbilityClasses[Slot])
		{
			GiveAbility(FGameplayAbilitySpec(AbilityClasses[Slot], 1, Slot, GetOwner()));
		}
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Hotbar

FGameplayAbilitySpec* URPGAbilitySystemComponent::FindSlotSpec(int32 Slot) const
{
	return Slot >= 0 && Slot < NumSlots ? FindAbilitySpecFromInputID(Slot) : nullptr;
}

const URPGGameplayAbility* URPGAbilitySystemComponent::GetSlotAbility(int32 Slot) const
{
	const FGameplayAbilitySpec* Spec = FindSlotSpec(Slot);
	if (!Spec)
	{
		return nullptr;
	}
	if (const UGameplayAbility* Instance = Spec->GetPrimaryInstance())
	{
		return Cast<URPGGameplayAbility>(Instance);
	}
	return Cast<URPGGameplayAbility>(Spec->Ability);
}

ERPGCastResult URPGAbilitySystemComponent::CanActivateSlot(int32 Slot) const
{
	const FGameplayAbilitySpec* Spec = FindSlotSpec(Slot);
	const URPGGameplayAbility* Ability = GetSlotAbility(Slot);
	const ARPGCharacterBase* Character = GetCharacter();
	const FGameplayAbilityActorInfo* ActorInfo = AbilityActorInfo.Get();
	if (!Spec || !Ability || !Character || !ActorInfo)
	{
		return ERPGCastResult::InvalidSlot;
	}
	if (!Character->IsAlive())
	{
		return ERPGCastResult::Dead;
	}
	if (Character->IsIncapacitated() && !Ability->IsUsableWhileIncapacitated())
	{
		return ERPGCastResult::Incapacitated;
	}
	if (HasMatchingGameplayTag(RPGTags::State_Casting) || Spec->IsActive())
	{
		return ERPGCastResult::Busy;
	}
	if (!Ability->CheckCooldown(Spec->Handle, ActorInfo))
	{
		return ERPGCastResult::Cooldown;
	}
	if (!Ability->CheckCost(Spec->Handle, ActorInfo))
	{
		return ERPGCastResult::NotEnoughResource;
	}

	const ERPGCastResult CasterResult = Ability->CheckCasterState(*Character);
	if (CasterResult != ERPGCastResult::Success)
	{
		return CasterResult;
	}

	// Targeted abilities need a soft-locked enemy under the crosshair (only the controlling machine can tell).
	if (Ability->RequiresTarget())
	{
		FVector AimLocation;
		ARPGCharacterBase* Target = nullptr;
		Character->ComputeAim(Ability->GetRange(), AimLocation, Target);
		if (!Target)
		{
			return ERPGCastResult::NoTarget;
		}
		return Ability->CheckTarget(*Character, *Target);
	}
	return ERPGCastResult::Success;
}

ERPGCastResult URPGAbilitySystemComponent::TryActivateSlot(int32 Slot)
{
	const ERPGCastResult Result = CanActivateSlot(Slot);
	if (Result != ERPGCastResult::Success)
	{
		return Result;
	}
	return TryActivateAbility(FindSlotSpec(Slot)->Handle) ? ERPGCastResult::Success : ERPGCastResult::Blocked;
}

float URPGAbilitySystemComponent::GetSlotCooldownRemaining(int32 Slot, float& OutDuration) const
{
	OutDuration = 0.f;
	const FGameplayAbilitySpec* Spec = FindSlotSpec(Slot);
	const URPGGameplayAbility* Ability = GetSlotAbility(Slot);
	if (!Spec || !Ability || !AbilityActorInfo.IsValid())
	{
		return 0.f;
	}

	float Remaining = 0.f;
	Ability->GetCooldownTimeRemainingAndDuration(Spec->Handle, AbilityActorInfo.Get(), Remaining, OutDuration);
	return Remaining;
}

void URPGAbilitySystemComponent::ResetCooldowns()
{
	RemoveActiveEffectsWithGrantedTags(FGameplayTagContainer(RPGTags::Cooldown));
}

// ---------------------------------------------------------------------------------------------------------------------
// Vitals

void URPGAbilitySystemComponent::RestoreAll()
{
	const URPGAttributeSet* Attributes = GetRPGAttributes();
	if (!Attributes || !GetOwner()->HasAuthority())
	{
		return;
	}

	RemoveStatuses(FGameplayTagContainer(RPGTags::Status));
	SetNumericAttributeBase(URPGAttributeSet::GetHealthAttribute(), Attributes->GetMaxHealth());
	SetNumericAttributeBase(URPGAttributeSet::GetResourceAttribute(), ResourceConfig.bStartsFull ? Attributes->GetMaxResource() : 0.f);
	SetNumericAttributeBase(URPGAttributeSet::GetShieldAttribute(), 0.f);
	Diminishing.Reset();
	BreakDamageTaken.Reset();
}

void URPGAbilitySystemComponent::AddResource(float Amount)
{
	const URPGAttributeSet* Attributes = GetRPGAttributes();
	if (Attributes && Amount != 0.f && GetOwner()->HasAuthority())
	{
		SetNumericAttributeBase(URPGAttributeSet::GetResourceAttribute(), Attributes->GetResource() + Amount);
	}
}

void URPGAbilitySystemComponent::AddShield(float Amount, float Duration)
{
	const URPGAttributeSet* Attributes = GetRPGAttributes();
	if (!Attributes || Amount <= 0.f || !GetOwner()->HasAuthority())
	{
		return;
	}

	// The barrier status times the shield; replacing it clears the old amount, so read it first.
	const float Current = HasMatchingGameplayTag(RPGTags::Status_Barrier) ? Attributes->GetShield() : 0.f;
	if (ApplyStatus(FRPGStatusSpec(RPGTags::Status_Barrier, Duration), GetOwner()))
	{
		SetNumericAttributeBase(URPGAttributeSet::GetShieldAttribute(), FMath::Max(Current, Amount));
	}
}

bool URPGAbilitySystemComponent::IsInCombat() const
{
	const UWorld* World = GetWorld();
	return World && World->GetTimeSeconds() - LastCombatTime < OutOfCombatDelay;
}

bool URPGAbilitySystemComponent::WasDamagedWithin(float Seconds) const
{
	const UWorld* World = GetWorld();
	return World && World->GetTimeSeconds() - LastDamagedTime < Seconds;
}

void URPGAbilitySystemComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	const ARPGCharacterBase* Character = GetCharacter();
	const URPGAttributeSet* Attributes = GetRPGAttributes();
	if (!GetOwner() || !GetOwner()->HasAuthority() || !Character || !Character->IsAlive() || !Attributes)
	{
		return;
	}

	RegenAccumulator += DeltaTime;
	if (RegenAccumulator < RPGAbilitySystemPrivate::RegenInterval)
	{
		return;
	}
	const float Step = RegenAccumulator;
	RegenAccumulator = 0.f;

	if (HealthRegen > 0.f && !WasDamagedWithin(OutOfCombatDelay) && Attributes->GetHealth() < Attributes->GetMaxHealth())
	{
		SetNumericAttributeBase(URPGAttributeSet::GetHealthAttribute(), Attributes->GetHealth() + HealthRegen * Step);
	}

	float ResourceDelta = ResourceConfig.RegenPerSecond * Step;
	if (!IsInCombat())
	{
		ResourceDelta -= ResourceConfig.OutOfCombatDecayPerSecond * Step;
	}
	if (ResourceDelta != 0.f)
	{
		const float NewResource = FMath::Clamp(Attributes->GetResource() + ResourceDelta, 0.f, Attributes->GetMaxResource());
		if (NewResource != Attributes->GetResource())
		{
			SetNumericAttributeBase(URPGAttributeSet::GetResourceAttribute(), NewResource);
		}
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Statuses

float URPGAbilitySystemComponent::ScaleCrowdControlDuration(const FGameplayTag& Category, float Duration)
{
	using namespace RPGAbilitySystemPrivate;

	const double Now = GetWorld()->GetTimeSeconds();
	FDiminishingState& State = Diminishing.FindOrAdd(Category);
	if (Now >= State.ResetTime)
	{
		State.Level = 0;
	}

	const float Factor = State.Level < UE_ARRAY_COUNT(DiminishingFactors) ? DiminishingFactors[State.Level] : 0.f;
	State.Level = FMath::Min(State.Level + 1, static_cast<int32>(UE_ARRAY_COUNT(DiminishingFactors)));
	State.ResetTime = Now + DiminishingResetSeconds;
	return Duration * Factor;
}

bool URPGAbilitySystemComponent::ApplyStatus(const FRPGStatusSpec& Status, AActor* SourceActor, AActor* Causer)
{
	ARPGCharacterBase* Character = GetCharacter();
	const FRPGStatusDefinition* Definition = RPGStatusEffects::Find(Status.Status);
	if (!Definition)
	{
		UE_LOG(LogRPG, Warning, TEXT("ApplyStatus: '%s' has no definition in RPGStatusEffects."), *Status.Status.ToString());
		return false;
	}
	if (!Character || !Character->IsAlive() || !GetOwner()->HasAuthority())
	{
		return false;
	}

	if (HasAnyMatchingGameplayTags(Definition->BlockedBy))
	{
		Character->ShowCombatText(LOCTEXT("Immune", "IMMUNE"), RPGAbilitySystemPrivate::ImmuneColor);
		return false;
	}

	float Duration = Status.Duration;
	if (Definition->DiminishingCategory.IsValid() && Duration > 0.f)
	{
		Duration = ScaleCrowdControlDuration(Definition->DiminishingCategory, Duration);
		if (Duration <= 0.f)
		{
			Character->ShowCombatText(LOCTEXT("Immune", "IMMUNE"), RPGAbilitySystemPrivate::ImmuneColor);
			return false;
		}
	}

	if (Definition->bReplaceExisting)
	{
		RemoveActiveEffectsWithGrantedTags(FGameplayTagContainer(Definition->Tag));
	}
	BreakDamageTaken.Remove(Definition->Tag);

	TSubclassOf<UGameplayEffect> EffectClass = URPGEffect_Infinite::StaticClass();
	if (Definition->DamageOverTimeType.IsValid())
	{
		EffectClass = URPGEffect_DamageOverTime::StaticClass();
		Duration = FMath::Max(Duration, URPGEffect_DamageOverTime::TickInterval);
	}
	else if (Duration > 0.f)
	{
		EffectClass = URPGEffect_Timed::StaticClass();
	}

	// Effects are made by the source so they carry its identity (kill credit, frontal block direction...).
	UAbilitySystemComponent* SourceASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(SourceActor);
	if (!SourceASC)
	{
		SourceASC = this;
	}

	FGameplayEffectContextHandle Context = SourceASC->MakeEffectContext();
	Context.AddInstigator(SourceActor, Causer ? Causer : SourceActor);
	const FGameplayEffectSpecHandle SpecHandle = SourceASC->MakeOutgoingSpec(EffectClass, 1.f, Context);
	if (!SpecHandle.IsValid())
	{
		return false;
	}

	FGameplayEffectSpec& Spec = *SpecHandle.Data;
	Spec.SetSetByCallerMagnitude(RPGTags::Data_Duration, Duration);
	Spec.SetSetByCallerMagnitude(RPGTags::Data_Magnitude, Status.Magnitude);
	Spec.DynamicGrantedTags.AddTag(Definition->Tag);
	if (Definition->DamageOverTimeType.IsValid())
	{
		Spec.SetSetByCallerMagnitude(RPGTags::Data_Damage, Status.Magnitude * URPGEffect_DamageOverTime::TickInterval);
		Spec.AddDynamicAssetTag(Definition->DamageOverTimeType);
	}

	SourceASC->ApplyGameplayEffectSpecToTarget(Spec, this);
	return true;
}

void URPGAbilitySystemComponent::RemoveStatuses(const FGameplayTagContainer& Tags)
{
	if (GetOwner() && GetOwner()->HasAuthority() && !Tags.IsEmpty())
	{
		RemoveActiveEffectsWithGrantedTags(Tags);
	}
}

float URPGAbilitySystemComponent::GetStatusMagnitude(const FGameplayTag& Tag, ERPGMagnitudeAggregation Aggregation, float Default) const
{
	if (!HasMatchingGameplayTag(Tag))
	{
		return Default;
	}

	bool bFound = false;
	float Result = Default;
	for (const FActiveGameplayEffectHandle& Handle : GetActiveEffects(FGameplayEffectQuery::MakeQuery_MatchAnyOwningTags(FGameplayTagContainer(Tag))))
	{
		const FActiveGameplayEffect* Effect = GetActiveGameplayEffect(Handle);
		if (!Effect)
		{
			continue;
		}

		const float Magnitude = Effect->Spec.GetSetByCallerMagnitude(RPGTags::Data_Magnitude, false, Default);
		if (!bFound)
		{
			Result = Magnitude;
			bFound = true;
		}
		else
		{
			Result = Aggregation == ERPGMagnitudeAggregation::Lowest ? FMath::Min(Result, Magnitude) : FMath::Max(Result, Magnitude);
		}
	}
	return Result;
}

float URPGAbilitySystemComponent::GetStatusTimeRemaining(const FGameplayTag& Tag) const
{
	float Longest = 0.f;
	for (const TPair<float, float>& Entry : GetActiveEffectsTimeRemainingAndDuration(FGameplayEffectQuery::MakeQuery_MatchAnyOwningTags(FGameplayTagContainer(Tag))))
	{
		Longest = FMath::Max(Longest, Entry.Key);
	}
	return Longest;
}

float URPGAbilitySystemComponent::GetMoveSpeedMultiplier() const
{
	using namespace RPGTags;

	if (HasMatchingGameplayTag(Status_Root))
	{
		return 0.f;
	}

	float Multiplier = 1.f;
	if (!HasMatchingGameplayTag(Status_Immune_Slow) && !HasMatchingGameplayTag(Status_Immune_CC))
	{
		Multiplier *= FMath::Clamp(GetStatusMagnitude(Status_Slow, ERPGMagnitudeAggregation::Lowest, 1.f), 0.05f, 1.f);
	}
	Multiplier *= FMath::Clamp(GetStatusMagnitude(Status_Stealth, ERPGMagnitudeAggregation::Lowest, 1.f), 0.05f, 1.f);
	Multiplier *= FMath::Max(1.f, GetStatusMagnitude(Status_Haste, ERPGMagnitudeAggregation::Highest, 1.f));
	return Multiplier;
}

float URPGAbilitySystemComponent::GetHealingMultiplier() const
{
	return FMath::Clamp(GetStatusMagnitude(RPGTags::Status_HealingReduced, ERPGMagnitudeAggregation::Lowest, 1.f), 0.f, 1.f);
}

void URPGAbilitySystemComponent::OnIncapacitatedChanged(const FGameplayTag Tag, int32 NewCount)
{
	ARPGCharacterBase* Character = GetCharacter();
	if (!Character)
	{
		return;
	}

	if (NewCount > 0 && GetOwner()->HasAuthority())
	{
		// Interrupt casts and channels; abilities meant to break crowd control keep going.
		for (const FGameplayAbilitySpec& Spec : GetActivatableAbilities())
		{
			const URPGGameplayAbility* Ability = Cast<URPGGameplayAbility>(Spec.Ability);
			if (Spec.IsActive() && Ability && !Ability->IsUsableWhileIncapacitated())
			{
				CancelAbilityHandle(Spec.Handle);
			}
		}
	}

	Character->OnIncapacitatedChanged(NewCount > 0);
}

void URPGAbilitySystemComponent::OnBarrierChanged(const FGameplayTag Tag, int32 NewCount)
{
	if (NewCount == 0 && GetOwner() && GetOwner()->HasAuthority())
	{
		SetNumericAttributeBase(URPGAttributeSet::GetShieldAttribute(), 0.f);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Damage pipeline

void URPGAbilitySystemComponent::HandleIncomingDamage(float Amount, const FGameplayEffectSpec& Spec)
{
	ARPGCharacterBase* Character = GetCharacter();
	const URPGAttributeSet* Attributes = GetRPGAttributes();
	if (!Character || !Attributes || !Character->IsAlive())
	{
		return;
	}

	const FGameplayEffectContextHandle& Context = Spec.GetContext();
	AActor* InstigatorActor = Context.GetInstigator();

	if (Amount <= 0.f)
	{
		if (HasMatchingGameplayTag(RPGTags::Status_DivineShield))
		{
			Character->ShowCombatText(LOCTEXT("Immune", "IMMUNE"), RPGAbilitySystemPrivate::ImmuneColor);
		}
		return;
	}

	FGameplayTag DamageType = RPGTags::Damage_Physical;
	FGameplayTagContainer AssetTags;
	Spec.GetAllAssetTags(AssetTags);
	for (const FGameplayTag& Tag : AssetTags)
	{
		if (Tag.MatchesTag(RPGTags::Damage))
		{
			DamageType = Tag;
			break;
		}
	}

	const double Now = GetWorld()->GetTimeSeconds();
	LastDamagedTime = Now;
	LastCombatTime = Now;

	// Shield first.
	const float Absorbed = FMath::Min(Attributes->GetShield(), Amount);
	if (Absorbed > 0.f)
	{
		SetNumericAttributeBase(URPGAttributeSet::GetShieldAttribute(), Attributes->GetShield() - Absorbed);
		if (Attributes->GetShield() <= 0.f)
		{
			RemoveActiveEffectsWithGrantedTags(FGameplayTagContainer(RPGTags::Status_Barrier));
		}
	}

	const float OldHealth = Attributes->GetHealth();
	const float MinHealth = bInvulnerable ? 1.f : 0.f;
	const float NewHealth = FMath::Max(MinHealth, OldHealth - (Amount - Absorbed));
	SetNumericAttributeBase(URPGAttributeSet::GetHealthAttribute(), NewHealth);
	const float HealthDamage = OldHealth - NewHealth;
	UE_LOG(LogRPG, Verbose, TEXT("%s takes %.1f %s damage from %s (%.1f absorbed)"), *Character->GetName(), Amount, *DamageType.ToString(), InstigatorActor ? *InstigatorActor->GetName() : TEXT("?"), Absorbed);

	// Statuses that end on damage (stealth at once, fear after enough of it).
	for (const FRPGStatusDefinition& Definition : RPGStatusEffects::GetDefinitions())
	{
		if (Definition.BreakDamageFraction < 0.f || !HasMatchingGameplayTag(Definition.Tag))
		{
			continue;
		}

		float& Taken = BreakDamageTaken.FindOrAdd(Definition.Tag);
		Taken += Amount;
		if (Taken >= Definition.BreakDamageFraction * Attributes->GetMaxHealth())
		{
			RemoveActiveEffectsWithGrantedTags(FGameplayTagContainer(Definition.Tag));
			BreakDamageTaken.Remove(Definition.Tag);
		}
	}

	AddResource(Amount * ResourceConfig.GainPerDamageTaken);
	if (URPGAbilitySystemComponent* SourceASC = Cast<URPGAbilitySystemComponent>(Context.GetInstigatorAbilitySystemComponent()); SourceASC && SourceASC != this)
	{
		SourceASC->NotifyDamageDealt(Amount);
	}

	Character->NotifyDamageTaken(HealthDamage, Absorbed, InstigatorActor, DamageType);

	if (NewHealth <= 0.f)
	{
		Character->NotifyKilled(InstigatorActor);
	}
}

void URPGAbilitySystemComponent::HandleIncomingHealing(float Amount, const FGameplayEffectSpec& Spec)
{
	ARPGCharacterBase* Character = GetCharacter();
	const URPGAttributeSet* Attributes = GetRPGAttributes();
	if (!Character || !Attributes || !Character->IsAlive() || Amount <= 0.f)
	{
		return;
	}

	const float OldHealth = Attributes->GetHealth();
	const float NewHealth = FMath::Min(Attributes->GetMaxHealth(), OldHealth + Amount * GetHealingMultiplier());
	SetNumericAttributeBase(URPGAttributeSet::GetHealthAttribute(), NewHealth);
	Character->NotifyHealed(NewHealth - OldHealth);
}

void URPGAbilitySystemComponent::NotifyDamageDealt(float Amount)
{
	LastCombatTime = GetWorld()->GetTimeSeconds();
	AddResource(Amount * ResourceConfig.GainPerDamageDealt);
}

#undef LOCTEXT_NAMESPACE
