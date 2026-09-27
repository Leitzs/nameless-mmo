#pragma once

#include "CoreMinimal.h"
#include "AttributeSet.h"
#include "AbilitySystemComponent.h"
#include "RPGAttributeSet.generated.h"

/**
 * Attributes of every combatant: health, the class resource (mana, energy or rage, see FRPGResourceConfig),
 * and a damage-absorbing shield. IncomingDamage and IncomingHealing are meta attributes: effects write to them and
 * URPGAbilitySystemComponent turns them into health changes (shield absorption, death, combat text, rage...).
 * Health, MaxHealth and Shield replicate to everyone (health bars); the resource only to the owning player.
 */
UCLASS()
class RPGTEST_API URPGAttributeSet : public UAttributeSet
{
	GENERATED_BODY()

public:
	URPGAttributeSet();

	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual void PreAttributeBaseChange(const FGameplayAttribute& Attribute, float& NewValue) const override;
	virtual void PreAttributeChange(const FGameplayAttribute& Attribute, float& NewValue) override;
	virtual void PostGameplayEffectExecute(const FGameplayEffectModCallbackData& Data) override;

	ATTRIBUTE_ACCESSORS_BASIC(URPGAttributeSet, Health);
	ATTRIBUTE_ACCESSORS_BASIC(URPGAttributeSet, MaxHealth);
	ATTRIBUTE_ACCESSORS_BASIC(URPGAttributeSet, Resource);
	ATTRIBUTE_ACCESSORS_BASIC(URPGAttributeSet, MaxResource);
	ATTRIBUTE_ACCESSORS_BASIC(URPGAttributeSet, Shield);
	ATTRIBUTE_ACCESSORS_BASIC(URPGAttributeSet, IncomingDamage);
	ATTRIBUTE_ACCESSORS_BASIC(URPGAttributeSet, IncomingHealing);

private:
	/** Keeps a value inside its [0, max] range. */
	void ClampAttribute(const FGameplayAttribute& Attribute, float& NewValue) const;

	UFUNCTION()
	void OnRep_Health(const FGameplayAttributeData& OldValue);

	UFUNCTION()
	void OnRep_MaxHealth(const FGameplayAttributeData& OldValue);

	UFUNCTION()
	void OnRep_Resource(const FGameplayAttributeData& OldValue);

	UFUNCTION()
	void OnRep_MaxResource(const FGameplayAttributeData& OldValue);

	UFUNCTION()
	void OnRep_Shield(const FGameplayAttributeData& OldValue);

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Health, Category = "Attributes", meta = (AllowPrivateAccess = true))
	FGameplayAttributeData Health;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxHealth, Category = "Attributes", meta = (AllowPrivateAccess = true))
	FGameplayAttributeData MaxHealth;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Resource, Category = "Attributes", meta = (AllowPrivateAccess = true))
	FGameplayAttributeData Resource;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_MaxResource, Category = "Attributes", meta = (AllowPrivateAccess = true))
	FGameplayAttributeData MaxResource;

	UPROPERTY(BlueprintReadOnly, ReplicatedUsing = OnRep_Shield, Category = "Attributes", meta = (AllowPrivateAccess = true))
	FGameplayAttributeData Shield;

	/** Meta attribute (server only, never replicated): damage about to be applied. */
	UPROPERTY(BlueprintReadOnly, Category = "Attributes", meta = (AllowPrivateAccess = true))
	FGameplayAttributeData IncomingDamage;

	/** Meta attribute (server only, never replicated): healing about to be applied. */
	UPROPERTY(BlueprintReadOnly, Category = "Attributes", meta = (AllowPrivateAccess = true))
	FGameplayAttributeData IncomingHealing;
};
