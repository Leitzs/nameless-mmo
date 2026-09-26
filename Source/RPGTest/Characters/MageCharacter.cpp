#include "Characters/MageCharacter.h"

#include "Camera/CameraComponent.h"
#include "Components/PointLightComponent.h"
#include "Components/RPGSpellbookComponent.h"
#include "Components/RPGAttributeComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Core/RPGTestGameMode.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/Controller.h"
#include "GameFramework/SpringArmComponent.h"
#include "Spells/MageSpells.h"
#include "UObject/ConstructorHelpers.h"

#define LOCTEXT_NAMESPACE "RPGMage"

namespace MageCharacterPrivate
{
	const FName HeadBone(TEXT("head"));
	const FName RightHandBone(TEXT("hand_r"));
	constexpr float StaffTiltDegrees = 8.f;
	constexpr float StaffLength = 175.f;
	constexpr float StaffGripOffset = 10.f;
}

AMageCharacter::AMageCharacter()
{
	using namespace MageCharacterPrivate;

	Team = ERPGTeam::Player;
	CharacterName = LOCTEXT("MageName", "Mage");
	BodyTint = FLinearColor(0.16f, 0.07f, 0.35f, 1.f);
	BaseMoveSpeed = 480.f;

	static ConstructorHelpers::FObjectFinder<USkeletalMesh> QuinnMesh(RPGAssets::QuinnMesh);
	if (QuinnMesh.Succeeded())
	{
		GetMesh()->SetSkeletalMeshAsset(QuinnMesh.Object);
	}

	Attributes->SetDefaults(300.f, 250.f, 4.f, 12.f);

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

	Spellbook = CreateDefaultSubobject<URPGSpellbookComponent>(TEXT("Spellbook"));
	TArray<TSubclassOf<URPGSpell>> MageSpells;
	MageSpells.Add(USpell_Fireball::StaticClass());
	MageSpells.Add(USpell_FrostNova::StaticClass());
	MageSpells.Add(USpell_LightningStrike::StaticClass());
	MageSpells.Add(USpell_Blink::StaticClass());
	MageSpells.Add(USpell_ArcaneShield::StaticClass());
	Spellbook->SetSpellClasses(MageSpells);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> ConeMesh(RPGAssets::ConeMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> CylinderMesh(RPGAssets::CylinderMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(RPGAssets::SphereMesh);

	HatCone = CreateCosmeticPart(TEXT("HatCone"), ConeMesh.Object, HeadBone);
	HatBrim = CreateCosmeticPart(TEXT("HatBrim"), CylinderMesh.Object, HeadBone);
	HatBand = CreateCosmeticPart(TEXT("HatBand"), CylinderMesh.Object, HeadBone);
	StaffShaft = CreateCosmeticPart(TEXT("StaffShaft"), CylinderMesh.Object, RightHandBone);
	StaffOrb = CreateCosmeticPart(TEXT("StaffOrb"), SphereMesh.Object, RightHandBone);
	StaffOrb->SetCastShadow(false);

	StaffLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("StaffLight"));
	StaffLight->SetupAttachment(StaffOrb);
	StaffLight->SetIntensityUnits(ELightUnits::Candelas);
	StaffLight->SetIntensity(80.f);
	StaffLight->SetAttenuationRadius(500.f);
	StaffLight->SetLightColor(FLinearColor(0.6f, 0.35f, 1.f));
	StaffLight->SetCastShadows(false);
}

void AMageCharacter::BeginPlay()
{
	Super::BeginPlay();
	DesiredArmLength = CameraBoom->TargetArmLength;
}

void AMageCharacter::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	CameraBoom->TargetArmLength = FMath::FInterpTo(CameraBoom->TargetArmLength, DesiredArmLength, DeltaSeconds, 8.f);

	// While casting, keep facing the aim direction instead of turning towards the movement direction.
	GetCharacterMovement()->bOrientRotationToMovement = !Spellbook->IsCasting();
}

void AMageCharacter::Move(const FVector2D& Axis)
{
	if (!Controller || !CanAct())
	{
		return;
	}

	const FRotationMatrix YawMatrix(FRotator(0.f, Controller->GetControlRotation().Yaw, 0.f));
	AddMovementInput(YawMatrix.GetUnitAxis(EAxis::X), Axis.X);
	AddMovementInput(YawMatrix.GetUnitAxis(EAxis::Y), Axis.Y);
}

void AMageCharacter::Look(const FVector2D& Axis)
{
	AddControllerYawInput(Axis.X * LookSensitivity);
	AddControllerPitchInput((bInvertLookY ? Axis.Y : -Axis.Y) * LookSensitivity);
}

void AMageCharacter::Zoom(float Axis)
{
	DesiredArmLength = FMath::Clamp(DesiredArmLength - Axis * ZoomStep, MinZoom, MaxZoom);
}

