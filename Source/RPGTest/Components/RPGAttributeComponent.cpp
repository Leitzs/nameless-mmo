#include "Components/RPGAttributeComponent.h"

#include "Engine/World.h"

URPGAttributeComponent::URPGAttributeComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	PrimaryComponentTick.TickInterval = 0.1f;
}

void URPGAttributeComponent::SetDefaults(float InMaxHealth, float InMaxMana, float InHealthRegen, float InManaRegen)
{
	MaxHealth = FMath::Max(1.f, InMaxHealth);
	MaxMana = FMath::Max(0.f, InMaxMana);
	HealthRegen = InHealthRegen;
	ManaRegen = InManaRegen;
}

void URPGAttributeComponent::BeginPlay()
{
	Super::BeginPlay();
	RestoreAll();
}

void URPGAttributeComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	if (!IsAlive())
	{
		return;
	}

	Mana = FMath::Min(MaxMana, Mana + ManaRegen * DeltaTime);

	if (!IsInCombat())
	{
		Health = FMath::Min(MaxHealth, Health + HealthRegen * DeltaTime);
	}

	if (ShieldTimeRemaining > 0.f)
	{
		ShieldTimeRemaining -= DeltaTime;
		if (ShieldTimeRemaining <= 0.f)
		{
			Shield = 0.f;
			ShieldTimeRemaining = 0.f;
		}
	}
}

float URPGAttributeComponent::ApplyDamage(float Amount, AActor* InstigatorActor)
{
	if (Amount <= 0.f || !IsAlive())
	{
		return 0.f;
	}

	LastDamageTime = GetWorld()->GetTimeSeconds();

	const float Absorbed = FMath::Min(Shield, Amount);
	Shield -= Absorbed;
	if (Shield <= 0.f)
	{
		ShieldTimeRemaining = 0.f;
	}

	const float Remaining = Amount - Absorbed;
	const float MinHealth = bInvulnerable ? 1.f : 0.f;
	const float NewHealth = FMath::Max(MinHealth, Health - Remaining);
	const float HealthDamage = Health - NewHealth;
	Health = NewHealth;

	OnDamaged.Broadcast(this, HealthDamage, Absorbed, InstigatorActor);

	if (!IsAlive())
	{
		Shield = 0.f;
		OnDeath.Broadcast(InstigatorActor);
	}

	return HealthDamage;
}

void URPGAttributeComponent::Heal(float Amount)
{
	if (IsAlive() && Amount > 0.f)
	{
		Health = FMath::Min(MaxHealth, Health + Amount);
	}
}

bool URPGAttributeComponent::TryConsumeMana(float Amount)
{
	if (Mana + KINDA_SMALL_NUMBER < Amount)
	{
		return false;
	}

	Mana = FMath::Max(0.f, Mana - Amount);
	return true;
}

void URPGAttributeComponent::AddShield(float Amount, float Duration)
{
	Shield = FMath::Max(Shield, Amount);
	ShieldTimeRemaining = FMath::Max(ShieldTimeRemaining, Duration);
}

void URPGAttributeComponent::RestoreAll()
{
	Health = MaxHealth;
	Mana = MaxMana;
	Shield = 0.f;
	ShieldTimeRemaining = 0.f;
}

bool URPGAttributeComponent::IsInCombat() const
{
	const UWorld* World = GetWorld();
	return World && World->GetTimeSeconds() - LastDamageTime < OutOfCombatDelay;
}
