#include "Characters/RPGCharacterBase.h"

#include "Animation/AnimInstance.h"
#include "Animation/AnimSequenceBase.h"
#include "Combat/RPGCombatLibrary.h"
#include "Combat/RPGDamageTypes.h"
#include "Components/CapsuleComponent.h"
#include "Components/RPGAttributeComponent.h"
#include "Components/RPGStatusEffectComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/DamageEvents.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/Controller.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "TimerManager.h"
#include "UI/RPGHUD.h"
#include "UObject/ConstructorHelpers.h"

const FName ARPGCharacterBase::CosmeticTag(TEXT("RPGCosmetic"));

namespace
{
	const FName DefaultSlotName(TEXT("DefaultSlot"));
	const FName PaintTintParameter(TEXT("Paint Tint"));
	const FName IntensityParameter(TEXT("Intensity"));
}

ARPGCharacterBase::ARPGCharacterBase()
{
	PrimaryActorTick.bCanEverTick = true;

	GetCapsuleComponent()->InitCapsuleSize(42.f, 96.f);

	bUseControllerRotationPitch = false;
	bUseControllerRotationYaw = false;
	bUseControllerRotationRoll = false;

	UCharacterMovementComponent* Movement = GetCharacterMovement();
	Movement->bOrientRotationToMovement = true;
	Movement->RotationRate = FRotator(0.f, 600.f, 0.f);
	Movement->JumpZVelocity = 520.f;
	Movement->AirControl = 0.35f;
	Movement->MaxWalkSpeed = BaseMoveSpeed;
	Movement->MinAnalogWalkSpeed = 20.f;
	Movement->BrakingDecelerationWalking = 2000.f;
	Movement->BrakingDecelerationFalling = 1500.f;

	static ConstructorHelpers::FObjectFinder<USkeletalMesh> MannyMesh(RPGAssets::MannyMesh);
	static ConstructorHelpers::FClassFinder<UAnimInstance> UnarmedAnimClass(RPGAssets::UnarmedAnimBlueprint);

	USkeletalMeshComponent* SkeletalMesh = GetMesh();
	if (MannyMesh.Succeeded())
	{
		SkeletalMesh->SetSkeletalMeshAsset(MannyMesh.Object);
	}
	if (UnarmedAnimClass.Succeeded())
	{
		SkeletalMesh->SetAnimInstanceClass(UnarmedAnimClass.Class);
	}
	SkeletalMesh->SetRelativeLocationAndRotation(FVector(0.f, 0.f, -96.f), FRotator(0.f, -90.f, 0.f));
	// Cosmetic parts are aligned from the evaluated pose, so bones must update even when off screen.
	SkeletalMesh->VisibilityBasedAnimTickOption = EVisibilityBasedAnimTickOption::AlwaysTickPoseAndRefreshBones;

	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> DeathFront(TEXT("/Game/Characters/Mannequins/Anims/Death/MM_Death_Front_01.MM_Death_Front_01"));
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> DeathFront2(TEXT("/Game/Characters/Mannequins/Anims/Death/MM_Death_Front_02.MM_Death_Front_02"));
	static ConstructorHelpers::FObjectFinder<UAnimSequenceBase> DeathBack(TEXT("/Game/Characters/Mannequins/Anims/Death/MM_Death_Back_01.MM_Death_Back_01"));
	for (UAnimSequenceBase* Animation : { DeathFront.Object.Get(), DeathFront2.Object.Get(), DeathBack.Object.Get() })
	{
		if (Animation)
		{
			DeathAnimations.Add(Animation);
		}
	}

	Attributes = CreateDefaultSubobject<URPGAttributeComponent>(TEXT("Attributes"));
	StatusEffects = CreateDefaultSubobject<URPGStatusEffectComponent>(TEXT("StatusEffects"));

	static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(RPGAssets::SphereMesh);
	ShieldBubble = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("ShieldBubble"));
	ShieldBubble->SetupAttachment(GetCapsuleComponent());
	ShieldBubble->SetStaticMesh(SphereMesh.Object);
	ShieldBubble->SetRelativeScale3D(FVector(2.2f, 2.2f, 2.4f));
	ShieldBubble->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	ShieldBubble->SetGenerateOverlapEvents(false);
	ShieldBubble->SetCanEverAffectNavigation(false);
	ShieldBubble->SetCastShadow(false);
	ShieldBubble->SetVisibility(false);
}