ERPGCastResult AMageCharacter::CastSpell(int32 SlotIndex)
{
	return Spellbook->TryCast(SlotIndex);
}

FVector AMageCharacter::GetSpellOrigin() const
{
	return StaffOrb && StaffOrb->IsVisible() ? StaffOrb->GetComponentLocation() : Super::GetSpellOrigin();
}

void AMageCharacter::ComputeAim(float MaxRange, FVector& OutAimLocation, ARPGCharacterBase*& OutTarget) const
{
	OutTarget = nullptr;

	const UWorld* World = GetWorld();
	if (!World || !FollowCamera)
	{
		Super::ComputeAim(MaxRange, OutAimLocation, OutTarget);
		return;
	}

	// Start the ray level with the mage so obstacles between the camera and the character are ignored,
	// and measure the range from the mage rather than from the camera.
	const FVector CameraLocation = FollowCamera->GetComponentLocation();
	const FVector CameraDirection = FollowCamera->GetForwardVector();
	const float DistanceToMage = FMath::Max(0.f, FVector::DotProduct(GetActorLocation() - CameraLocation, CameraDirection));
	const FVector Start = CameraLocation + CameraDirection * DistanceToMage;
	const FVector End = Start + CameraDirection * FMath::Max(MaxRange, 100.f);

	FCollisionQueryParams Params(SCENE_QUERY_STAT(RPGMageAim), false, this);

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
		if (Candidate && Candidate->IsAlive() && IsHostileTo(Candidate) && Hit.Distance <= WorldHitDistance + 100.f)
		{
			OutTarget = Candidate;
			OutAimLocation = Candidate->GetTargetPoint();
			return;
		}
	}

	OutAimLocation = bHitWorld ? WorldHit.ImpactPoint : End;
}

bool AMageCharacter::CanJumpInternal_Implementation() const
{
	return Super::CanJumpInternal_Implementation() && CanAct();
}

float AMageCharacter::GetDesiredMoveSpeed() const
{
	float Speed = bSprinting ? SprintSpeed : BaseMoveSpeed;
	if (Spellbook && Spellbook->IsCasting())
	{
		Speed *= CastingSpeedMultiplier;
	}
	return Speed;
}

void AMageCharacter::HandleDeath(AActor* Killer)
{
	Super::HandleDeath(Killer);

	StaffLight->SetVisibility(false);
	if (ARPGTestGameMode* GameMode = GetWorld()->GetAuthGameMode<ARPGTestGameMode>())
	{
		GameMode->NotifyPlayerDied(GetController());
	}
}

void AMageCharacter::AlignCosmetics()
{
	using namespace MageCharacterPrivate;

	// A tall pointed hat sitting on the head, leaning slightly back.
	AlignCosmeticPart(HatBrim, HeadBone, FVector(-1.f, 0.f, 15.f), FRotator(8.f, 0.f, 0.f), FVector(0.62f, 0.62f, 0.025f));
	AlignCosmeticPart(HatBand, HeadBone, FVector(-2.f, 0.f, 19.f), FRotator(8.f, 0.f, 0.f), FVector(0.43f, 0.43f, 0.07f));
	AlignCosmeticPart(HatCone, HeadBone, FVector(-6.f, 0.f, 47.f), FRotator(10.f, 0.f, 0.f), FVector(0.42f, 0.42f, 0.62f));

	// A staff held upright in the right hand with the tip leaning forward.
	const FRotator StaffRotation(-StaffTiltDegrees, 0.f, 0.f);
	const FVector StaffUp = StaffRotation.RotateVector(FVector::UpVector);
	AlignCosmeticPart(StaffShaft, RightHandBone, FVector(0.f, 0.f, StaffGripOffset), StaffRotation, FVector(0.06f, 0.06f, StaffLength / 100.f));
	AlignCosmeticPart(StaffOrb, RightHandBone, FVector(0.f, 0.f, StaffGripOffset) + StaffUp * (StaffLength * 0.5f + 8.f), FRotator::ZeroRotator, FVector(0.18f));
}

void AMageCharacter::ApplyCosmeticMaterials()
{
	const FLinearColor HatColor(0.09f, 0.035f, 0.22f);
	RPGAssets::ApplySurface(HatCone, HatColor, 0.7f);
	RPGAssets::ApplySurface(HatBrim, HatColor, 0.7f);
	RPGAssets::ApplySurface(HatBand, FLinearColor(0.55f, 0.4f, 0.08f), 0.35f);
	RPGAssets::ApplySurface(StaffShaft, FLinearColor(0.12f, 0.07f, 0.035f), 0.75f);
	RPGAssets::ApplySurface(StaffOrb, FLinearColor(0.55f, 0.3f, 1.f), 0.2f, 12.f);
}

#undef LOCTEXT_NAMESPACE
