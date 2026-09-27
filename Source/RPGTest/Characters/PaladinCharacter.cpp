#include "Characters/PaladinCharacter.h"

#include "Abilities/RPGGameplayTags.h"
#include "Spells/PaladinSpells.h"

#define LOCTEXT_NAMESPACE "RPGPaladin"

APaladinCharacter::APaladinCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	CharacterName = LOCTEXT("PaladinName", "Paladin");
	BodyTint = FLinearColor(0.32f, 0.34f, 0.45f, 1.f);
	BaseMoveSpeed = 480.f;

	SetClassStats(420.f, 5.f, FRPGResourceConfig::MakeMana(180.f, 8.f));
	PassiveTags.AddTag(RPGTags::Trait_FrontalBlock);

	AbilityClasses = {
		USpell_SwordSwing::StaticClass(),
		USpell_CrusaderStrike::StaticClass(),
		USpell_HammerOfJustice::StaticClass(),
		USpell_FlashOfLight::StaticClass(),
		USpell_Cleanse::StaticClass(),
		USpell_DivineShield::StaticClass(),
	};

	const FName HeadBone(TEXT("head"));
	const FLinearColor Steel(0.62f, 0.63f, 0.68f);
	const FLinearColor Gold(0.75f, 0.55f, 0.12f);

	FRPGCosmeticPart Helmet;
	Helmet.Name = TEXT("Helmet");
	Helmet.Shape = ERPGPartShape::Sphere;
	Helmet.Bone = HeadBone;
	Helmet.Offset = FVector(1.f, 0.f, 12.f);
	Helmet.Scale = FVector(0.3f, 0.28f, 0.28f);
	Helmet.Color = Steel;
	Helmet.Roughness = 0.3f;
	AddCosmeticPart(Helmet);

	FRPGCosmeticPart Crest;
	Crest.Name = TEXT("HelmetCrest");
	Crest.Bone = HeadBone;
	Crest.Offset = FVector(0.f, 0.f, 26.f);
	Crest.Scale = FVector(0.24f, 0.03f, 0.07f);
	Crest.Color = Gold;
	Crest.Roughness = 0.35f;
	AddCosmeticPart(Crest);

	// Longsword in the right hand, held forward in a guard stance.
	AddBladeParts(TEXT("Sword"), TEXT("hand_r"), FVector(0.77f, 0.f, 0.64f), 85.f, 0.07f, Steel, Gold);

	// Round shield strapped to the left forearm, facing outwards.
	FRPGCosmeticPart Shield;
	Shield.Name = TEXT("Shield");
	Shield.Shape = ERPGPartShape::Cylinder;
	Shield.Bone = TEXT("lowerarm_l");
	Shield.Offset = FVector(6.f, -12.f, 0.f);
	Shield.Rotation = FRotator(0.f, 0.f, 90.f);
	Shield.Scale = FVector(0.62f, 0.62f, 0.05f);
	Shield.Color = FLinearColor(0.12f, 0.18f, 0.45f);
	Shield.Roughness = 0.45f;
	AddCosmeticPart(Shield);

	FRPGCosmeticPart Emblem;
	Emblem.Name = TEXT("ShieldEmblem");
	Emblem.Shape = ERPGPartShape::Cylinder;
	Emblem.Bone = TEXT("lowerarm_l");
	Emblem.Offset = FVector(6.f, -15.f, 0.f);
	Emblem.Rotation = FRotator(0.f, 0.f, 90.f);
	Emblem.Scale = FVector(0.24f, 0.24f, 0.05f);
	Emblem.Color = Gold;
	Emblem.Roughness = 0.3f;
	Emblem.Emissive = 0.5f;
	AddCosmeticPart(Emblem);
}

#undef LOCTEXT_NAMESPACE
