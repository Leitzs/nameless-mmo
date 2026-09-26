#include "Components/RPGSpellbookComponent.h"

#include "Characters/RPGCharacterBase.h"
#include "Components/RPGAttributeComponent.h"
#include "Engine/World.h"
#include "RPGTest.h"
#include "Spells/RPGSpell.h"
#include "TimerManager.h"

URPGSpellbookComponent::URPGSpellbookComponent()
{
	PrimaryComponentTick.bCanEverTick = false;
}

void URPGSpellbookComponent::BeginPlay()
{
	Super::BeginPlay();

	Spells.Reset();
	for (const TSubclassOf<URPGSpell>& SpellClass : SpellClasses)
	{
		if (SpellClass)
		{
			Spells.Add(NewObject<URPGSpell>(this, SpellClass));
		}
	}
}

ARPGCharacterBase* URPGSpellbookComponent::GetCaster() const
{
	return Cast<ARPGCharacterBase>(GetOwner());
}

bool URPGSpellbookComponent::IsCasting() const
{
	return GetWorld() && GetWorld()->GetTimeSeconds() < CastEndTime;
}

ERPGCastResult URPGSpellbookComponent::CanCast(int32 SlotIndex) const
{
	const ARPGCharacterBase* Caster = GetCaster();
	const URPGSpell* Spell = GetSpell(SlotIndex);
	if (!Caster || !Spell)
	{
		return ERPGCastResult::InvalidSlot;
	}
	if (!Caster->IsAlive())
	{
		return ERPGCastResult::Dead;
	}
	if (Caster->IsIncapacitated())
	{
		return ERPGCastResult::Incapacitated;
	}
	if (IsCasting())
	{
		return ERPGCastResult::Busy;
	}
	if (Spell->GetCooldownRemaining() > 0.f)
	{
		return ERPGCastResult::Cooldown;
	}
	if (Caster->GetAttributes()->GetMana() < Spell->GetManaCost())
	{
		return ERPGCastResult::NotEnoughMana;
	}
	return Spell->CanCast(*Caster);
}

ERPGCastResult URPGSpellbookComponent::TryCast(int32 SlotIndex)
{
	const ERPGCastResult Result = CanCast(SlotIndex);
	if (Result != ERPGCastResult::Success)
	{
		return Result;
	}

	ARPGCharacterBase* Caster = GetCaster();
	URPGSpell* Spell = Spells[SlotIndex];

	Caster->GetAttributes()->TryConsumeMana(Spell->GetManaCost());
	Spell->StartCooldown();
	CastEndTime = GetWorld()->GetTimeSeconds() + Spell->GetCastTime();

	if (Spell->ShouldFaceAim())
	{
		FVector AimLocation;
		ARPGCharacterBase* Target = nullptr;
		Caster->ComputeAim(Spell->GetRange(), AimLocation, Target);
		Caster->FaceLocation(AimLocation, true);
	}

	Caster->PlayActionAnimation(Spell->GetCastAnimation(), Spell->GetAnimationPlayRate());

	if (Spell->GetReleaseDelay() <= 0.f)
	{
		ReleaseSpell(Spell);
	}
	else
	{
		GetWorld()->GetTimerManager().SetTimer(ReleaseTimer, FTimerDelegate::CreateUObject(this, &ThisClass::ReleaseSpell, Spell), Spell->GetReleaseDelay(), false);
	}

	UE_LOG(LogRPG, Verbose, TEXT("%s casts %s"), *Caster->GetName(), *Spell->GetDisplayName().ToString());
	OnSpellCast.Broadcast(SlotIndex, Spell);
	return ERPGCastResult::Success;
}

void URPGSpellbookComponent::ReleaseSpell(URPGSpell* Spell)
{
	ARPGCharacterBase* Caster = GetCaster();
	if (!Spell || !Caster || !Caster->CanAct())
	{
		// Interrupted (died, frozen or stunned during the wind-up): the mana and cooldown stay spent.
		return;
	}

	FRPGSpellContext Context;
	Context.Caster = Caster;
	Context.Origin = Caster->GetSpellOrigin();

	ARPGCharacterBase* Target = nullptr;
	Caster->ComputeAim(Spell->GetRange(), Context.AimLocation, Target);
	Context.Target = Target;

	Spell->Execute(Context);
}

void URPGSpellbookComponent::ResetCooldowns()
{
	for (URPGSpell* Spell : Spells)
	{
		Spell->ResetCooldown();
	}
	CastEndTime = 0.0;
}
