#include "Spells/RPGSpell.h"

#include "Engine/World.h"

UWorld* URPGSpell::GetWorld() const
{
	// The class default object has no world; returning null there lets Blueprint subclasses use world context nodes.
	if (HasAnyFlags(RF_ClassDefaultObject) || !GetOuter())
	{
		return nullptr;
	}
	return GetOuter()->GetWorld();
}

void URPGSpell::StartCooldown()
{
	if (const UWorld* World = GetWorld())
	{
		CooldownEndTime = World->GetTimeSeconds() + Cooldown;
	}
}

float URPGSpell::GetCooldownRemaining() const
{
	const UWorld* World = GetWorld();
	return World ? FMath::Max(0.f, static_cast<float>(CooldownEndTime - World->GetTimeSeconds())) : 0.f;
}
