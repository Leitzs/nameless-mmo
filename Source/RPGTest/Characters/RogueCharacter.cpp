#include "Characters/RogueCharacter.h"

#include "Components/SkeletalMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/SkeletalMesh.h"
#include "Spells/RogueSpells.h"
#include "UObject/ConstructorHelpers.h"

#define LOCTEXT_NAMESPACE "RPGRogue"

ARogueCharacter::ARogueCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	CharacterName = LOCTEXT("RogueName", "Rogue");
	BodyTint = FLinearColor(0.05f, 0.05f, 0.06f, 1.f);
	BaseMoveSpeed = 520.f;
	SprintSpeed = 800.f;

	static ConstructorHelpers::FObjectFinder<USkeletalMesh> QuinnMesh(RPGAssets::QuinnMesh);
	if (QuinnMesh.Succeeded())
	{
		GetMesh()->SetSkeletalMeshAsset(QuinnMesh.Object);
	}

	SetClassStats(320.f, 4.f, FRPGResourceConfig::MakeEnergy(100.f, 18.f));

	AbilityClasses = {
		USpell_DaggerSlash::StaticClass(),
		USpell_Stealth::StaticClass(),
		USpell_Backstab::StaticClass(),
		USpell_ThrowingKnife::StaticClass(),
		USpell_KidneyShot::StaticClass(),
		USpell_Shadowstep::StaticClass(),
	};

	const FLinearColor Cloth(0.06f, 0.06f, 0.08f);
	const FLinearColor Blade(0.7f, 0.72f, 0.75f);
	const FLinearColor Hilt(0.25f, 0.2f, 0.15f);

	FRPGCosmeticPart Hood;
	Hood.Name = TEXT("Hood");
	Hood.Shape = ERPGPartShape::Cone;
	Hood.Bone = TEXT("head");
	Hood.Offset = FVector(-4.f, 0.f, 16.f);
	Hood.Rotation = FRotator(-12.f, 0.f, 0.f);
	Hood.Scale = FVector(0.34f, 0.32f, 0.4f);
	Hood.Color = Cloth;
	Hood.Roughness = 0.9f;
	AddCosmeticPart(Hood);

	FRPGCosmeticPart Mask;
	Mask.Name = TEXT("Mask");
	Mask.Bone = TEXT("head");
	Mask.Offset = FVector(9.f, 0.f, 2.f);
	Mask.Scale = FVector(0.04f, 0.17f, 0.08f);
	Mask.Color = FLinearColor(0.25f, 0.05f, 0.05f);
	Mask.Roughness = 0.8f;
	AddCosmeticPart(Mask);

	// A dagger in each hand, points forward.
	AddBladeParts(TEXT("DaggerRight"), TEXT("hand_r"), FVector(0.85f, 0.f, 0.5f), 32.f, 0.045f, Blade, Hilt);
	AddBladeParts(TEXT("DaggerLeft"), TEXT("hand_l"), FVector(0.85f, 0.f, 0.5f), 32.f, 0.045f, Blade, Hilt);
}

#undef LOCTEXT_NAMESPACE
