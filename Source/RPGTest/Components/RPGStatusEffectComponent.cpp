#include "Components/RPGStatusEffectComponent.h"

#include "Combat/RPGDamageTypes.h"
#include "GameFramework/Controller.h"
#include "Kismet/GameplayStatics.h"

namespace
{
	constexpr float BurnTickInterval = 0.5f;
}

URPGStatusEffectComponent::URPGStatusEffectComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
}

void URPGStatusEffectComponent::ApplySlow(float SpeedMultiplier, float Duration)
{
	const bool bWasSlowed = IsSlowed();
	SlowMultiplier = bWasSlowed ? FMath::Min(SlowMultiplier, SpeedMultiplier) : SpeedMultiplier;
	SlowMultiplier = FMath::Clamp(SlowMultiplier, 0.05f, 1.f);
	SlowRemaining = FMath::Max(SlowRemaining, Duration);
	if (!bWasSlowed)
	{
		OnStatusChanged.Broadcast();
	}
}

void URPGStatusEffectComponent::ApplyFreeze(float Duration)
{
	const bool bWasFrozen = IsFrozen();
	FreezeRemaining = FMath::Max(FreezeRemaining, Duration);
	if (!bWasFrozen)
	{
		OnStatusChanged.Broadcast();
	}
}

void URPGStatusEffectComponent::ApplyStun(float Duration)
{
	const bool bWasStunned = IsStunned();
	StunRemaining = FMath::Max(StunRemaining, Duration);
	if (!bWasStunned)
	{
		OnStatusChanged.Broadcast();
	}
}

void URPGStatusEffectComponent::ApplyBurn(float DamagePerSecond, float Duration, AController* InstigatorController, AActor* DamageCauser)
{
	const bool bWasBurning = IsBurning();
	BurnDamagePerSecond = FMath::Max(DamagePerSecond, bWasBurning ? BurnDamagePerSecond : 0.f);
	BurnRemaining = FMath::Max(BurnRemaining, Duration);
	BurnInstigator = InstigatorController;
	BurnCauser = DamageCauser;
	if (!bWasBurning)
	{
		BurnTickAccumulator = 0.f;
		OnStatusChanged.Broadcast();
	}
}

void URPGStatusEffectComponent::ClearAll()
{
	SlowRemaining = FreezeRemaining = StunRemaining = BurnRemaining = 0.f;
	SlowMultiplier = 1.f;
	OnStatusChanged.Broadcast();
}

float URPGStatusEffectComponent::GetSpeedMultiplier() const
{
	if (IsIncapacitated())
	{
		return 0.f;
	}
	return IsSlowed() ? SlowMultiplier : 1.f;
}

bool URPGStatusEffectComponent::TickTimer(float& Remaining, float DeltaTime)
{
	if (Remaining <= 0.f)
	{
		return false;
	}

	Remaining -= DeltaTime;
	if (Remaining <= 0.f)
	{
		Remaining = 0.f;
		return true;
	}
	return false;
}

void URPGStatusEffectComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	if (IsBurning())
	{
		BurnTickAccumulator += DeltaTime;
		while (BurnTickAccumulator >= BurnTickInterval && BurnRemaining > 0.f)
		{
			BurnTickAccumulator -= BurnTickInterval;
			UGameplayStatics::ApplyDamage(GetOwner(), BurnDamagePerSecond * BurnTickInterval, BurnInstigator.Get(), BurnCauser.Get(), UDamageType_Fire::StaticClass());
		}
	}

	bool bChanged = false;
	bChanged |= TickTimer(SlowRemaining, DeltaTime);
	bChanged |= TickTimer(FreezeRemaining, DeltaTime);
	bChanged |= TickTimer(StunRemaining, DeltaTime);
	bChanged |= TickTimer(BurnRemaining, DeltaTime);

	if (!IsSlowed())
	{
		SlowMultiplier = 1.f;
	}

	if (bChanged)
	{
		OnStatusChanged.Broadcast();
	}
}