void ARPGCharacterBase::BeginPlay()
{
	Super::BeginPlay();

	Attributes->OnDamaged.AddDynamic(this, &ThisClass::HandleAttributesDamaged);
	Attributes->OnDeath.AddDynamic(this, &ThisClass::HandleAttributesDeath);
	StatusEffects->OnStatusChanged.AddDynamic(this, &ThisClass::HandleStatusChanged);

	ApplyBodyTint();
	ApplyCosmeticMaterials();
	CreateStatusMaterials();
	UpdateMovementSpeed();

	// Give the anim blueprint a few frames to settle into its idle pose before attaching cosmetics.
	SetCosmeticsVisible(false);
	GetWorldTimerManager().SetTimer(CosmeticAlignTimer, this, &ThisClass::RunCosmeticAlignment, 0.25f, false);
}

void ARPGCharacterBase::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	ApplyBodyTint();
	ApplyCosmeticMaterials();
}

void ARPGCharacterBase::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	UpdateMovementSpeed();
	UpdateFacing(DeltaSeconds);
	UpdateStatusVisuals(DeltaSeconds);
}

float ARPGCharacterBase::TakeDamage(float DamageAmount, FDamageEvent const& DamageEvent, AController* EventInstigator, AActor* DamageCauser)
{
	if (!IsAlive() || DamageAmount <= 0.f)
	{
		return 0.f;
	}

	AActor* InstigatorActor = URPGCombatLibrary::ResolveInstigator(EventInstigator, DamageCauser);
	if (InstigatorActor && InstigatorActor != this && !IsHostileTo(InstigatorActor))
	{
		return 0.f;
	}

	const float Amount = Super::TakeDamage(DamageAmount, DamageEvent, EventInstigator, DamageCauser);
	if (Amount <= 0.f)
	{
		return 0.f;
	}

	const float Absorbed = FMath::Min(Attributes->GetShield(), Amount);
	const float HealthDamage = Attributes->ApplyDamage(Amount, InstigatorActor);

	const URPGDamageType* DamageTypeCDO = DamageEvent.DamageTypeClass ? Cast<URPGDamageType>(DamageEvent.DamageTypeClass->GetDefaultObject()) : nullptr;
	const FLinearColor Color = DamageTypeCDO ? DamageTypeCDO->DisplayColor : FLinearColor::White;
	ARPGHUD::NotifyDamage(this, GetActorLocation() + FVector(0.f, 0.f, 110.f), HealthDamage, Absorbed, Color, Team == ERPGTeam::Player);

	return HealthDamage;
}

bool ARPGCharacterBase::IsHostileTo(const AActor* Other) const
{
	return URPGCombatLibrary::AreHostile(this, Other);
}

bool ARPGCharacterBase::IsAlive() const
{
	return !bDeathHandled && Attributes && Attributes->IsAlive();
}

bool ARPGCharacterBase::IsIncapacitated() const
{
	return StatusEffects && StatusEffects->IsIncapacitated();
}

FVector ARPGCharacterBase::GetTargetPoint() const
{
	return GetActorLocation() + FVector(0.f, 0.f, 40.f);
}

FVector ARPGCharacterBase::GetSpellOrigin() const
{
	return GetActorLocation() + GetActorForwardVector() * 60.f + FVector(0.f, 0.f, 40.f);
}

void ARPGCharacterBase::ComputeAim(float MaxRange, FVector& OutAimLocation, ARPGCharacterBase*& OutTarget) const
{
	OutAimLocation = GetTargetPoint() + GetActorForwardVector() * MaxRange;
	OutTarget = nullptr;
}

float ARPGCharacterBase::PlayActionAnimation(UAnimSequenceBase* Animation, float PlayRate)
{
	UAnimInstance* AnimInstance = GetMesh() ? GetMesh()->GetAnimInstance() : nullptr;
	if (!Animation || !AnimInstance || PlayRate <= 0.f)
	{
		return 0.f;
	}

	const UAnimMontage* Montage = AnimInstance->PlaySlotAnimationAsDynamicMontage(Animation, DefaultSlotName, 0.1f, 0.2f, PlayRate);
	return Montage ? Animation->GetPlayLength() / PlayRate : 0.f;
}

void ARPGCharacterBase::StopActionAnimation(float BlendOutTime)
{
	if (UAnimInstance* AnimInstance = GetMesh() ? GetMesh()->GetAnimInstance() : nullptr)
	{
		AnimInstance->Montage_Stop(BlendOutTime);
	}
}

void ARPGCharacterBase::FaceLocation(const FVector& Location, bool bInstant)
{
	FVector Direction = Location - GetActorLocation();
	Direction.Z = 0.f;
	if (Direction.IsNearlyZero())
	{
		return;
	}

	DesiredFacing = Direction.Rotation();
	if (bInstant)
	{
		SetActorRotation(DesiredFacing);
		bHasDesiredFacing = false;
	}
	else
	{
		bHasDesiredFacing = true;
	}
}

void ARPGCharacterBase::ApplyKnockback(const FVector& Direction, float Strength, float UpStrength)
{
	if (IsAlive())
	{
		LaunchCharacter(Direction.GetSafeNormal2D() * Strength + FVector(0.f, 0.f, UpStrength), true, true);
	}
}

