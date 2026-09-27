#include "Characters/RPGCharacterBase.h"

#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGAttributeSet.h"
#include "Abilities/RPGGameplayAbility.h"
#include "Abilities/RPGGameplayTags.h"
#include "Abilities/RPGStatusEffects.h"
#include "Animation/AnimInstance.h"
#include "Animation/AnimSequenceBase.h"
#include "Characters/RPGCharacterMovementComponent.h"
#include "Combat/RPGCombatLibrary.h"
#include "Components/CapsuleComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Core/RPGTestGameMode.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/Controller.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/PlayerState.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Net/Core/PushModel/PushModel.h"
#include "Net/UnrealNetwork.h"
#include "TimerManager.h"
#include "UI/RPGHUD.h"
#include "UObject/ConstructorHelpers.h"

const FName ARPGCharacterBase::CosmeticTag(TEXT("RPGCosmetic"));

namespace
{
	const FName DefaultSlotName(TEXT("DefaultSlot"));
	const FName PaintTintParameter(TEXT("Paint Tint"));
	const FName IntensityParameter(TEXT("Intensity"));

	/** Overlay priorities of the effects that are not statuses (statuses use RPGStatusEffects). */
	constexpr int32 HitFlashPriority = 80;
	constexpr int32 TelegraphPriority = 60;

	/** Feared characters run a bit slower than normal. */
	constexpr float FearSpeedMultiplier = 0.85f;

	const TCHAR* GetPartMeshPath(ERPGPartShape Shape)
	{
		switch (Shape)
		{
		case ERPGPartShape::Sphere: return RPGAssets::SphereMesh;
		case ERPGPartShape::Cylinder: return RPGAssets::CylinderMesh;
		case ERPGPartShape::Cone: return RPGAssets::ConeMesh;
		default: return RPGAssets::CubeMesh;
		}
	}
}

ARPGCharacterBase::ARPGCharacterBase(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer.SetDefaultSubobjectClass<URPGCharacterMovementComponent>(ACharacter::CharacterMovementComponentName))
{
	PrimaryActorTick.bCanEverTick = true;
	bReplicates = true;
	SetReplicatingMovement(true);

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

	AbilitySystem = CreateDefaultSubobject<URPGAbilitySystemComponent>(TEXT("AbilitySystem"));
	AttributeSet = CreateDefaultSubobject<URPGAttributeSet>(TEXT("AttributeSet"));

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

void ARPGCharacterBase::SetClassStats(float InMaxHealth, float InHealthRegen, const FRPGResourceConfig& InResource)
{
	MaxHealth = InMaxHealth;
	HealthRegen = InHealthRegen;
	ResourceConfig = InResource;
}

UAbilitySystemComponent* ARPGCharacterBase::GetAbilitySystemComponent() const
{
	return AbilitySystem;
}

void ARPGCharacterBase::BeginPlay()
{
	Super::BeginPlay();

	InitAbilitySystem();

	ApplyBodyTint();
	ApplyCosmeticMaterials();
	CreateStatusMaterials();

	// Give the anim blueprint a few frames to settle into its idle pose before attaching cosmetics.
	SetCosmeticsVisible(false);
	GetWorldTimerManager().SetTimer(CosmeticAlignTimer, this, &ThisClass::RunCosmeticAlignment, 0.25f, false);
}

void ARPGCharacterBase::InitAbilitySystem()
{
	AbilitySystem->InitAbilityActorInfo(this, this);
	if (bAbilitySystemInitialized)
	{
		return;
	}
	bAbilitySystemInitialized = true;

	AbilitySystem->InitVitals(MaxHealth, HealthRegen, ResourceConfig);
	AbilitySystem->AddLooseGameplayTags(PassiveTags);
	if (HasAuthority())
	{
		AbilitySystem->GrantSlotAbilities(AbilityClasses);
	}
}

void ARPGCharacterBase::PossessedBy(AController* NewController)
{
	Super::PossessedBy(NewController);
	// The actor info caches the controller (local control, prediction).
	AbilitySystem->InitAbilityActorInfo(this, this);
}

void ARPGCharacterBase::OnRep_Controller()
{
	Super::OnRep_Controller();
	AbilitySystem->InitAbilityActorInfo(this, this);
}

void ARPGCharacterBase::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);
	ApplyBodyTint();
	ApplyCosmeticMaterials();
}

