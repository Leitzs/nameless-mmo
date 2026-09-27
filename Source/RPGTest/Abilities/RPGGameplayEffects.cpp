#include "Abilities/RPGGameplayEffects.h"

#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGAttributeSet.h"
#include "Abilities/RPGGameplayTags.h"
#include "GameFramework/Actor.h"

namespace
{
	FGameplayModifierInfo MakeSetByCallerModifier(const FGameplayAttribute& Attribute, const FGameplayTag& DataTag)
	{
		FSetByCallerFloat SetByCaller;
		SetByCaller.DataTag = DataTag;

		FGameplayModifierInfo Modifier;
		Modifier.Attribute = Attribute;
		Modifier.ModifierOp = EGameplayModOp::AddBase;
		Modifier.ModifierMagnitude = FGameplayEffectModifierMagnitude(SetByCaller);
		return Modifier;
	}

	FGameplayEffectModifierMagnitude MakeSetByCallerDuration()
	{
		FSetByCallerFloat SetByCaller;
		SetByCaller.DataTag = RPGTags::Data_Duration;
		return FGameplayEffectModifierMagnitude(SetByCaller);
	}
}

URPGEffect_Damage::URPGEffect_Damage()
{
	DurationPolicy = EGameplayEffectDurationType::Instant;

	FGameplayEffectExecutionDefinition Execution;
	Execution.CalculationClass = URPGDamageExecution::StaticClass();
	Executions.Add(Execution);
}

URPGEffect_Heal::URPGEffect_Heal()
{
	DurationPolicy = EGameplayEffectDurationType::Instant;
	Modifiers.Add(MakeSetByCallerModifier(URPGAttributeSet::GetIncomingHealingAttribute(), RPGTags::Data_Heal));
}

URPGEffect_Cost::URPGEffect_Cost()
{
	DurationPolicy = EGameplayEffectDurationType::Instant;
	Modifiers.Add(MakeSetByCallerModifier(URPGAttributeSet::GetResourceAttribute(), RPGTags::Data_Cost));
}

URPGEffect_Timed::URPGEffect_Timed()
{
	DurationPolicy = EGameplayEffectDurationType::HasDuration;
	DurationMagnitude = MakeSetByCallerDuration();
}

URPGEffect_Infinite::URPGEffect_Infinite()
{
	DurationPolicy = EGameplayEffectDurationType::Infinite;
}

URPGEffect_DamageOverTime::URPGEffect_DamageOverTime()
{
	DurationPolicy = EGameplayEffectDurationType::HasDuration;
	DurationMagnitude = MakeSetByCallerDuration();
	Period = FScalableFloat(TickInterval);
	bExecutePeriodicEffectOnApplication = false;

	FGameplayEffectExecutionDefinition Execution;
	Execution.CalculationClass = URPGDamageExecution::StaticClass();
	Executions.Add(Execution);
}

void URPGDamageExecution::Execute_Implementation(const FGameplayEffectCustomExecutionParameters& ExecutionParams, FGameplayEffectCustomExecutionOutput& OutExecutionOutput) const
{
	const FGameplayEffectSpec& Spec = ExecutionParams.GetOwningSpec();
	float Damage = FMath::Max(0.f, Spec.GetSetByCallerMagnitude(RPGTags::Data_Damage, false, 0.f));

	const URPGAbilitySystemComponent* SourceASC = Cast<URPGAbilitySystemComponent>(ExecutionParams.GetSourceAbilitySystemComponent());
	const URPGAbilitySystemComponent* TargetASC = Cast<URPGAbilitySystemComponent>(ExecutionParams.GetTargetAbilitySystemComponent());

	// Divine Shield: immune to damage, but its own attacks are weakened.
	if (TargetASC && TargetASC->HasMatchingGameplayTag(RPGTags::Status_DivineShield))
	{
		Damage = 0.f;
	}
	if (SourceASC)
	{
		Damage *= SourceASC->GetStatusMagnitude(RPGTags::Status_DivineShield, ERPGMagnitudeAggregation::Lowest, 1.f);
	}

	// Shield bearers block part of the damage of direct attacks coming from their front.
	const AActor* SourceActor = Spec.GetContext().GetInstigator();
	const AActor* TargetActor = TargetASC ? TargetASC->GetAvatarActor() : nullptr;
	const bool bPeriodic = Spec.GetPeriod() > 0.f;
	if (!bPeriodic && TargetASC && TargetASC->HasMatchingGameplayTag(RPGTags::Trait_FrontalBlock) && SourceActor && TargetActor && SourceActor != TargetActor)
	{
		const FVector ToSource = (SourceActor->GetActorLocation() - TargetActor->GetActorLocation()).GetSafeNormal2D();
		if (FVector::DotProduct(TargetActor->GetActorForwardVector().GetSafeNormal2D(), ToSource) > 0.2f)
		{
			Damage *= FrontalBlockMultiplier;
		}
	}

	OutExecutionOutput.AddOutputModifier(FGameplayModifierEvaluatedData(URPGAttributeSet::GetIncomingDamageAttribute(), EGameplayModOp::AddBase, Damage));
}
