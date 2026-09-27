#include "Characters/WarriorCharacter.h"

#include "Spells/WarriorSpells.h"

#define LOCTEXT_NAMESPACE "RPGWarrior"

AWarriorCharacter::AWarriorCharacter(const FObjectInitializer& ObjectInitializer)
	: Super(ObjectInitializer)
{
	CharacterName = LOCTEXT("WarriorName", "Warrior");
	BodyTint = FLinearColor(0.28f, 0.1f, 0.05f, 1.f);
	BaseMoveSpeed = 500.f;

	// Rage: +0.4 per damage dealt, +0.3 per damage taken, drains 4 per second out of combat.
	SetClassStats(450.f, 5.f, FRPGResourceConfig::MakeRage(100.f, 0.4f, 0.3f, 4.f));

	AbilityClasses = {
		USpell_SwordSlash::StaticClass(),
		USpell_Charge::StaticClass(),
		USpell_MortalStrike::StaticClass(),
		USpell_Hamstring::StaticClass(),
		USpell_Whirlwind::StaticClass(),
		USpell_BerserkerRush::StaticClass(),
	};

	const FName HeadBone(TEXT("head"));
	const FLinearColor Iron(0.3f, 0.3f, 0.32f);
	const FLinearColor BoneColor(0.78f, 0.72f, 0.6f);

	FRPGCosmeticPart Helmet;
	Helmet.Name = TEXT("Helmet");
	Helmet.Shape = ERPGPartShape::Sphere;
	Helmet.Bone = HeadBone;
	Helmet.Offset = FVector(1.f, 0.f, 12.f);
	Helmet.Scale = FVector(0.31f, 0.29f, 0.27f);
	Helmet.Color = Iron;
	Helmet.Roughness = 0.4f;
	AddCosmeticPart(Helmet);

	FRPGCosmeticPart NoseGuard;
	NoseGuard.Name = TEXT("NoseGuard");
	NoseGuard.Bone = HeadBone;
	NoseGuard.Offset = FVector(15.f, 0.f, 6.f);
	NoseGuard.Scale = FVector(0.02f, 0.03f, 0.14f);
	NoseGuard.Color = Iron;
	NoseGuard.Roughness = 0.4f;
	AddCosmeticPart(NoseGuard);

	// Big horns pointing outwards and forward.
	for (const float Side : { -1.f, 1.f })
	{
		const FVector Direction = FVector(0.35f, 0.8f * Side, 0.5f).GetSafeNormal();
		FRPGCosmeticPart Horn;
		Horn.Name = Side < 0.f ? TEXT("HornLeft") : TEXT("HornRight");
		Horn.Shape = ERPGPartShape::Cone;
		Horn.Bone = HeadBone;
		Horn.Offset = FVector(2.f, 13.f * Side, 15.f) + Direction * 14.f;
		Horn.Rotation = FRotationMatrix::MakeFromZ(Direction).Rotator();
		Horn.Scale = FVector(0.1f, 0.1f, 0.32f);
		Horn.Color = BoneColor;
		Horn.Roughness = 0.6f;
		AddCosmeticPart(Horn);
	}

	// A heavy greatsword.
	AddBladeParts(TEXT("Greatsword"), TEXT("hand_r"), FVector(0.77f, 0.f, 0.64f), 115.f, 0.1f, FLinearColor(0.5f, 0.5f, 0.52f), FLinearColor(0.35f, 0.12f, 0.08f));
}

#undef LOCTEXT_NAMESPACE
