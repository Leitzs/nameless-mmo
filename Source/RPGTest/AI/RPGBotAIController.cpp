#include "AI/RPGBotAIController.h"

#include "Characters/EnemyBotCharacter.h"
#include "Combat/RPGCombatLibrary.h"
#include "Components/RPGAttributeComponent.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/PlayerController.h"
#include "NavigationSystem.h"
#include "Navigation/PathFollowingComponent.h"

namespace RPGBotAIPrivate
{
	constexpr float PerceptionInterval = 0.25f;
	constexpr float RepathInterval = 0.4f;
	constexpr float HomeArrivalDistance = 200.f;
}

ARPGBotAIController::ARPGBotAIController()
{
	PrimaryActorTick.bCanEverTick = true;
	bSetControlRotationFromPawnOrientation = true;
}

AEnemyBotCharacter* ARPGBotAIController::GetBot() const
{
	return Cast<AEnemyBotCharacter>(GetPawn());
}

void ARPGBotAIController::OnPossess(APawn* InPawn)
{
	Super::OnPossess(InPawn);

	SetState(EBotState::Idle);
	NextPatrolTime = GetWorld()->GetTimeSeconds() + FMath::FRandRange(1.f, 3.f);
}

void ARPGBotAIController::NotifyDamagedBy(AActor* InstigatorActor)
{
	ARPGCharacterBase* Attacker = URPGCombatLibrary::GetResponsibleCharacter(InstigatorActor);
	if (!IsValidTarget(Attacker))
	{
		return;
	}

	Target = Attacker;
	IgnoreAggroUntil = 0.0;
	if (State == EBotState::Idle || State == EBotState::Patrol || State == EBotState::Return)
	{
		SetState(EBotState::Chase);
	}
}

bool ARPGBotAIController::IsValidTarget(const ARPGCharacterBase* Candidate) const
{
	const AEnemyBotCharacter* Bot = GetBot();
	return Bot && Candidate && Candidate != Bot && Candidate->IsAlive() && Bot->IsHostileTo(Candidate);
}

void ARPGBotAIController::SetState(EBotState NewState)
{
	if (State == NewState)
	{
		return;
	}

	State = NewState;
	bDirectSteering = false;
	NextRepathTime = 0.0;

	if (AEnemyBotCharacter* Bot = GetBot())
	{
		Bot->SetRunning(NewState == EBotState::Chase || NewState == EBotState::Attack || NewState == EBotState::Return);
	}

	if (NewState == EBotState::Idle || NewState == EBotState::Attack)
	{
		StopMovement();
	}
}

void ARPGBotAIController::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	AEnemyBotCharacter* Bot = GetBot();
	if (!Bot || !Bot->IsAlive())
	{
		return;
	}

	if (Bot->IsIncapacitated())
	{
		StopMovement();
		bDirectSteering = false;
		return;
	}

	if (Bot->IsBusy())
	{
		return;
	}

	UpdatePerception();

	ARPGCharacterBase* CurrentTarget = Target.Get();
	if (CurrentTarget && !IsValidTarget(CurrentTarget))
	{
		Target = nullptr;
		CurrentTarget = nullptr;
		SetState(EBotState::Return);
	}

	// Leash: never get dragged too far from home.
	if (CurrentTarget && FVector::Dist2D(Bot->GetActorLocation(), Bot->GetHomeLocation()) > Bot->GetLeashRange())
	{
		Target = nullptr;
		CurrentTarget = nullptr;
		IgnoreAggroUntil = GetWorld()->GetTimeSeconds() + 4.0;
		SetState(EBotState::Return);
	}

	const float DistanceToTarget = CurrentTarget ? FVector::Dist2D(Bot->GetActorLocation(), CurrentTarget->GetActorLocation()) : 0.f;

	switch (State)
	{
	case EBotState::Idle:
	case EBotState::Patrol:
		if (CurrentTarget)
		{
			SetState(EBotState::Chase);
		}
		else
		{
			TickIdle();
		}
		break;
	case EBotState::Chase:
		TickChase(DistanceToTarget);
		break;
	case EBotState::Attack:
		TickAttack(DistanceToTarget);
		break;
	case EBotState::Return:
		if (CurrentTarget)
		{
			SetState(EBotState::Chase);
		}
		else
		{
			TickReturn();
		}
		break;
	}

	if (bDirectSteering)
	{
		const FVector ToGoal = (DirectSteerGoal - Bot->GetActorLocation()).GetSafeNormal2D();
		Bot->AddMovementInput(ToGoal, 1.f);
	}
}

void ARPGBotAIController::UpdatePerception()
{
	const double Now = GetWorld()->GetTimeSeconds();
	if (Now < NextPerceptionTime || Target.IsValid() || Now < IgnoreAggroUntil)
	{
		return;
	}

	NextPerceptionTime = Now + RPGBotAIPrivate::PerceptionInterval;
	Target = FindVisibleHostile();
}

