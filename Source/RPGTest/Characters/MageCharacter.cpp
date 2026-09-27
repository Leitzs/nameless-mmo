#include "Characters/MageCharacter.h"

#include "Components/PointLightComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/StaticMesh.h"
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

AMageCharacter::AMageCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	using namespace MageCharacterPrivate;

	CharacterName = LOCTEXT("MageName", "Mage");
	BodyTint = FLinearColor(0.16f, 0.07f, 0.35f, 1.f);
	BaseMoveSpeed = 480.f;

	static ConstructorHelpers::FObjectFinder<USkeletalMesh> QuinnMesh(RPGAssets::QuinnMesh);
	if (QuinnMesh.Succeeded())
	{
		GetMesh()->SetSkeletalMeshAsset(QuinnMesh.Object);
	}

	SetClassStats(300.f, 4.f, FRPGResourceConfig::MakeMana(250.f, 12.f));

	AbilityClasses = {
		USpell_ArcaneBolt::StaticClass(),
		USpell_Fireball::StaticClass(),
		USpell_FrostNova::StaticClass(),
		USpell_LightningStrike::StaticClass(),
		USpell_Blink::StaticClass(),
		USpell_ArcaneShield::StaticClass(),
	};

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

FVector AMageCharacter::GetSpellOrigin() const
{
	return StaffOrb && StaffOrb->IsVisible() ? StaffOrb->GetComponentLocation() : Super::GetSpellOrigin();
}

void AMageCharacter::HandleDeath(AActor* Killer)
{
	Super::HandleDeath(Killer);
	StaffLight->SetVisibility(false);
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
