#include "Characters/WarlockCharacter.h"

#include "Components/PointLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Spells/WarlockSpells.h"

#define LOCTEXT_NAMESPACE "RPGWarlock"

AWarlockCharacter::AWarlockCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	CharacterName = LOCTEXT("WarlockName", "Warlock");
	BodyTint = FLinearColor(0.07f, 0.16f, 0.06f, 1.f);
	BaseMoveSpeed = 470.f;

	SetClassStats(320.f, 4.f, FRPGResourceConfig::MakeMana(260.f, 11.f));

	AbilityClasses = {
		USpell_FelBolt::StaticClass(),
		USpell_ShadowBolt::StaticClass(),
		USpell_Corruption::StaticClass(),
		USpell_DrainLife::StaticClass(),
		USpell_Fear::StaticClass(),
		USpell_DemonicCircle::StaticClass(),
	};

	const FName HeadBone(TEXT("head"));
	const FName LeftHandBone(TEXT("hand_l"));
	const FLinearColor HornColor(0.12f, 0.1f, 0.09f);

	// Two horns sweeping up and back.
	for (const float Side : { -1.f, 1.f })
	{
		const FVector Direction = FVector(-0.35f, 0.45f * Side, 0.82f).GetSafeNormal();
		FRPGCosmeticPart Horn;
		Horn.Name = Side < 0.f ? TEXT("HornLeft") : TEXT("HornRight");
		Horn.Shape = ERPGPartShape::Cone;
		Horn.Bone = HeadBone;
		Horn.Offset = FVector(2.f, 8.f * Side, 16.f) + Direction * 12.f;
		Horn.Rotation = FRotationMatrix::MakeFromZ(Direction).Rotator();
		Horn.Scale = FVector(0.07f, 0.07f, 0.28f);
		Horn.Color = HornColor;
		Horn.Roughness = 0.5f;
		AddCosmeticPart(Horn);
	}

	// A fel orb floating over the left hand: the spells come out of it.
	FRPGCosmeticPart Orb;
	Orb.Name = TEXT("FelOrb");
	Orb.Shape = ERPGPartShape::Sphere;
	Orb.Bone = LeftHandBone;
	Orb.Offset = FVector(12.f, 0.f, 8.f);
	Orb.Scale = FVector(0.16f);
	Orb.Color = FLinearColor(0.35f, 1.f, 0.2f);
	Orb.Roughness = 0.2f;
	Orb.Emissive = 12.f;
	FelOrb = AddCosmeticPart(Orb);
	FelOrb->SetCastShadow(false);

	FelLight = CreateDefaultSubobject<UPointLightComponent>(TEXT("FelLight"));
	FelLight->SetupAttachment(FelOrb);
	FelLight->SetIntensityUnits(ELightUnits::Candelas);
	FelLight->SetIntensity(80.f);
	FelLight->SetAttenuationRadius(500.f);
	FelLight->SetLightColor(FLinearColor(0.35f, 1.f, 0.2f));
	FelLight->SetCastShadows(false);
}

FVector AWarlockCharacter::GetSpellOrigin() const
{
	return FelOrb && FelOrb->IsVisible() ? FelOrb->GetComponentLocation() : Super::GetSpellOrigin();
}

void AWarlockCharacter::HandleDeath(AActor* Killer)
{
	Super::HandleDeath(Killer);
	FelLight->SetVisibility(false);
}

#undef LOCTEXT_NAMESPACE
