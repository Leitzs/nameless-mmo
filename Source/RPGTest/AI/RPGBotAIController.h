#pragma once

#include "CoreMinimal.h"
#include "AIController.h"
#include "RPGBotAIController.generated.h"

class AEnemyBotCharacter;
class ARPGCharacterBase;

/**
 * Small state machine for the training bot: idle/patrol around home, chase and fight hostiles it can see
 * (or that hit it), give up and walk home when dragged beyond its leash range.
 */
UCLASS()
class RPGTEST_API ARPGBotAIController : public AAIController
{
	GENERATED_BODY()

public:
	ARPGBotAIController();

	virtual void Tick(float DeltaSeconds) override;

	/** Being hit always makes the bot fight back, even outside its aggro range. */
	void NotifyDamagedBy(AActor* InstigatorActor);

	ARPGCharacterBase* GetTarget() const { return Target.Get(); }

protected:
	virtual void OnPossess(APawn* InPawn) override;

private:
	enum class EBotState : uint8
	{
		Idle,
		Patrol,
		Chase,
		Attack,
		Return
	};

	void SetState(EBotState NewState);
	void UpdatePerception();
	ARPGCharacterBase* FindVisibleHostile() const;
	bool IsValidTarget(const ARPGCharacterBase* Candidate) const;

	void TickIdle();
	void TickChase(float DistanceToTarget);
	void TickAttack(float DistanceToTarget);
	void TickReturn();

	/** Path to the goal, steering directly when there is no navigation mesh. */
	void MoveTowards(AActor* GoalActor, const FVector& GoalLocation, float AcceptanceRadius);

	AEnemyBotCharacter* GetBot() const;

	TWeakObjectPtr<ARPGCharacterBase> Target;
	EBotState State = EBotState::Idle;
	double NextPerceptionTime = 0.0;
	double NextRepathTime = 0.0;
	double NextPatrolTime = 0.0;
	double IgnoreAggroUntil = 0.0;
	bool bDirectSteering = false;
	FVector DirectSteerGoal = FVector::ZeroVector;
};