void ARPGCharacterBase::GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const
{
	Super::GetLifetimeReplicatedProps(OutLifetimeProps);

	FDoRepLifetimeParams Params;
	Params.bIsPushBased = true;
	DOREPLIFETIME_WITH_PARAMS_FAST(ARPGCharacterBase, DeathPose, Params);
}

void ARPGCharacterBase::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	UpdateFacing(DeltaSeconds);
	UpdateFearMovement(DeltaSeconds);
	UpdateStatusVisuals(DeltaSeconds);
	UpdateStealthVisibility();
}

// ---------------------------------------------------------------------------------------------------------------------
// State

FString ARPGCharacterBase::GetCombatName() const
{
	const APlayerState* State = GetPlayerState();
	return State ? State->GetPlayerName() : CharacterName.ToString();
}

float ARPGCharacterBase::GetMoveSpeed() const
{
	if (!IsAlive() || !AbilitySystem)
	{
		return 0.f;
	}
	if (HasStatus(RPGTags::Status_CC_Stun) || HasStatus(RPGTags::Status_CC_Freeze))
	{
		return 0.f;
	}

	float Speed = GetDesiredMoveSpeed() * AbilitySystem->GetMoveSpeedMultiplier();
	if (HasStatus(RPGTags::Status_CC_Fear))
	{
		Speed *= FearSpeedMultiplier;
	}
	return Speed;
}

bool ARPGCharacterBase::IsHostileTo(const AActor* Other) const
{
	return URPGCombatLibrary::AreHostile(this, Other);
}

bool ARPGCharacterBase::IsAlive() const
{
	return !bDeathHandled && AttributeSet && AttributeSet->GetHealth() > 0.f;
}

bool ARPGCharacterBase::IsIncapacitated() const
{
	return HasStatus(RPGTags::Status_CC);
}

bool ARPGCharacterBase::HasStatus(const FGameplayTag& Status) const
{
	return AbilitySystem && AbilitySystem->HasMatchingGameplayTag(Status);
}

bool ARPGCharacterBase::IsStealthed() const
{
	return HasStatus(RPGTags::Status_Stealth);
}

bool ARPGCharacterBase::IsVisibleTo(const AActor* Viewer) const
{
	if (!IsStealthed())
	{
		return true;
	}

	const ARPGCharacterBase* ViewerCharacter = Cast<ARPGCharacterBase>(Viewer);
	if (!ViewerCharacter)
	{
		return false;
	}
	if (ViewerCharacter == this || !IsHostileTo(ViewerCharacter))
	{
		return true;
	}
	return FVector::Dist(ViewerCharacter->GetActorLocation(), GetActorLocation()) <= StealthRevealDistance;
}

float ARPGCharacterBase::GetHealth() const
{
	return AttributeSet ? AttributeSet->GetHealth() : 0.f;
}

float ARPGCharacterBase::GetMaxHealth() const
{
	return AttributeSet ? AttributeSet->GetMaxHealth() : 1.f;
}

float ARPGCharacterBase::GetResource() const
{
	return AttributeSet ? AttributeSet->GetResource() : 0.f;
}

float ARPGCharacterBase::GetMaxResource() const
{
	return AttributeSet ? AttributeSet->GetMaxResource() : 0.f;
}