ARPGCharacterBase* ARPGBotAIController::FindVisibleHostile() const
{
	const AEnemyBotCharacter* Bot = GetBot();
	if (!Bot)
	{
		return nullptr;
	}

	ARPGCharacterBase* Best = nullptr;
	float BestDistance = Bot->GetAggroRange();

	for (FConstPlayerControllerIterator It = GetWorld()->GetPlayerControllerIterator(); It; ++It)
	{
		const APlayerController* PlayerController = It->Get();
		ARPGCharacterBase* Candidate = PlayerController ? Cast<ARPGCharacterBase>(PlayerController->GetPawn()) : nullptr;
		if (!IsValidTarget(Candidate))
		{
			continue;
		}

		const float Distance = FVector::Dist(Bot->GetActorLocation(), Candidate->GetActorLocation());
		if (Distance <= BestDistance && LineOfSightTo(Candidate))
		{
			Best = Candidate;
			BestDistance = Distance;
		}
	}

	return Best;
}

void ARPGBotAIController::TickIdle()
{
	AEnemyBotCharacter* Bot = GetBot();
	const double Now = GetWorld()->GetTimeSeconds();
	if (Now < NextPatrolTime)
	{
		return;
	}

	NextPatrolTime = Now + FMath::FRandRange(4.f, 8.f);

	FNavLocation PatrolPoint;
	UNavigationSystemV1* NavSystem = FNavigationSystem::GetCurrent<UNavigationSystemV1>(GetWorld());
	if (NavSystem && NavSystem->GetRandomReachablePointInRadius(Bot->GetHomeLocation(), Bot->GetPatrolRadius(), PatrolPoint))
	{
		SetState(EBotState::Patrol);
		Bot->SetRunning(false);
		MoveToLocation(PatrolPoint.Location, 50.f);
	}
}

void ARPGBotAIController::TickChase(float DistanceToTarget)
{
	AEnemyBotCharacter* Bot = GetBot();
	ARPGCharacterBase* CurrentTarget = Target.Get();
	if (!CurrentTarget)
	{
		SetState(EBotState::Return);
		return;
	}

	if (DistanceToTarget <= Bot->GetMeleeRange())
	{
		SetState(EBotState::Attack);
		return;
	}

	if (DistanceToTarget >= Bot->GetChargeMinRange() && DistanceToTarget <= Bot->GetChargeMaxRange() && Bot->CanCharge() && LineOfSightTo(CurrentTarget))
	{
		bDirectSteering = false;
		Bot->StartCharge(CurrentTarget);
		return;
	}

	MoveTowards(CurrentTarget, CurrentTarget->GetActorLocation(), Bot->GetMeleeRange() * 0.6f);
}

void ARPGBotAIController::TickAttack(float DistanceToTarget)
{
	AEnemyBotCharacter* Bot = GetBot();
	ARPGCharacterBase* CurrentTarget = Target.Get();
	if (!CurrentTarget)
	{
		SetState(EBotState::Return);
		return;
	}

	if (DistanceToTarget > Bot->GetMeleeRange() * 1.25f)
	{
		SetState(EBotState::Chase);
		return;
	}

	Bot->FaceLocation(CurrentTarget->GetActorLocation(), false);
	if (Bot->CanMeleeAttack())
	{
		Bot->StartMeleeAttack(CurrentTarget);
	}
}

void ARPGBotAIController::TickReturn()
{
	AEnemyBotCharacter* Bot = GetBot();
	if (FVector::Dist2D(Bot->GetActorLocation(), Bot->GetHomeLocation()) <= RPGBotAIPrivate::HomeArrivalDistance)
	{
		Bot->GetAttributes()->RestoreAll();
		SetState(EBotState::Idle);
		return;
	}

	MoveTowards(nullptr, Bot->GetHomeLocation(), 100.f);
}

void ARPGBotAIController::MoveTowards(AActor* GoalActor, const FVector& GoalLocation, float AcceptanceRadius)
{
	const double Now = GetWorld()->GetTimeSeconds();
	DirectSteerGoal = GoalLocation;

	if (Now < NextRepathTime && (bDirectSteering || GetMoveStatus() == EPathFollowingStatus::Moving))
	{
		return;
	}
	NextRepathTime = Now + RPGBotAIPrivate::RepathInterval;

	const EPathFollowingRequestResult::Type Result = GoalActor
		? MoveToActor(GoalActor, AcceptanceRadius, true, true, false)
		: MoveToLocation(GoalLocation, AcceptanceRadius, true, true, true, false);

	// Without a navigation mesh (or an unreachable goal) walk straight at it.
	bDirectSteering = Result == EPathFollowingRequestResult::Failed;
}
