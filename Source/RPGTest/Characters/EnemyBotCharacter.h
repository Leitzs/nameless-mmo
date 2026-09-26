#pragma once

#include "CoreMinimal.h"
#include "Characters/RPGCharacterBase.h"
#include "EnemyBotCharacter.generated.h"

class UAnimSequenceBase;

/**
 * AI-controlled training enemy (a forest bandit). Fights in melee with a telegraphed three-hit combo and
 * closes distance with a telegraphed charge. Decisions are made by ARPGBotAIController; this class executes them.
 */
UCLASS()
class RPGTEST_API AEnemyBotCharacter : public ARPGCharacterBase
{
	GENERATED_BODY()

public:
	AEnemyBotCharacter();

	virtual void Tick(float DeltaSeconds) override;

	/** Attacking or charging; the AI should wait for the action to finish. */
	bool IsBusy() const { return Action != EBotAction::None; }

	bool CanMeleeAttack() const;
	bool CanCharge() const;
	void StartMeleeAttack(ARPGCharacterBase* Target);
	void StartCharge(ARPGCharacterBase* Target);

	void SetRunning(bool bInRunning) { bRunning = bInRunning; }

	void SetHomeLocation(const FVector& InHomeLocation) { HomeLocation = InHomeLocation; }
	const FVector& GetHomeLocation() const { return HomeLocation; }

	float GetMeleeRange() const { return MeleeRange; }
	float GetChargeMinRange() const { return ChargeMinRange; }
	float GetChargeMaxRange() const { return ChargeMaxRange; }
	float GetAggroRange() const { return AggroRange; }
	float GetLeashRange() const { return LeashRange; }
	float GetPatrolRadius() const { return PatrolRadius; }

protected:
	virtual void BeginPlay() override;
	virtual void HandleDeath(AActor* Killer) override;
	virtual void OnDamageTaken(float HealthDamage, float AbsorbedDamage, AActor* InstigatorActor) override;
	virtual float GetDesiredMoveSpeed() const override;
	virtual void AlignCosmetics() override;
	virtual void ApplyCosmeticMaterials() override;

	// Melee
	UPROPERTY(EditAnywhere, Category = "Bot|Melee", meta = (ClampMin = "0"))
	float MeleeDamage = 16.f;

	/** Reach measured from the bot's center to the target's capsule edge. */
	UPROPERTY(EditAnywhere, Category = "Bot|Melee", meta = (ClampMin = "0"))
	float MeleeRange = 190.f;

	UPROPERTY(EditAnywhere, Category = "Bot|Melee", meta = (ClampMin = "0", ClampMax = "360"))
	float MeleeArcDegrees = 120.f;

	/** Warning time between starting a swing and the hit landing. */
	UPROPERTY(EditAnywhere, Category = "Bot|Melee", meta = (ClampMin = "0"))
	float MeleeWindup = 0.45f;

	UPROPERTY(EditAnywhere, Category = "Bot|Melee", meta = (ClampMin = "0"))
	float MeleeRecovery = 0.45f;

	UPROPERTY(EditAnywhere, Category = "Bot|Melee", meta = (ClampMin = "0"))
	float AttackCooldown = 1.3f;

	UPROPERTY(EditDefaultsOnly, Category = "Bot|Melee")
	TArray<TObjectPtr<UAnimSequenceBase>> AttackAnimations;

	UPROPERTY(EditAnywhere, Category = "Bot|Melee", meta = (ClampMin = "0.1"))
	float AttackPlayRate = 1.2f;

	// Charge
	UPROPERTY(EditAnywhere, Category = "Bot|Charge", meta = (ClampMin = "0"))
	float ChargeDamage = 24.f;

	UPROPERTY(EditAnywhere, Category = "Bot|Charge", meta = (ClampMin = "0"))
	float ChargeMinRange = 550.f;

	UPROPERTY(EditAnywhere, Category = "Bot|Charge", meta = (ClampMin = "0"))
	float ChargeMaxRange = 1500.f;

	UPROPERTY(EditAnywhere, Category = "Bot|Charge", meta = (ClampMin = "0"))
	float ChargeWindup = 0.7f;

	UPROPERTY(EditAnywhere, Category = "Bot|Charge", meta = (ClampMin = "0"))
	float ChargeSpeed = 1700.f;

	UPROPERTY(EditAnywhere, Category = "Bot|Charge", meta = (ClampMin = "0"))
	float ChargeDuration = 0.6f;

	UPROPERTY(EditAnywhere, Category = "Bot|Charge", meta = (ClampMin = "0"))
	float ChargeCooldown = 9.f;

	UPROPERTY(EditAnywhere, Category = "Bot|Charge", meta = (ClampMin = "0"))
	float ChargeKnockback = 800.f;

	UPROPERTY(EditDefaultsOnly, Category = "Bot|Charge")
	TObjectPtr<UAnimSequenceBase> ChargeAnimation;

	// Movement & awareness
	UPROPERTY(EditAnywhere, Category = "Bot|Movement", meta = (ClampMin = "0"))
	float WalkSpeed = 200.f;

	UPROPERTY(EditAnywhere, Category = "Bot|Movement", meta = (ClampMin = "0"))
	float RunSpeed = 520.f;

	UPROPERTY(EditAnywhere, Category = "Bot|AI", meta = (ClampMin = "0"))
	float AggroRange = 2000.f;

	/** Gives up the chase when this far from home. */
	UPROPERTY(EditAnywhere, Category = "Bot|AI", meta = (ClampMin = "0"))
	float LeashRange = 4500.f;

	UPROPERTY(EditAnywhere, Category = "Bot|AI", meta = (ClampMin = "0"))
	float PatrolRadius = 700.f;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> Helmet;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> HornLeft;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> HornRight;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> SwordBlade;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> SwordGuard;

	UPROPERTY(VisibleAnywhere, Category = "Components|Cosmetics")
	TObjectPtr<UStaticMeshComponent> SwordGrip;

private:
	enum class EBotAction : uint8
	{
		None,
		MeleeWindup,
		Recover,
		ChargeWindup,
		Charging
	};

	void SetAction(EBotAction NewAction, float Duration);
	void CancelAction();
	void ResolveMeleeHit();
	void BeginChargeDash();
	void TryChargeHit();

	EBotAction Action = EBotAction::None;
	float ActionTimeRemaining = 0.f;
	TWeakObjectPtr<ARPGCharacterBase> ActionTarget;
	FVector ChargeDirection = FVector::ForwardVector;
	FVector HomeLocation = FVector::ZeroVector;
	double NextAttackTime = 0.0;
	double NextChargeTime = 0.0;
	int32 ComboIndex = 0;
	bool bChargeHitApplied = false;
	bool bRunning = false;
};