float ARPGCharacterBase::GetShield() const
{
	return AttributeSet ? AttributeSet->GetShield() : 0.f;
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

// ---------------------------------------------------------------------------------------------------------------------
// Combat feedback

void ARPGCharacterBase::NotifyDamageTaken(float HealthDamage, float AbsorbedDamage, AActor* InstigatorActor, const FGameplayTag& DamageType)
{
	MulticastDamageFeedback(HealthDamage, AbsorbedDamage, DamageType);
	OnDamageTaken(HealthDamage, AbsorbedDamage, InstigatorActor);
}

void ARPGCharacterBase::NotifyHealed(float Amount)
{
	if (Amount >= 0.5f)
	{
		MulticastHealFeedback(Amount);
	}
}

void ARPGCharacterBase::ShowCombatText(const FText& Text, const FLinearColor& Color)
{
	if (HasAuthority())
	{
		MulticastCombatText(Text, Color);
	}
}

void ARPGCharacterBase::MulticastDamageFeedback_Implementation(float HealthDamage, float AbsorbedDamage, FGameplayTag DamageType)
{
	if (GetNetMode() == NM_DedicatedServer)
	{
		return;
	}

	if (HealthDamage > 0.f)
	{
		HitFlashRemaining = 0.12f;
	}

	const bool bLocalPlayerWasHit = IsLocallyControlled() && IsPlayerControlled();
	ARPGHUD::NotifyDamage(this, GetActorLocation() + FVector(0.f, 0.f, 110.f), HealthDamage, AbsorbedDamage, RPGTags::GetDamageTypeColor(DamageType), bLocalPlayerWasHit);
}

void ARPGCharacterBase::MulticastHealFeedback_Implementation(float Amount)
{
	if (GetNetMode() != NM_DedicatedServer)
	{
		ARPGHUD::NotifyText(this, GetActorLocation() + FVector(0.f, 0.f, 120.f), FString::Printf(TEXT("+%d"), FMath::RoundToInt(Amount)), FLinearColor(0.35f, 1.f, 0.4f), 0.9f);
	}
}

void ARPGCharacterBase::MulticastCombatText_Implementation(const FText& Text, FLinearColor Color)
{
	if (GetNetMode() != NM_DedicatedServer)
	{
		ARPGHUD::NotifyText(this, GetActorLocation() + FVector(0.f, 0.f, 140.f), Text.ToString(), Color, 0.75f);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Animation and movement helpers

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

void ARPGCharacterBase::PlayActionAnimationForAll(UAnimSequenceBase* Animation, float PlayRate)
{
	// The controlling machine plays it right away; the multicast skips it (see the implementation).
	if (IsLocallyControlled())
	{
		PlayActionAnimation(Animation, PlayRate);
	}
	if (HasAuthority() && Animation)
	{
		MulticastPlayActionAnimation(Animation, PlayRate);
	}
}

void ARPGCharacterBase::StopActionAnimationForAll(float BlendOutTime)
{
	if (IsLocallyControlled())
	{
		StopActionAnimation(BlendOutTime);
	}
	if (HasAuthority())
	{
		MulticastStopActionAnimation(BlendOutTime);
	}
}

void ARPGCharacterBase::MulticastPlayActionAnimation_Implementation(UAnimSequenceBase* Animation, float PlayRate)
{
	if (!IsLocallyControlled() && GetNetMode() != NM_DedicatedServer)
	{
		PlayActionAnimation(Animation, PlayRate);
	}
}

void ARPGCharacterBase::MulticastStopActionAnimation_Implementation(float BlendOutTime)
{
	if (!IsLocallyControlled())
	{
		StopActionAnimation(BlendOutTime);
	}
}

void ARPGCharacterBase::SetTelegraphGlow(float Duration)
{
	TelegraphRemaining = Duration;
	if (HasAuthority() && GetNetMode() != NM_Standalone)
	{
		MulticastTelegraphGlow(Duration);
	}
}

void ARPGCharacterBase::MulticastTelegraphGlow_Implementation(float Duration)
{
	TelegraphRemaining = Duration;
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

void ARPGCharacterBase::UpdateFearMovement(float DeltaSeconds)
{
	const bool bNowFeared = IsAlive() && HasStatus(RPGTags::Status_CC_Fear);
	if (!bNowFeared)
	{
		bFeared = false;
		return;
	}

	// Whoever drives this character's movement (the owning player, or the server for bots) makes it run.
	if (!IsLocallyControlled())
	{
		return;
	}

	if (!bFeared)
	{
		bFeared = true;
		FearDirection = FVector(FMath::RandPointInCircle(1.f), 0.f).GetSafeNormal();
		if (FearDirection.IsNearlyZero())
		{
			FearDirection = -GetActorForwardVector();
		}
		FearTurnTimer = 0.6f;
	}

	FearTurnTimer -= DeltaSeconds;
	if (FearTurnTimer <= 0.f)
	{
		// Panic: wander, and turn around when running into a wall.
		const bool bStuck = GetVelocity().Size2D() < 50.f;
		FearDirection = FearDirection.RotateAngleAxis(bStuck ? FMath::FRandRange(120.f, 240.f) : FMath::FRandRange(-60.f, 60.f), FVector::UpVector);
		FearTurnTimer = FMath::FRandRange(0.5f, 0.9f);
	}

	AddMovementInput(FearDirection, 1.f);
}

void ARPGCharacterBase::OnIncapacitatedChanged(bool bIncapacitated)
{
	if (bIncapacitated && IsAlive())
	{
		GetCharacterMovement()->StopMovementImmediately();
		StopActionAnimation(0.1f);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Death

void ARPGCharacterBase::NotifyKilled(AActor* Killer)
{
	// Only the server applies damage, so this only runs there. Clients die through OnRep_DeathPose.
	if (bDeathHandled)
	{
		return;
	}

	DeathPose = static_cast<uint8>(DeathAnimations.Num() > 0 ? FMath::RandRange(1, DeathAnimations.Num()) : 1);
	MARK_PROPERTY_DIRTY_FROM_NAME(ARPGCharacterBase, DeathPose, this);
	ApplyDeath(Killer);

	if (ARPGTestGameMode* GameMode = GetWorld()->GetAuthGameMode<ARPGTestGameMode>())
	{
		GameMode->NotifyCharacterDied(this, Killer);
	}
}

void ARPGCharacterBase::OnRep_DeathPose()
{
	if (DeathPose > 0)
	{
		ApplyDeath(nullptr);
	}
}

void ARPGCharacterBase::ApplyDeath(AActor* Killer)
{
	if (bDeathHandled)
	{
		return;
	}

	bDeathHandled = true;
	HandleDeath(Killer);
}

void ARPGCharacterBase::HandleDeath(AActor* Killer)
{
	AbilitySystem->AddLooseGameplayTag(RPGTags::State_Dead);
	if (HasAuthority())
	{
		AbilitySystem->CancelAllAbilities();
		AbilitySystem->RemoveStatuses(FGameplayTagContainer(RPGTags::Status));
	}
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
	SkeletalMesh->SetVisibility(true, true);
	bHiddenByStealth = false;
	ShieldBubble->SetVisibility(false);

	const int32 DeathAnimationIndex = static_cast<int32>(DeathPose) - 1;
	if (DeathAnimations.IsValidIndex(DeathAnimationIndex))
	{
		if (UAnimSequenceBase* DeathAnimation = DeathAnimations[DeathAnimationIndex])
		{
			SkeletalMesh->PlayAnimation(DeathAnimation, false);
		}
	}

	if (AController* OwningController = GetController())
	{
		OwningController->StopMovement();
	}

	// The server removes the body; clients follow when the actor is destroyed there.
	if (CorpseLifeSpan > 0.f && HasAuthority())
	{
		SetLifeSpan(CorpseLifeSpan);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Cosmetics

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

UStaticMeshComponent* ARPGCharacterBase::AddCosmeticPart(const FRPGCosmeticPart& Part)
{
	ConstructorHelpers::FObjectFinder<UStaticMesh> PartMesh(GetPartMeshPath(Part.Shape));
	UStaticMeshComponent* Component = CreateCosmeticPart(Part.Name, PartMesh.Object, Part.Bone);
	CosmeticPartSpecs.Add(Part);
	CosmeticPartComponents.Add(Component);
	return Component;
}

void ARPGCharacterBase::AddBladeParts(const FString& Prefix, FName Bone, const FVector& Direction, float BladeLength, float BladeWidth, const FLinearColor& BladeColor, const FLinearColor& HiltColor)
{
	const FVector Along = Direction.GetSafeNormal();
	const FRotator Rotation = FRotationMatrix::MakeFromZY(Along, FVector::RightVector).Rotator();
	const float GripLength = FMath::Clamp(BladeLength * 0.22f, 10.f, 22.f);

	FRPGCosmeticPart Grip;
	Grip.Name = *(Prefix + TEXT("Grip"));
	Grip.Shape = ERPGPartShape::Cylinder;
	Grip.Bone = Bone;
	Grip.Offset = Along * 2.f;
	Grip.Rotation = Rotation;
	Grip.Scale = FVector(0.035f, 0.035f, GripLength / 100.f);
	Grip.Color = FLinearColor(0.1f, 0.05f, 0.03f);
	Grip.Roughness = 0.8f;
	AddCosmeticPart(Grip);

	FRPGCosmeticPart Guard;
	Guard.Name = *(Prefix + TEXT("Guard"));
	Guard.Bone = Bone;
	Guard.Offset = Along * (GripLength * 0.5f + 3.f);
	Guard.Rotation = Rotation;
	Guard.Scale = FVector(0.05f, FMath::Max(0.12f, BladeWidth * 3.5f), 0.04f);
	Guard.Color = HiltColor;
	Guard.Roughness = 0.4f;
	AddCosmeticPart(Guard);

	FRPGCosmeticPart Blade;
	Blade.Name = *(Prefix + TEXT("Blade"));
	Blade.Bone = Bone;
	Blade.Offset = Along * (GripLength * 0.5f + 4.f + BladeLength * 0.5f);
	Blade.Rotation = Rotation;
	Blade.Scale = FVector(0.02f, BladeWidth, BladeLength / 100.f);
	Blade.Color = BladeColor;
	Blade.Roughness = 0.25f;
	AddCosmeticPart(Blade);
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

void ARPGCharacterBase::AlignCosmetics()
{
	for (int32 Index = 0; Index < CosmeticPartSpecs.Num() && Index < CosmeticPartComponents.Num(); ++Index)
	{
		const FRPGCosmeticPart& Spec = CosmeticPartSpecs[Index];
		AlignCosmeticPart(CosmeticPartComponents[Index], Spec.Bone, Spec.Offset, Spec.Rotation, Spec.Scale);
	}
}

void ARPGCharacterBase::ApplyCosmeticMaterials()
{
	for (int32 Index = 0; Index < CosmeticPartSpecs.Num() && Index < CosmeticPartComponents.Num(); ++Index)
	{
		const FRPGCosmeticPart& Spec = CosmeticPartSpecs[Index];
		RPGAssets::ApplySurface(CosmeticPartComponents[Index], Spec.Color, Spec.Roughness, Spec.Emissive);
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
	SetCosmeticsVisible(!bHiddenByStealth);
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

// ---------------------------------------------------------------------------------------------------------------------
// Status visuals

void ARPGCharacterBase::CreateStatusMaterials()
{
	for (const FRPGStatusDefinition& Definition : RPGStatusEffects::GetDefinitions())
	{
		if (Definition.OverlayPriority > 0)
		{
			StatusOverlays.Add(Definition.Tag, RPGAssets::CreateFXMaterial(this, Definition.Color, Definition.OverlayIntensity, Definition.OverlayFresnel));
		}
	}

	HitOverlay = RPGAssets::CreateFXMaterial(this, FLinearColor::White, 2.5f, 0.6f);
	TelegraphOverlay = RPGAssets::CreateFXMaterial(this, FLinearColor(1.f, 0.1f, 0.05f), 3.f, 0.8f);
	StealthOverlay = RPGAssets::CreateFXMaterial(this, FLinearColor(0.35f, 0.4f, 0.6f), 1.2f, 1.f);
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

	// The highest-priority effect wins the overlay slot.
	UMaterialInstanceDynamic* DesiredOverlay = nullptr;
	int32 BestPriority = 0;
	for (const FRPGStatusDefinition& Definition : RPGStatusEffects::GetDefinitions())
	{
		if (Definition.OverlayPriority > BestPriority && HasStatus(Definition.Tag))
		{
			if (UMaterialInstanceDynamic* Overlay = StatusOverlays.FindRef(Definition.Tag))
			{
				DesiredOverlay = Overlay;
				BestPriority = Definition.OverlayPriority;
				if (Definition.DamageOverTimeType.IsValid())
				{
					Overlay->SetScalarParameterValue(IntensityParameter, Definition.OverlayIntensity * (0.8f + FMath::PerlinNoise1D(Time * 6.f) * 0.8f));
				}
			}
		}
	}
	if (HitFlashRemaining > 0.f && HitFlashPriority > BestPriority)
	{
		DesiredOverlay = HitOverlay;
		BestPriority = HitFlashPriority;
	}
	if (TelegraphRemaining > 0.f && TelegraphPriority > BestPriority && TelegraphOverlay)
	{
		DesiredOverlay = TelegraphOverlay;
		TelegraphOverlay->SetScalarParameterValue(IntensityParameter, 2.5f + 2.f * FMath::Sin(Time * 25.f));
	}
	if (IsStealthed() && StealthOverlay)
	{
		// Stealth overrides everything else: a faint shimmer, stronger for enemies who spotted it up close.
		DesiredOverlay = StealthOverlay;
		StealthOverlay->SetScalarParameterValue(IntensityParameter, 0.8f + 0.4f * FMath::Sin(Time * 5.f));
	}

	USkeletalMeshComponent* SkeletalMesh = GetMesh();
	if (SkeletalMesh->GetOverlayMaterial() != DesiredOverlay)
	{
		SkeletalMesh->SetOverlayMaterial(DesiredOverlay);
	}

	const bool bShowShield = GetShield() > 0.f && !bHiddenByStealth;
	if (ShieldBubble->IsVisible() != bShowShield)
	{
		ShieldBubble->SetVisibility(bShowShield);
	}
	if (bShowShield && ShieldBubbleMaterial)
	{
		ShieldBubbleMaterial->SetScalarParameterValue(IntensityParameter, 0.9f + 0.4f * FMath::Sin(Time * 4.f));
	}

	// Frozen characters hold their pose.
	const float AnimRate = HasStatus(RPGTags::Status_CC_Freeze) ? 0.f : 1.f;
	if (SkeletalMesh->GlobalAnimRateScale != AnimRate)
	{
		SkeletalMesh->GlobalAnimRateScale = AnimRate;
	}
}

void ARPGCharacterBase::UpdateStealthVisibility()
{
	if (GetNetMode() == NM_DedicatedServer || !IsAlive())
	{
		return;
	}

	// Rendering is per machine: hide the character from the local player when it is a stealthed enemy out of reveal range.
	bool bHide = false;
	if (IsStealthed() && !IsLocallyControlled())
	{
		const APlayerController* LocalController = GetWorld()->GetFirstPlayerController();
		const APawn* Viewer = LocalController ? LocalController->GetPawn() : nullptr;
		bHide = !IsVisibleTo(Viewer);
	}

	if (bHide != bHiddenByStealth)
	{
		bHiddenByStealth = bHide;
		GetMesh()->SetVisibility(!bHide, true);
	}
}
