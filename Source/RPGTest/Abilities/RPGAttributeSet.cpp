#include "Abilities/RPGAttributeSet.h"

#include "Abilities/RPGAbilitySystemComponent.h"
#include "GameplayEffectExtension.h"
#include "Net/UnrealNetwork.h"

URPGAttributeSet::URPGAttributeSet()
{
	InitHealth(100.f);
	InitMaxHealth(100.f);
	InitResource(0.f);
	InitMaxResource(0.f);
	InitShield(0.f);
	InitIncomingDamage(0.f);
	InitIncomingHealing(0.f);
}

void URPGAttributeSet::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);

	DOREPLIFETIME_CONDITION_NOTIFY(URPGAttributeSet, Health, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(URPGAttributeSet, MaxHealth, COND_None, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(URPGAttributeSet, Shield, COND_None, REPNOTIFY_Always);

	// Only the HUD of the owning player shows the resource.
	DOREPLIFETIME_CONDITION_NOTIFY(URPGAttributeSet, Resource, COND_OwnerOnly, REPNOTIFY_Always);
	DOREPLIFETIME_CONDITION_NOTIFY(URPGAttributeSet, MaxResource, COND_OwnerOnly, REPNOTIFY_Always);
}

void URPGAttributeSet::ClampAttribute(const FGameplayAttribute& Attribute, float& NewValue) const
{
	if (Attribute == GetHealthAttribute())
	{
		NewValue = FMath::Clamp(NewValue, 0.f, GetMaxHealth());
	}
	else if (Attribute == GetResourceAttribute())
	{
		NewValue = FMath::Clamp(NewValue, 0.f, GetMaxResource());
	}
	else if (Attribute == GetShieldAttribute() || Attribute == GetMaxResourceAttribute())
	{
		NewValue = FMath::Max(0.f, NewValue);
	}
	else if (Attribute == GetMaxHealthAttribute())
	{
		NewValue = FMath::Max(1.f, NewValue);
	}
}

void URPGAttributeSet::PreAttributeBaseChange(const FGameplayAttribute& Attribute, float& NewValue) const
{
	Super::PreAttributeBaseChange(Attribute, NewValue);
	ClampAttribute(Attribute, NewValue);
}

void URPGAttributeSet::PreAttributeChange(const FGameplayAttribute& Attribute, float& NewValue)
{
	Super::PreAttributeChange(Attribute, NewValue);
	ClampAttribute(Attribute, NewValue);
}

void URPGAttributeSet::PostGameplayEffectExecute(const FGameplayEffectModCallbackData& Data)
{
	Super::PostGameplayEffectExecute(Data);

	URPGAbilitySystemComponent* RPGAbilitySystem = Cast<URPGAbilitySystemComponent>(GetOwningAbilitySystemComponent());
	if (!RPGAbilitySystem)
	{
		return;
	}

	if (Data.EvaluatedData.Attribute == GetIncomingDamageAttribute())
	{
		const float Amount = GetIncomingDamage();
		SetIncomingDamage(0.f);
		RPGAbilitySystem->HandleIncomingDamage(Amount, Data.EffectSpec);
	}
	else if (Data.EvaluatedData.Attribute == GetIncomingHealingAttribute())
	{
		const float Amount = GetIncomingHealing();
		SetIncomingHealing(0.f);
		RPGAbilitySystem->HandleIncomingHealing(Amount, Data.EffectSpec);
	}
}

void URPGAttributeSet::OnRep_Health(const FGameplayAttributeData& OldValue)
{
	GAMEPLAYATTRIBUTE_REPNOTIFY(URPGAttributeSet, Health, OldValue);
}

void URPGAttributeSet::OnRep_MaxHealth(const FGameplayAttributeData& OldValue)
{
	GAMEPLAYATTRIBUTE_REPNOTIFY(URPGAttributeSet, MaxHealth, OldValue);
}

void URPGAttributeSet::OnRep_Resource(const FGameplayAttributeData& OldValue)
{
	GAMEPLAYATTRIBUTE_REPNOTIFY(URPGAttributeSet, Resource, OldValue);
}

void URPGAttributeSet::OnRep_MaxResource(const FGameplayAttributeData& OldValue)
{
	GAMEPLAYATTRIBUTE_REPNOTIFY(URPGAttributeSet, MaxResource, OldValue);
}

void URPGAttributeSet::OnRep_Shield(const FGameplayAttributeData& OldValue)
{
	GAMEPLAYATTRIBUTE_REPNOTIFY(URPGAttributeSet, Shield, OldValue);
}
