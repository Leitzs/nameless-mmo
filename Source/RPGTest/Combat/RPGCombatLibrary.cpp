#include "Combat/RPGCombatLibrary.h"

#include "AbilitySystemGlobals.h"
#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGGameplayEffects.h"
#include "Abilities/RPGGameplayTags.h"
#include "Characters/RPGCharacterBase.h"
#include "Components/CapsuleComponent.h"
#include "Core/RPGGameState.h"
#include "Engine/OverlapResult.h"
#include "Engine/World.h"

namespace
{
	/** The spec's maker: the source's own ability system when it has one, otherwise the target's. */
	UAbilitySystemComponent* GetEffectMaker(AActor* Source, UAbilitySystemComponent* Fallback)
	{
		UAbilitySystemComponent* SourceASC = UAbilitySystemGlobals::GetAbilitySystemComponentFromActor(URPGCombatLibrary::GetResponsibleCharacter(Source));
		return SourceASC ? SourceASC : Fallback;
	}

	bool CanAffect(const AActor* Source, const ARPGCharacterBase* Target)
	{
		if (!Target || !Target->IsAlive() || !Target->HasAuthority())
		{
			return false;
		}
		const ARPGCharacterBase* SourceCharacter = URPGCombatLibrary::GetResponsibleCharacter(Source);
		return !SourceCharacter || SourceCharacter == Target || URPGCombatLibrary::AreHostile(SourceCharacter, Target);
	}
}

ARPGCharacterBase* URPGCombatLibrary::GetResponsibleCharacter(const AActor* Actor)
{
	if (!Actor)
	{
		return nullptr;
	}

	if (const ARPGCharacterBase* Character = Cast<ARPGCharacterBase>(Actor))
	{
		return const_cast<ARPGCharacterBase*>(Character);
	}

	return Cast<ARPGCharacterBase>(Actor->GetInstigator());
}

bool URPGCombatLibrary::AreHostile(const AActor* A, const AActor* B)
{
	const ARPGCharacterBase* CharacterA = GetResponsibleCharacter(A);
	const ARPGCharacterBase* CharacterB = GetResponsibleCharacter(B);

	if (!CharacterA || !CharacterB)
	{
		return true;
	}

	if (CharacterA == CharacterB)
	{
		return false;
	}

	if (CharacterA->GetTeam() == CharacterB->GetTeam())
	{
		// Deathmatch: every player fights every other player.
		const ARPGGameState* GameState = CharacterA->GetWorld() ? CharacterA->GetWorld()->GetGameState<ARPGGameState>() : nullptr;
		return CharacterA->GetTeam() == ERPGTeam::Player && GameState && GameState->ArePlayersHostile();
	}

	return true;
}

TArray<ARPGCharacterBase*> URPGCombatLibrary::GetHostilesInRadius(const UObject* WorldContextObject, const AActor* Instigator, FVector Center, float Radius)
{
	TArray<ARPGCharacterBase*> Result;

	const UWorld* World = WorldContextObject ? WorldContextObject->GetWorld() : nullptr;
	if (!World || Radius <= 0.f)
	{
		return Result;
	}

	TArray<FOverlapResult> Overlaps;
	FCollisionQueryParams Params(SCENE_QUERY_STAT(RPGHostilesInRadius), false);
	World->OverlapMultiByObjectType(Overlaps, Center, FQuat::Identity, FCollisionObjectQueryParams(ECC_Pawn), FCollisionShape::MakeSphere(Radius), Params);

	for (const FOverlapResult& Overlap : Overlaps)
	{
		ARPGCharacterBase* Character = Cast<ARPGCharacterBase>(Overlap.GetActor());
		if (Character && Character->IsAlive() && AreHostile(Instigator, Character))
		{
			Result.AddUnique(Character);
		}
	}

	return Result;
}

TArray<ARPGCharacterBase*> URPGCombatLibrary::GetHostilesInArc(const ARPGCharacterBase* Attacker, float Range, float ArcDegrees)
{
	TArray<ARPGCharacterBase*> Result;
	if (!Attacker)
	{
		return Result;
	}

	const FVector Origin = Attacker->GetActorLocation();
	const FVector Forward = Attacker->GetActorForwardVector().GetSafeNormal2D();
	const float CosHalfArc = FMath::Cos(FMath::DegreesToRadians(FMath::Clamp(ArcDegrees, 0.f, 360.f) * 0.5f));

	// Query a bit wider than the reach so capsule edges count.
	for (ARPGCharacterBase* Candidate : GetHostilesInRadius(Attacker, Attacker, Origin, Range + 60.f))
	{
		const FVector ToCandidate = Candidate->GetActorLocation() - Origin;
		const float Reach = Range + Candidate->GetCapsuleComponent()->GetScaledCapsuleRadius();
		if (ToCandidate.Size2D() > Reach || FMath::Abs(ToCandidate.Z) > 150.f)
		{
			continue;
		}
		if (ArcDegrees < 360.f && FVector::DotProduct(Forward, ToCandidate.GetSafeNormal2D()) < CosHalfArc)
		{
			continue;
		}
		Result.Add(Candidate);
	}
	return Result;
}

