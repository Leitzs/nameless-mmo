#include "Characters/RPGPlayerCharacter.h"

#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGGameplayTags.h"
#include "Camera/CameraComponent.h"
#include "Characters/RPGCharacterMovementComponent.h"
#include "Engine/World.h"
#include "GameFramework/Controller.h"
#include "GameFramework/SpringArmComponent.h"

ARPGPlayerCharacter::ARPGPlayerCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	Team = ERPGTeam::Player;

	CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
	CameraBoom->SetupAttachment(RootComponent);
	CameraBoom->TargetArmLength = DesiredArmLength;
	CameraBoom->SocketOffset = FVector(0.f, 55.f, 70.f);
	CameraBoom->bUsePawnControlRotation = true;
	CameraBoom->bEnableCameraLag = true;
	CameraBoom->CameraLagSpeed = 14.f;
	CameraBoom->ProbeSize = 14.f;

	FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
	FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
	FollowCamera->bUsePawnControlRotation = false;
	FollowCamera->SetFieldOfView(85.f);
}

void ARPGPlayerCharacter::BeginPlay()
{
	Super::BeginPlay();
	DesiredArmLength = CameraBoom->TargetArmLength;
}

void ARPGPlayerCharacter::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	CameraBoom->TargetArmLength = FMath::FInterpTo(CameraBoom->TargetArmLength, DesiredArmLength, DeltaSeconds, 8.f);

	URPGCharacterMovementComponent* Movement = GetRPGMovement();
	if (!Movement)
	{
		return;
	}

	// The controlling machine decides; the flag reaches the server inside the saved moves.
	if (IsLocallyControlled())
	{
		Movement->SetCastSlowed(HasStatus(RPGTags::State_Casting_Slow));
	}

	// While using an ability, keep facing the aim direction instead of turning towards the movement direction.
	// Feared characters always face where they run.
	Movement->bOrientRotationToMovement = !Movement->IsCastSlowed() && (!HasStatus(RPGTags::State_Casting) || HasStatus(RPGTags::Status_CC_Fear));
}

URPGCharacterMovementComponent* ARPGPlayerCharacter::GetRPGMovement() const
{
	return Cast<URPGCharacterMovementComponent>(GetCharacterMovement());
}

bool ARPGPlayerCharacter::IsSprinting() const
{
	const URPGCharacterMovementComponent* Movement = GetRPGMovement();
	return Movement && Movement->WantsToSprint();
}

void ARPGPlayerCharacter::Move(const FVector2D& Axis)
{
	if (!Controller || !CanAct())
	{
		return;
	}

	const FRotationMatrix YawMatrix(FRotator(0.f, Controller->GetControlRotation().Yaw, 0.f));
	AddMovementInput(YawMatrix.GetUnitAxis(EAxis::X), Axis.X);
	AddMovementInput(YawMatrix.GetUnitAxis(EAxis::Y), Axis.Y);
}

void ARPGPlayerCharacter::Look(const FVector2D& Axis)
{
	AddControllerYawInput(Axis.X * LookSensitivity);
	AddControllerPitchInput((bInvertLookY ? Axis.Y : -Axis.Y) * LookSensitivity);
}

void ARPGPlayerCharacter::Zoom(float Axis)
{
	DesiredArmLength = FMath::Clamp(DesiredArmLength - Axis * ZoomStep, MinZoom, MaxZoom);
}

void ARPGPlayerCharacter::SetSprinting(bool bInSprinting)
{
	if (URPGCharacterMovementComponent* Movement = GetRPGMovement())
	{
		Movement->SetWantsToSprint(bInSprinting);
	}
}

ERPGCastResult ARPGPlayerCharacter::UseAbility(int32 Slot)
{
	return AbilitySystem->TryActivateSlot(Slot);
}

void ARPGPlayerCharacter::ComputeAim(float MaxRange, FVector& OutAimLocation, ARPGCharacterBase*& OutTarget) const
{
	OutTarget = nullptr;

	const UWorld* World = GetWorld();
	if (!World || !FollowCamera)
	{
		Super::ComputeAim(MaxRange, OutAimLocation, OutTarget);
		return;
	}

	// Start the ray level with the character so obstacles between the camera and the character are ignored,
	// and measure the range from the character rather than from the camera.
	const FVector CameraLocation = FollowCamera->GetComponentLocation();
	const FVector CameraDirection = FollowCamera->GetForwardVector();
	const float DistanceToCharacter = FMath::Max(0.f, FVector::DotProduct(GetActorLocation() - CameraLocation, CameraDirection));
	const FVector Start = CameraLocation + CameraDirection * DistanceToCharacter;
	const FVector End = Start + CameraDirection * FMath::Max(MaxRange, 100.f);

	FCollisionQueryParams Params(SCENE_QUERY_STAT(RPGPlayerAim), false, this);

	FHitResult WorldHit;
	const bool bHitWorld = World->LineTraceSingleByChannel(WorldHit, Start, End, ECC_Visibility, Params);
	const float WorldHitDistance = bHitWorld ? WorldHit.Distance : TNumericLimits<float>::Max();

	// Soft lock: the closest living hostile near the ray, as long as the world does not block the view of it.
	TArray<FHitResult> PawnHits;
	World->SweepMultiByObjectType(PawnHits, Start, End, FQuat::Identity, FCollisionObjectQueryParams(ECC_Pawn), FCollisionShape::MakeSphere(AimAssistRadius), Params);
	PawnHits.Sort([](const FHitResult& A, const FHitResult& B) { return A.Distance < B.Distance; });

	for (const FHitResult& Hit : PawnHits)
	{
		ARPGCharacterBase* Candidate = Cast<ARPGCharacterBase>(Hit.GetActor());
		if (Candidate && Candidate->IsAlive() && IsHostileTo(Candidate) && Candidate->IsVisibleTo(this) && Hit.Distance <= WorldHitDistance + 100.f)
		{
			OutTarget = Candidate;
			OutAimLocation = Candidate->GetTargetPoint();
			return;
		}
	}

	OutAimLocation = bHitWorld ? WorldHit.ImpactPoint : End;
}

bool ARPGPlayerCharacter::CanJumpInternal_Implementation() const
{
	return Super::CanJumpInternal_Implementation() && CanAct();
}

float ARPGPlayerCharacter::GetDesiredMoveSpeed() const
{
	const URPGCharacterMovementComponent* Movement = GetRPGMovement();
	float Speed = Movement && Movement->WantsToSprint() ? SprintSpeed : BaseMoveSpeed;
	if (Movement && Movement->IsCastSlowed())
	{
		Speed *= CastingSpeedMultiplier;
	}
	return Speed;
}
