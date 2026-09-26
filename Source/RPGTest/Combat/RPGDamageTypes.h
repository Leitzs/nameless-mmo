#pragma once

#include "CoreMinimal.h"
#include "GameFramework/DamageType.h"
#include "RPGDamageTypes.generated.h"

/** Base damage type for the game. The display color tints floating combat text. */
UCLASS(Abstract, Blueprintable)
class RPGTEST_API URPGDamageType : public UDamageType
{
	GENERATED_BODY()

public:
	UPROPERTY(EditDefaultsOnly, BlueprintReadOnly, Category = "Damage")
	FLinearColor DisplayColor = FLinearColor::White;
};

UCLASS()
class RPGTEST_API UDamageType_Physical : public URPGDamageType
{
	GENERATED_BODY()

public:
	UDamageType_Physical() { DisplayColor = FLinearColor(1.f, 0.35f, 0.3f); }
};

UCLASS()
class RPGTEST_API UDamageType_Fire : public URPGDamageType
{
	GENERATED_BODY()

public:
	UDamageType_Fire() { DisplayColor = FLinearColor(1.f, 0.55f, 0.1f); }
};

UCLASS()
class RPGTEST_API UDamageType_Frost : public URPGDamageType
{
	GENERATED_BODY()

public:
	UDamageType_Frost() { DisplayColor = FLinearColor(0.45f, 0.85f, 1.f); }
};

UCLASS()
class RPGTEST_API UDamageType_Lightning : public URPGDamageType
{
	GENERATED_BODY()

public:
	UDamageType_Lightning() { DisplayColor = FLinearColor(0.95f, 0.95f, 0.4f); }
};
