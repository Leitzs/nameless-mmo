#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "RPGHUD.generated.h"

class AMageCharacter;
class UFont;

/**
 * Canvas-drawn HUD: player health/mana/shield, spell hotbar with cooldowns, crosshair with target lock,
 * enemy health bars, floating combat text, zone banner, messages and a controls panel.
 */
UCLASS()
class RPGTEST_API ARPGHUD : public AHUD
{
	GENERATED_BODY()

public:
	virtual void DrawHUD() override;

	/** Pops a floating damage number over a character. Safe to call from anywhere in the game world. */
	static void NotifyDamage(const UObject* WorldContextObject, const FVector& WorldLocation, float HealthDamage, float AbsorbedDamage, const FLinearColor& Color, bool bPlayerWasHit);

	/** Shows a short centered message (e.g. "Not enough mana"). */
	void ShowMessage(const FText& Message, const FLinearColor& Color, float Duration = 1.8f);

private:
	struct FFloatingText
	{
		FVector WorldLocation = FVector::ZeroVector;
		FVector2D Drift = FVector2D::ZeroVector;
		FString Text;
		FLinearColor Color = FLinearColor::White;
		float Scale = 1.f;
		float Age = 0.f;
		float Lifetime = 1.1f;
	};

	void AddFloatingText(const FVector& WorldLocation, const FString& Text, const FLinearColor& Color, float Scale);

	void DrawCrosshair(const AMageCharacter& Mage);
	void DrawPlayerFrame(const AMageCharacter& Mage);
	void DrawSpellBar(const AMageCharacter& Mage);
	void DrawEnemyBars();
	void DrawFloatingTexts(float DeltaSeconds);
	void DrawZoneBanner(const AMageCharacter& Mage, float DeltaSeconds);
	void DrawDeathScreen(const AMageCharacter& Mage);
	void DrawMessage(float DeltaSeconds);
	void DrawHelp();

	void DrawBar(float X, float Y, float Width, float Height, float Fraction, const FLinearColor& Fill, const FLinearColor& Background);
	void DrawFrame(float X, float Y, float Width, float Height, float Thickness, const FLinearColor& Color);

	/** Draws shadowed text whose line height is PixelHeight (already UI-scaled by the caller). */
	void DrawString(const FString& Text, float X, float Y, const FLinearColor& Color, float PixelHeight, bool bCenterX = false, bool bCenterY = false);
	FVector2D MeasureString(const FString& Text, float PixelHeight) const;

	UPROPERTY(Transient)
	TObjectPtr<UFont> Font;

	/** Native line height of Font, used to convert pixel sizes into canvas scales. */
	float FontLineHeight = 0.f;

	TArray<FFloatingText> FloatingTexts;

	FText MessageText;
	FLinearColor MessageColor = FLinearColor::White;
	float MessageTimeRemaining = 0.f;

	FText CurrentZone;
	float ZoneBannerTime = 0.f;

	double LastDrawTime = 0.0;
	float UIScale = 1.f;
};
