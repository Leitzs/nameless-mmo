#include "Characters/EnemyBotCharacter.h"

#include "AI/RPGBotAIController.h"
#include "Animation/AnimSequenceBase.h"
#include "Combat/RPGCombatLibrary.h"
#include "Combat/RPGDamageTypes.h"
#include "Components/CapsuleComponent.h"
#include "Components/RPGAttributeComponent.h"
#include "Components/RPGStatusEffectComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "UObject/ConstructorHelpers.h"

#define LOCTEXT_NAMESPACE "RPGEnemyBot"

namespace EnemyBotPrivate
{
	const FName HeadBone(TEXT("head"));
	const FName RightHandBone(TEXT("hand_r"));
}

AEnemyBotCharacter::AEnemyBotCharacter()
{
	using namespace EnemyBotPrivate;

	Team = ERPGTeam::Enemy;
	CharacterName = LOCTEXT("BotName", "Forest Bandit");
	BodyTint = FLinearColor(0.35f, 0.06f, 0.04f, 1.f);
	BaseMoveSpeed = RunSpeed;
	CorpseLifeSpan = 5.f;

	AIControllerClass = ARPGBotAIController::StaticClass();
	AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned;

	Attributes->SetDefaults(500.f, 0.f, 12.f, 0.f);
	GetCharacterMovement()->RotationRate = FRotator(0.f, 540.f, 0.f);

	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Attack1(TEXT("/Game/Characters/Mannequins/Anims/Unarmed/Attack/MM_Attack_01.MM_Attack_01"));
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Attack2(TEXT("/Game/Characters/Mannequins/Anims/Unarmed/Attack/MM_Attack_02.MM_Attack_02"));
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Attack3(TEXT("/Game/Characters/Mannequins/Anims/Unarmed/Attack/MM_Attack_03.MM_Attack_03"));
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> Charged(TEXT("/Game/Characters/Mannequins/Anims/Unarmed/Attack/MM_ChargedAttack.MM_ChargedAttack"));
	for (UAnimSequenceBase* Animation : { Attack1.Object.Get(), Attack2.Object.Get(), Attack3.Object.Get() })
	{
		if (Animation)
		{
			AttackAnimations.Add(Animation);
		}
	}
	ChargeAnimation = Charged.Object;

	static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(RPGAssets::SphereMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> ConeMesh(RPGAssets::ConeMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMesh(RPGAssets::CubeMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> CylinderMesh(RPGAssets::CylinderMesh);

	Helmet = CreateCosmeticPart(TEXT("Helmet"), SphereMesh.Object, HeadBone);
	HornLeft = CreateCosmeticPart(TEXT("HornLeft"), ConeMesh.Object, HeadBone);
	HornRight = CreateCosmeticPart(TEXT("HornRight"), ConeMesh.Object, HeadBone);
	SwordBlade = CreateCosmeticPart(TEXT("SwordBlade"), CubeMesh.Object, RightHandBone);
	SwordGuard = CreateCosmeticPart(TEXT("SwordGuard"), CubeMesh.Object, RightHandBone);
	SwordGrip = CreateCosmeticPart(TEXT("SwordGrip"), CylinderMesh.Object, RightHandBone);
}

void AEnemyBotCharacter::BeginPlay()
{
	Super::BeginPlay();

	if (HomeLocation.IsZero())
	{
		HomeLocation = GetActorLocation();
	}
}

void AEnemyBotCharacter::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (Action == EBotAction::None)
	{
		return;
	}

	if (!CanAct())
	{
		CancelAction();
		return;
	}

	ARPGCharacterBase* Target = ActionTarget.Get();
	if (Target && (Action == EBotAction::MeleeWindup || Action == EBotAction::ChargeWindup))
	{
		FaceLocation(Target->GetActorLocation(), false);
	}

	if (Action == EBotAction::Charging)
	{
		AddMovementInput(ChargeDirection, 1.f);
		TryChargeHit();
		if (bChargeHitApplied)
		{
			SetAction(EBotAction::Recover, 0.6f);
			return;
		}
	}

	ActionTimeRemaining -= DeltaSeconds;
	if (ActionTimeRemaining > 0.f)
	{
		return;
	}

	switch (Action)
	{
	case EBotAction::MeleeWindup:
		ResolveMeleeHit();
		SetAction(EBotAction::Recover, MeleeRecovery);
		break;
	case EBotAction::ChargeWindup:
		BeginChargeDash();
		SetAction(EBotAction::Charging, ChargeDuration);
		break;
	case EBotAction::Charging:
		SetAction(EBotAction::Recover, 0.5f);
		break;
	default:
		SetAction(EBotAction::None, 0.f);
		break;
	}
}

bool AEnemyBotCharacter::CanMeleeAttack() const
{
	return CanAct() && !IsBusy() && GetWorld()->GetTimeSeconds() >= NextAttackTime;
}

bool AEnemyBotCharacter::CanCharge() const
{
	return CanAct() && !IsBusy() && GetWorld()->GetTimeSeconds() >= NextChargeTime && GetCharacterMovement()->IsMovingOnGround();
}

void AEnemyBotCharacter::StartMeleeAttack(ARPGCharacterBase* Target)
{
	if (!Target || !CanMeleeAttack())
	{
		return;
	}

	ActionTarget = Target;
	NextAttackTime = GetWorld()->GetTimeSeconds() + AttackCooldown;

	if (AttackAnimations.Num() > 0)
	{
		PlayActionAnimation(AttackAnimations[ComboIndex % AttackAnimations.Num()], AttackPlayRate);
		ComboIndex = (ComboIndex + 1) % AttackAnimations.Num();
	}

	if (AController* BotController = GetController())
	{
		BotController->StopMovement();
	}
	SetTelegraphGlow(MeleeWindup * 0.8f);
	FaceLocation(Target->GetActorLocation(), false);
	SetAction(EBotAction::MeleeWindup, MeleeWindup);
}

void AEnemyBotCharacter::StartCharge(ARPGCharacterBase* Target)
{
	if (!Target || !CanCharge())
	{
		return;
	}

	ActionTarget = Target;
	NextChargeTime = GetWorld()->GetTimeSeconds() + ChargeCooldown;
	bChargeHitApplied = false;

	if (AController* BotController = GetController())
	{
		BotController->StopMovement();
	}
	GetCharacterMovement()->StopMovementImmediately();
	PlayActionAnimation(ChargeAnimation, 1.f);
	SetTelegraphGlow(ChargeWindup);
	FaceLocation(Target->GetActorLocation(), false);
	SetAction(EBotAction::ChargeWindup, ChargeWindup);
}

void AEnemyBotCharacter::SetAction(EBotAction NewAction, float Duration)
{
	Action = NewAction;
	ActionTimeRemaining = Duration;
}

void AEnemyBotCharacter::CancelAction()
{
	if (Action != EBotAction::None)
	{
		StopActionAnimation(0.15f);
		SetTelegraphGlow(0.f);
		SetAction(EBotAction::None, 0.f);
	}
}

void AEnemyBotCharacter::ResolveMeleeHit()
{
	ARPGCharacterBase* Target = ActionTarget.Get();
	if (!Target || !Target->IsAlive())
	{
		return;
	}

	const FVector ToTarget = Target->GetActorLocation() - GetActorLocation();
	const float Reach = MeleeRange + Target->GetCapsuleComponent()->GetScaledCapsuleRadius();
	if (ToTarget.Size2D() > Reach || FMath::Abs(ToTarget.Z) > 150.f)
	{
		return;
	}

	const float CosHalfArc = FMath::Cos(FMath::DegreesToRadians(MeleeArcDegrees * 0.5f));
	if (FVector::DotProduct(GetActorForwardVector().GetSafeNormal2D(), ToTarget.GetSafeNormal2D()) < CosHalfArc)
	{
		return;
	}

	URPGCombatLibrary::DealDamage(Target, MeleeDamage, this, this, UDamageType_Physical::StaticClass());
	Target->ApplyKnockback(ToTarget, 250.f, 60.f);
}

void AEnemyBotCharacter::BeginChargeDash()
{
	const ARPGCharacterBase* Target = ActionTarget.Get();
	ChargeDirection = Target ? (Target->GetActorLocation() - GetActorLocation()).GetSafeNormal2D() : GetActorForwardVector();
	if (ChargeDirection.IsNearlyZero())
	{
		ChargeDirection = GetActorForwardVector();
	}

	SetActorRotation(ChargeDirection.Rotation());
	GetCharacterMovement()->Velocity = ChargeDirection * ChargeSpeed;
}

void AEnemyBotCharacter::TryChargeHit()
{
	ARPGCharacterBase* Target = ActionTarget.Get();
	if (bChargeHitApplied || !Target || !Target->IsAlive())
	{
		return;
	}

	const FVector ToTarget = Target->GetActorLocation() - GetActorLocation();
	const float Reach = GetCapsuleComponent()->GetScaledCapsuleRadius() + Target->GetCapsuleComponent()->GetScaledCapsuleRadius() + 70.f;
	if (ToTarget.Size2D() > Reach || FMath::Abs(ToTarget.Z) > 150.f)
	{
		return;
	}

	bChargeHitApplied = true;
	URPGCombatLibrary::DealDamage(Target, ChargeDamage, this, this, UDamageType_Physical::StaticClass());
	if (Target->IsAlive())
	{
		Target->ApplyKnockback(ToTarget, ChargeKnockback, 350.f);
		Target->GetStatusEffects()->ApplyStun(0.4f);
	}
	GetCharacterMovement()->StopMovementImmediately();
}

void AEnemyBotCharacter::HandleDeath(AActor* Killer)
{
	CancelAction();
	Super::HandleDeath(Killer);
}

void AEnemyBotCharacter::OnDamageTaken(float HealthDamage, float AbsorbedDamage, AActor* InstigatorActor)
{
	if (ARPGBotAIController* BotController = Cast<ARPGBotAIController>(GetController()))
	{
		BotController->NotifyDamagedBy(InstigatorActor);
	}
}

float AEnemyBotCharacter::GetDesiredMoveSpeed() const
{
	switch (Action)
	{
	case EBotAction::MeleeWindup:
	case EBotAction::ChargeWindup:
	case EBotAction::Recover:
		return 0.f;
	case EBotAction::Charging:
		return ChargeSpeed;
	default:
		return bRunning ? RunSpeed : WalkSpeed;
	}
}

void AEnemyBotCharacter::AlignCosmetics()
{
	using namespace EnemyBotPrivate;

	// Horned iron helmet.
	AlignCosmeticPart(Helmet, HeadBone, FVector(1.f, 0.f, 12.f), FRotator::ZeroRotator, FVector(0.3f, 0.28f, 0.27f));
	const FVector LeftHornDirection = FVector(0.2f, -0.75f, 0.63f).GetSafeNormal();
	const FVector RightHornDirection = FVector(0.2f, 0.75f, 0.63f).GetSafeNormal();
	AlignCosmeticPart(HornLeft, HeadBone, FVector(2.f, -12.f, 17.f) + LeftHornDirection * 11.f, FRotationMatrix::MakeFromZ(LeftHornDirection).Rotator(), FVector(0.08f, 0.08f, 0.22f));
	AlignCosmeticPart(HornRight, HeadBone, FVector(2.f, 12.f, 17.f) + RightHornDirection * 11.f, FRotationMatrix::MakeFromZ(RightHornDirection).Rotator(), FVector(0.08f, 0.08f, 0.22f));

	// Sword held forward and up, in a guard stance.
	const FVector BladeDirection = FVector(0.77f, 0.f, 0.64f).GetSafeNormal();
	const FRotator BladeRotation = FRotationMatrix::MakeFromZY(BladeDirection, FVector::RightVector).Rotator();
	AlignCosmeticPart(SwordGrip, RightHandBone, BladeDirection * 3.f, BladeRotation, FVector(0.035f, 0.035f, 0.2f));
	AlignCosmeticPart(SwordGuard, RightHandBone, BladeDirection * 14.f, BladeRotation, FVector(0.05f, 0.3f, 0.04f));
	AlignCosmeticPart(SwordBlade, RightHandBone, BladeDirection * 60.f, BladeRotation, FVector(0.02f, 0.07f, 0.9f));
}

void AEnemyBotCharacter::ApplyCosmeticMaterials()
{
	RPGAssets::ApplySurface(Helmet, FLinearColor(0.2f, 0.2f, 0.22f), 0.35f);
	RPGAssets::ApplySurface(HornLeft, FLinearColor(0.7f, 0.64f, 0.52f), 0.6f);
	RPGAssets::ApplySurface(HornRight, FLinearColor(0.7f, 0.64f, 0.52f), 0.6f);
	RPGAssets::ApplySurface(SwordBlade, FLinearColor(0.55f, 0.56f, 0.6f), 0.25f);
	RPGAssets::ApplySurface(SwordGuard, FLinearColor(0.45f, 0.33f, 0.1f), 0.4f);
	RPGAssets::ApplySurface(SwordGrip, FLinearColor(0.1f, 0.05f, 0.03f), 0.8f);
}

#undef LOCTEXT_NAMESPACE