void ARPGCharacterBase::HandleDeath(AActor* Killer)
{
	StatusEffects->ClearAll();
	StopActionAnimation(0.1f);
	TelegraphRemaining = 0.f;

	UCharacterMovementComponent* Movement = GetCharacterMovement();
	Movement->StopMovementImmediately();
	Movement->DisableMovement();

	// Keep standing on the ground but stop blocking pawns, projectiles, cameras and aim traces.
	UCapsuleComponent* Capsule = GetCapsuleComponent();
	Capsule->SetCollisionResponseToChannel(ECC_Pawn, ECR_Ignore);
	Capsule->SetCollisionResponseToChannel(ECC_WorldDynamic, ECR_Ignore);
	Capsule->SetCollisionResponseToChannel(ECC_Camera, ECR_Ignore);
	Capsule->SetCollisionResponseToChannel(ECC_Visibility, ECR_Ignore);

	USkeletalMeshComponent* SkeletalMesh = GetMesh();
	SkeletalMesh->SetOverlayMaterial(nullptr);
	SkeletalMesh->GlobalAnimRateScale = 1.f;
	ShieldBubble->SetVisibility(false);

	if (DeathAnimations.Num() > 0)
	{
		if (UAnimSequenceBase* DeathAnimation = DeathAnimations[FMath::RandRange(0, DeathAnimations.Num() - 1)])
		{
			SkeletalMesh->PlayAnimation(DeathAnimation, false);
		}
	}

	if (AController* OwningController = GetController())
	{
		OwningController->StopMovement();
	}

	if (CorpseLifeSpan > 0.f)
	{
		SetLifeSpan(CorpseLifeSpan);
	}
}

UStaticMeshComponent* ARPGCharacterBase::CreateCosmeticPart(FName Name, UStaticMesh* PartMesh, FName Bone)
{
	UStaticMeshComponent* Part = CreateDefaultSubobject<UStaticMeshComponent>(Name);
	Part->SetupAttachment(GetMesh(), Bone);
	Part->SetStaticMesh(PartMesh);
	Part->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Part->SetGenerateOverlapEvents(false);
	Part->SetCanEverAffectNavigation(false);
	Part->bReceivesDecals = false;
	Part->ComponentTags.Add(CosmeticTag);
	return Part;
}

void ARPGCharacterBase::AlignCosmeticPart(UStaticMeshComponent* Part, FName Bone, const FVector& Offset, const FRotator& Rotation, const FVector& Scale) const
{
	if (!Part || !GetMesh())
	{
		return;
	}

	const FTransform BoneTransform = GetMesh()->GetSocketTransform(Bone, RTS_World);
	const FQuat ActorRotation = GetActorQuat();
	const FTransform Desired(ActorRotation * Rotation.Quaternion(), BoneTransform.GetLocation() + ActorRotation.RotateVector(Offset), Scale);
	Part->SetRelativeTransform(Desired.GetRelativeTransform(BoneTransform));
}

void ARPGCharacterBase::ApplyCosmeticMaterials()
{
}

void ARPGCharacterBase::HandleAttributesDamaged(URPGAttributeComponent* InAttributes, float HealthDamage, float AbsorbedDamage, AActor* InstigatorActor)
{
	if (HealthDamage > 0.f)
	{
		HitFlashRemaining = 0.12f;
	}
	OnDamageTaken(HealthDamage, AbsorbedDamage, InstigatorActor);
}

void ARPGCharacterBase::HandleAttributesDeath(AActor* Killer)
{
	if (bDeathHandled)
	{
		return;
	}

	bDeathHandled = true;
	HandleDeath(Killer);
}

void ARPGCharacterBase::HandleStatusChanged()
{
	if (IsAlive() && IsIncapacitated())
	{
		GetCharacterMovement()->StopMovementImmediately();
		StopActionAnimation(0.1f);
	}
}

void ARPGCharacterBase::SetCosmeticsVisible(bool bVisible)
{
	TArray<UStaticMeshComponent*> Parts;
	GetComponents<UStaticMeshComponent>(Parts);
	for (UStaticMeshComponent* Part : Parts)
	{
		if (Part->ComponentHasTag(CosmeticTag))
		{
			Part->SetVisibility(bVisible);
		}
	}
}

void ARPGCharacterBase::RunCosmeticAlignment()
{
	AlignCosmetics();
	SetCosmeticsVisible(true);
}