ARPGCharacterBase* URPGCombatLibrary::FindMeleeTarget(const ARPGCharacterBase* Attacker, ARPGCharacterBase* Preferred, float Range, float ArcDegrees)
{
	const TArray<ARPGCharacterBase*> Candidates = GetHostilesInArc(Attacker, Range, ArcDegrees);
	if (Preferred && Candidates.Contains(Preferred))
	{
		return Preferred;
	}

	ARPGCharacterBase* Best = nullptr;
	float BestDistance = TNumericLimits<float>::Max();
	for (ARPGCharacterBase* Candidate : Candidates)
	{
		const float Distance = FVector::DistSquared(Attacker->GetActorLocation(), Candidate->GetActorLocation());
		if (Distance < BestDistance)
		{
			Best = Candidate;
			BestDistance = Distance;
		}
	}
	return Best;
}

bool URPGCombatLibrary::IsBehind(const AActor* Attacker, const AActor* Victim, float MaxAngleDegrees)
{
	if (!Attacker || !Victim)
	{
		return false;
	}

	const FVector ToAttacker = (Attacker->GetActorLocation() - Victim->GetActorLocation()).GetSafeNormal2D();
	const FVector VictimBack = -Victim->GetActorForwardVector().GetSafeNormal2D();
	return FVector::DotProduct(ToAttacker, VictimBack) >= FMath::Cos(FMath::DegreesToRadians(MaxAngleDegrees));
}

bool URPGCombatLibrary::ApplyDamage(AActor* Source, ARPGCharacterBase* Target, float Amount, const FGameplayTag& DamageType, AActor* Causer)
{
	if (Amount <= 0.f || !CanAffect(Source, Target))
	{
		return false;
	}

	UAbilitySystemComponent* TargetASC = Target->GetAbilitySystemComponent();
	UAbilitySystemComponent* Maker = GetEffectMaker(Source, TargetASC);
	if (!TargetASC || !Maker)
	{
		return false;
	}

	FGameplayEffectContextHandle Context = Maker->MakeEffectContext();
	Context.AddInstigator(GetResponsibleCharacter(Source), Causer ? Causer : Source);
	const FGameplayEffectSpecHandle Spec = Maker->MakeOutgoingSpec(URPGEffect_Damage::StaticClass(), 1.f, Context);
	if (!Spec.IsValid())
	{
		return false;
	}

	Spec.Data->SetSetByCallerMagnitude(RPGTags::Data_Damage, Amount);
	Spec.Data->AddDynamicAssetTag(DamageType.IsValid() ? DamageType : RPGTags::Damage_Physical);
	Maker->ApplyGameplayEffectSpecToTarget(*Spec.Data, TargetASC);
	return true;
}

bool URPGCombatLibrary::ApplyHeal(AActor* Source, ARPGCharacterBase* Target, float Amount)
{
	if (Amount <= 0.f || !Target || !Target->IsAlive() || !Target->HasAuthority())
	{
		return false;
	}

	UAbilitySystemComponent* TargetASC = Target->GetAbilitySystemComponent();
	UAbilitySystemComponent* Maker = GetEffectMaker(Source, TargetASC);
	if (!TargetASC || !Maker)
	{
		return false;
	}

	FGameplayEffectContextHandle Context = Maker->MakeEffectContext();
	Context.AddInstigator(GetResponsibleCharacter(Source), Source);
	const FGameplayEffectSpecHandle Spec = Maker->MakeOutgoingSpec(URPGEffect_Heal::StaticClass(), 1.f, Context);
	if (!Spec.IsValid())
	{
		return false;
	}

	Spec.Data->SetSetByCallerMagnitude(RPGTags::Data_Heal, Amount);
	Maker->ApplyGameplayEffectSpecToTarget(*Spec.Data, TargetASC);
	return true;
}

bool URPGCombatLibrary::ApplyStatus(AActor* Source, ARPGCharacterBase* Target, const FRPGStatusSpec& Status, AActor* Causer)
{
	if (!CanAffect(Source, Target))
	{
		return false;
	}
	URPGAbilitySystemComponent* TargetASC = Target->GetRPGAbilitySystem();
	return TargetASC && TargetASC->ApplyStatus(Status, GetResponsibleCharacter(Source), Causer ? Causer : Source);
}

void URPGCombatLibrary::ApplyStatuses(AActor* Source, ARPGCharacterBase* Target, const TArray<FRPGStatusSpec>& Statuses, AActor* Causer)
{
	for (const FRPGStatusSpec& Status : Statuses)
	{
		ApplyStatus(Source, Target, Status, Causer);
	}
}
