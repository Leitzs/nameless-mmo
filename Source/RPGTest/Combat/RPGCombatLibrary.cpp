#include "Combat/RPGCombatLibrary.h"

#include "Characters/RPGCharacterBase.h"
#include "Engine/OverlapResult.h"
#include "Engine/World.h"
#include "GameFramework/Controller.h"
#include "Kismet/GameplayStatics.h"

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

AActor* URPGCombatLibrary::ResolveInstigator(AController* EventInstigator, AActor* DamageCauser)
{
	if (EventInstigator && EventInstigator->GetPawn())
	{
		return EventInstigator->GetPawn();
	}

	if (ARPGCharacterBase* Responsible = GetResponsibleCharacter(DamageCauser))
	{
		return Responsible;
	}

	return DamageCauser;
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

	return CharacterA->GetTeam() != CharacterB->GetTeam();
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

float URPGCombatLibrary::DealDamage(AActor* Target, float Amount, AActor* InstigatorActor, AActor* DamageCauser, TSubclassOf<UDamageType> DamageType)
{
	if (!Target || Amount <= 0.f)
	{
		return 0.f;
	}

	const APawn* InstigatorPawn = Cast<APawn>(InstigatorActor);
	AController* InstigatorController = InstigatorPawn ? InstigatorPawn->GetController() : nullptr;
	return UGameplayStatics::ApplyDamage(Target, Amount, InstigatorController, DamageCauser ? DamageCauser : InstigatorActor, DamageType);
}
