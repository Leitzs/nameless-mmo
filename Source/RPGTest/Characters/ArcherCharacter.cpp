#include "Characters/ArcherCharacter.h"

#include "Components/SkeletalMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/SkeletalMesh.h"
#include "Spells/ArcherSpells.h"
#include "UObject/ConstructorHelpers.h"

#define LOCTEXT_NAMESPACE "RPGArcher"

AArcherCharacter::AArcherCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	CharacterName = LOCTEXT("ArcherName", "Archer");
	BodyTint = FLinearColor(0.1f, 0.2f, 0.08f, 1.f);
	BaseMoveSpeed = 510.f;
	SprintSpeed = 780.f;

	static ConstructorHelpers::FObjectFinder<USkeletalMesh> MannyMesh(RPGAssets::MannyMesh);
	if (MannyMesh.Succeeded())
	{
		GetMesh()->SetSkeletalMeshAsset(MannyMesh.Object);
	}

	SetClassStats(330.f, 4.f, FRPGResourceConfig::MakeEnergy(100.f, 15.f));

	AbilityClasses = {
		USpell_QuickShot::StaticClass(),
		USpell_AimedShot::StaticClass(),
		USpell_MultiShot::StaticClass(),
		USpell_ConcussiveShot::StaticClass(),
		USpell_Disengage::StaticClass(),
		USpell_RainOfArrows::StaticClass(),
	};

	const FLinearColor Leather(0.28f, 0.17f, 0.08f);
	const FLinearColor Wood(0.4f, 0.24f, 0.1f);
	const FLinearColor Feather(0.2f, 0.45f, 0.15f);

	// A pointed hunter's cap with a feather.
	FRPGCosmeticPart Cap;
	Cap.Name = TEXT("Cap");
	Cap.Shape = ERPGPartShape::Cone;
	Cap.Bone = TEXT("head");
	Cap.Offset = FVector(-3.f, 0.f, 18.f);
	Cap.Rotation = FRotator(-20.f, 0.f, 0.f);
	Cap.Scale = FVector(0.3f, 0.28f, 0.3f);
	Cap.Color = Feather;
	Cap.Roughness = 0.85f;
	AddCosmeticPart(Cap);

	FRPGCosmeticPart CapFeather;
	CapFeather.Name = TEXT("CapFeather");
	CapFeather.Shape = ERPGPartShape::Cylinder;
	CapFeather.Bone = TEXT("head");
	CapFeather.Offset = FVector(-10.f, 8.f, 24.f);
	CapFeather.Rotation = FRotator(-50.f, 0.f, 15.f);
	CapFeather.Scale = FVector(0.02f, 0.06f, 0.3f);
	CapFeather.Color = FLinearColor(0.75f, 0.15f, 0.1f);
	CapFeather.Roughness = 0.9f;
	AddCosmeticPart(CapFeather);

	// A longbow held upright in the left hand: two bent limbs and a string behind the grip.
	FRPGCosmeticPart BowGrip;
	BowGrip.Name = TEXT("BowGrip");
	BowGrip.Shape = ERPGPartShape::Cylinder;
	BowGrip.Bone = TEXT("hand_l");
	BowGrip.Scale = FVector(0.05f, 0.05f, 0.16f);
	BowGrip.Color = Leather;
	BowGrip.Roughness = 0.9f;
	AddCosmeticPart(BowGrip);

	FRPGCosmeticPart BowUpperLimb;
	BowUpperLimb.Name = TEXT("BowUpperLimb");
	BowUpperLimb.Shape = ERPGPartShape::Cylinder;
	BowUpperLimb.Bone = TEXT("hand_l");
	BowUpperLimb.Offset = FVector(-4.f, 0.f, 36.f);
	BowUpperLimb.Rotation = FRotator(12.f, 0.f, 0.f);
	BowUpperLimb.Scale = FVector(0.035f, 0.035f, 0.6f);
	BowUpperLimb.Color = Wood;
	BowUpperLimb.Roughness = 0.6f;
	AddCosmeticPart(BowUpperLimb);

	FRPGCosmeticPart BowLowerLimb = BowUpperLimb;
	BowLowerLimb.Name = TEXT("BowLowerLimb");
	BowLowerLimb.Offset = FVector(-4.f, 0.f, -36.f);
	BowLowerLimb.Rotation = FRotator(-12.f, 0.f, 0.f);
	AddCosmeticPart(BowLowerLimb);

	FRPGCosmeticPart BowString;
	BowString.Name = TEXT("BowString");
	BowString.Shape = ERPGPartShape::Cylinder;
	BowString.Bone = TEXT("hand_l");
	BowString.Offset = FVector(-11.f, 0.f, 0.f);
	BowString.Scale = FVector(0.006f, 0.006f, 1.3f);
	BowString.Color = FLinearColor(0.85f, 0.82f, 0.7f);
	BowString.Roughness = 0.5f;
	AddCosmeticPart(BowString);

	// A quiver on the back, tilted over the right shoulder, with the fletchings sticking out.
	FRPGCosmeticPart Quiver;
	Quiver.Name = TEXT("Quiver");
	Quiver.Shape = ERPGPartShape::Cylinder;
	Quiver.Bone = TEXT("spine_03");
	Quiver.Offset = FVector(-22.f, 0.f, 5.f);
	Quiver.Rotation = FRotator(0.f, 0.f, -25.f);
	Quiver.Scale = FVector(0.13f, 0.13f, 0.55f);
	Quiver.Color = Leather;
	Quiver.Roughness = 0.85f;
	AddCosmeticPart(Quiver);

	FRPGCosmeticPart Fletchings;
	Fletchings.Name = TEXT("Fletchings");
	Fletchings.Shape = ERPGPartShape::Cone;
	Fletchings.Bone = TEXT("spine_03");
	Fletchings.Offset = FVector(-22.f, 13.f, 35.f);
	Fletchings.Rotation = FRotator(0.f, 0.f, -25.f);
	Fletchings.Scale = FVector(0.11f, 0.11f, 0.12f);
	Fletchings.Color = FLinearColor(0.9f, 0.88f, 0.8f);
	Fletchings.Roughness = 0.9f;
	AddCosmeticPart(Fletchings);
}

#undef LOCTEXT_NAMESPACE