void ARPGCharacterBase::ApplyBodyTint()
{
	USkeletalMeshComponent* SkeletalMesh = GetMesh();
	if (BodyTint.A <= 0.f || !SkeletalMesh)
	{
		return;
	}

	for (int32 Index = 0; Index < SkeletalMesh->GetNumMaterials(); ++Index)
	{
		if (UMaterialInstanceDynamic* MID = SkeletalMesh->CreateAndSetMaterialInstanceDynamic(Index))
		{
			MID->SetVectorParameterValue(PaintTintParameter, FLinearColor(BodyTint.R, BodyTint.G, BodyTint.B, 1.f));
		}
	}
}

void ARPGCharacterBase::CreateStatusMaterials()
{
	FrozenOverlay = RPGAssets::CreateFXMaterial(this, FLinearColor(0.3f, 0.75f, 1.f), 3.f, 0.85f);
	BurningOverlay = RPGAssets::CreateFXMaterial(this, FLinearColor(1.f, 0.35f, 0.05f), 2.5f, 0.9f);
	ShieldOverlay = RPGAssets::CreateFXMaterial(this, FLinearColor(0.6f, 0.3f, 1.f), 1.5f, 1.f);
	HitOverlay = RPGAssets::CreateFXMaterial(this, FLinearColor::White, 2.5f, 0.6f);
	TelegraphOverlay = RPGAssets::CreateFXMaterial(this, FLinearColor(1.f, 0.1f, 0.05f), 3.f, 0.8f);
	ShieldBubbleMaterial = RPGAssets::CreateFXMaterial(this, FLinearColor(0.55f, 0.3f, 1.f), 1.2f, 1.f);
	if (ShieldBubbleMaterial)
	{
		ShieldBubble->SetMaterial(0, ShieldBubbleMaterial);
	}
}

void ARPGCharacterBase::UpdateStatusVisuals(float DeltaSeconds)
{
	HitFlashRemaining = FMath::Max(0.f, HitFlashRemaining - DeltaSeconds);
	TelegraphRemaining = FMath::Max(0.f, TelegraphRemaining - DeltaSeconds);

	if (!IsAlive())
	{
		return;
	}

	const float Time = GetWorld()->GetTimeSeconds();

	UMaterialInterface* DesiredOverlay = nullptr;
	if (StatusEffects->IsFrozen())
	{
		DesiredOverlay = FrozenOverlay;
	}
	else if (HitFlashRemaining > 0.f)
	{
		DesiredOverlay = HitOverlay;
	}
	else if (TelegraphRemaining > 0.f)
	{
		DesiredOverlay = TelegraphOverlay;
		if (TelegraphOverlay)
		{
			TelegraphOverlay->SetScalarParameterValue(IntensityParameter, 2.5f + 2.f * FMath::Sin(Time * 25.f));
		}
	}
	else if (StatusEffects->IsBurning())
	{
		DesiredOverlay = BurningOverlay;
		if (BurningOverlay)
		{
			BurningOverlay->SetScalarParameterValue(IntensityParameter, 2.f + FMath::PerlinNoise1D(Time * 6.f) * 2.f);
		}
	}
	else if (Attributes->GetShield() > 0.f)
	{
		DesiredOverlay = ShieldOverlay;
	}

	USkeletalMeshComponent* SkeletalMesh = GetMesh();
	if (SkeletalMesh->GetOverlayMaterial() != DesiredOverlay)
	{
		SkeletalMesh->SetOverlayMaterial(DesiredOverlay);
	}

	const bool bShowShield = Attributes->GetShield() > 0.f;
	if (ShieldBubble->IsVisible() != bShowShield)
	{
		ShieldBubble->SetVisibility(bShowShield);
	}
	if (bShowShield && ShieldBubbleMaterial)
	{
		ShieldBubbleMaterial->SetScalarParameterValue(IntensityParameter, 0.9f + 0.4f * FMath::Sin(Time * 4.f));
	}

	// Frozen characters hold their pose.
	const float AnimRate = StatusEffects->IsFrozen() ? 0.f : 1.f;
	if (SkeletalMesh->GlobalAnimRateScale != AnimRate)
	{
		SkeletalMesh->GlobalAnimRateScale = AnimRate;
	}
}

void ARPGCharacterBase::UpdateMovementSpeed()
{
	const float Speed = IsAlive() ? GetDesiredMoveSpeed() * StatusEffects->GetSpeedMultiplier() : 0.f;
	GetCharacterMovement()->MaxWalkSpeed = Speed;
}

void ARPGCharacterBase::UpdateFacing(float DeltaSeconds)
{
	if (!bHasDesiredFacing || !CanAct())
	{
		return;
	}

	const FRotator NewRotation = FMath::RInterpConstantTo(GetActorRotation(), DesiredFacing, DeltaSeconds, 720.f);
	SetActorRotation(NewRotation);
	if (NewRotation.Equals(DesiredFacing, 1.f))
	{
		bHasDesiredFacing = false;
	}
}
