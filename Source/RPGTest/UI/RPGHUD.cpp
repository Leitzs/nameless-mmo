#include "UI/RPGHUD.h"

#include "CanvasItem.h"
#include "Camera/PlayerCameraManager.h"
#include "Characters/MageCharacter.h"
#include "Components/RPGAttributeComponent.h"
#include "Components/RPGSpellbookComponent.h"
#include "Components/RPGStatusEffectComponent.h"
#include "Core/RPGGameInstance.h"
#include "Core/RPGPlayerController.h"
#include "Core/RPGTestGameMode.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "Engine/Font.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "Spells/RPGSpell.h"
#include "World/RPGWorldGenerator.h"

namespace RPGHUDPrivate
{
	const FLinearColor PanelColor(0.015f, 0.015f, 0.025f, 0.72f);
	const FLinearColor BarBackground(0.f, 0.f, 0.f, 0.65f);
	const FLinearColor HealthColor(0.72f, 0.09f, 0.08f);
	const FLinearColor ManaColor(0.12f, 0.35f, 0.95f);
	const FLinearColor ShieldColor(0.7f, 0.45f, 1.f);
	const FLinearColor TextColor(0.95f, 0.92f, 0.85f);
	const FLinearColor GoldColor(1.f, 0.82f, 0.35f);

	FString DescribeStatus(const URPGStatusEffectComponent& Status)
	{
		TArray<FString> Parts;
		if (Status.IsFrozen()) { Parts.Add(TEXT("FROZEN")); }
		if (Status.IsStunned()) { Parts.Add(TEXT("STUNNED")); }
		if (Status.IsSlowed()) { Parts.Add(TEXT("SLOWED")); }
		if (Status.IsBurning()) { Parts.Add(TEXT("BURNING")); }
		return FString::Join(Parts, TEXT("  "));
	}

	FLinearColor WithAlpha(FLinearColor Color, float Alpha)
	{
		Color.A = Alpha;
		return Color;
	}
}

void ARPGHUD::NotifyDamage(const UObject* WorldContextObject, const FVector& WorldLocation, float HealthDamage, float AbsorbedDamage, const FLinearColor& Color, bool bPlayerWasHit)
{
	const UWorld* World = WorldContextObject ? WorldContextObject->GetWorld() : nullptr;
	const APlayerController* PlayerController = World ? World->GetFirstPlayerController() : nullptr;
	ARPGHUD* HUD = PlayerController ? PlayerController->GetHUD<ARPGHUD>() : nullptr;
	if (!HUD)
	{
		return;
	}

	if (HealthDamage >= 0.5f)
	{
		const FLinearColor NumberColor = bPlayerWasHit ? FLinearColor(1.f, 0.25f, 0.2f) : Color;
		HUD->AddFloatingText(WorldLocation, FString::Printf(TEXT("%d"), FMath::RoundToInt(HealthDamage)), NumberColor, bPlayerWasHit ? 0.85f : 1.f);
	}
	if (AbsorbedDamage >= 0.5f)
	{
		HUD->AddFloatingText(WorldLocation + FVector(0.f, 0.f, 25.f), FString::Printf(TEXT("(%d absorbed)"), FMath::RoundToInt(AbsorbedDamage)), RPGHUDPrivate::ShieldColor, 0.7f);
	}
}

void ARPGHUD::ShowMessage(const FText& Message, const FLinearColor& Color, float Duration)
{
	MessageText = Message;
	MessageColor = Color;
	MessageTimeRemaining = Duration;
}

void ARPGHUD::AddFloatingText(const FVector& WorldLocation, const FString& Text, const FLinearColor& Color, float Scale)
{
	FFloatingText& Entry = FloatingTexts.AddDefaulted_GetRef();
	Entry.WorldLocation = WorldLocation;
	Entry.Drift = FVector2D(FMath::FRandRange(-40.f, 40.f), 0.f);
	Entry.Text = Text;
	Entry.Color = Color;
	Entry.Scale = Scale;
}

void ARPGHUD::DrawHUD()
{
	Super::DrawHUD();

	if (!Canvas)
	{
		return;
	}

	if (!Font)
	{
		Font = GEngine->GetLargeFont();
		float Width = 0.f;
		Canvas->TextSize(Font, TEXT("Hg"), Width, FontLineHeight);
		FontLineHeight = FMath::Max(1.f, FontLineHeight);
	}

	const float DeltaSeconds = FMath::Min(GetWorld()->GetDeltaSeconds(), 0.1f);
	UIScale = FMath::Max(0.5f, Canvas->ClipY / 1080.f);

	ARPGPlayerController* PlayerController = Cast<ARPGPlayerController>(PlayerOwner);
	if (PlayerController && PlayerController->IsMapSelectorOpen())
	{
		DrawMapSelector(*PlayerController);
		return;
	}
	MapSelectorEntryBoxes.Reset();

	DrawEnemyBars();
	DrawFloatingTexts(DeltaSeconds);

	if (const AMageCharacter* Mage = Cast<AMageCharacter>(GetOwningPawn()))
	{
		if (Mage->IsAlive())
		{
			DrawCrosshair(*Mage);
		}
		DrawPlayerFrame(*Mage);
		DrawSpellBar(*Mage);
		DrawZoneBanner(*Mage, DeltaSeconds);
		if (!Mage->IsAlive())
		{
			DrawDeathScreen(*Mage);
		}
	}

	DrawMessage(DeltaSeconds);

	if (PlayerController && PlayerController->IsHelpVisible())
	{
		DrawHelp();
	}
}

void ARPGHUD::DrawCrosshair(const AMageCharacter& Mage)
{
	FVector AimLocation;
	ARPGCharacterBase* Target = nullptr;
	Mage.ComputeAim(4500.f, AimLocation, Target);

	const float S = UIScale;
	const float CenterX = Canvas->ClipX * 0.5f;
	const float CenterY = Canvas->ClipY * 0.5f;
	const FLinearColor Color = Target ? FLinearColor(1.f, 0.3f, 0.25f, 0.95f) : FLinearColor(1.f, 1.f, 1.f, 0.8f);
	const float Gap = 5.f * S;
	const float Length = 9.f * S;
	const float Thickness = FMath::Max(2.f, 2.f * S);

	DrawRect(Color, CenterX - Gap - Length, CenterY - Thickness * 0.5f, Length, Thickness);
	DrawRect(Color, CenterX + Gap, CenterY - Thickness * 0.5f, Length, Thickness);
	DrawRect(Color, CenterX - Thickness * 0.5f, CenterY - Gap - Length, Thickness, Length);
	DrawRect(Color, CenterX - Thickness * 0.5f, CenterY + Gap, Thickness, Length);
	DrawRect(Color, CenterX - Thickness * 0.5f, CenterY - Thickness * 0.5f, Thickness, Thickness);

	if (Target)
	{
		DrawString(Target->GetCharacterName().ToString(), CenterX, CenterY + 20.f * S, Color, 16.f * S, true);
	}
}

void ARPGHUD::DrawPlayerFrame(const AMageCharacter& Mage)
{
	using namespace RPGHUDPrivate;

	const URPGAttributeComponent* Attributes = Mage.GetAttributes();
	const float S = UIScale;
	const float Width = 440.f * S;
	const float X = (Canvas->ClipX - Width) * 0.5f;
	const float HealthHeight = 24.f * S;
	const float ManaHeight = 16.f * S;
	const float ManaY = Canvas->ClipY - 40.f * S - ManaHeight;
	const float HealthY = ManaY - 6.f * S - HealthHeight;
	const float PanelTop = HealthY - 14.f * S;

	DrawRect(PanelColor, X - 8.f * S, PanelTop, Width + 16.f * S, ManaY + ManaHeight + 8.f * S - PanelTop);

	DrawBar(X, HealthY, Width, HealthHeight, Attributes->GetHealth() / Attributes->GetMaxHealth(), HealthColor, BarBackground);
	DrawString(FString::Printf(TEXT("%d / %d"), FMath::CeilToInt(Attributes->GetHealth()), FMath::RoundToInt(Attributes->GetMaxHealth())), X + Width * 0.5f, HealthY + HealthHeight * 0.5f, TextColor, 17.f * S, true, true);

	if (Attributes->GetShield() > 0.f)
	{
		DrawBar(X, HealthY - 8.f * S, Width, 5.f * S, Attributes->GetShield() / Attributes->GetMaxHealth(), ShieldColor, BarBackground);
	}

	if (Attributes->GetMaxMana() > 0.f)
	{
		DrawBar(X, ManaY, Width, ManaHeight, Attributes->GetMana() / Attributes->GetMaxMana(), ManaColor, BarBackground);
		DrawString(FString::Printf(TEXT("%d / %d"), FMath::FloorToInt(Attributes->GetMana()), FMath::RoundToInt(Attributes->GetMaxMana())), X + Width * 0.5f, ManaY + ManaHeight * 0.5f, TextColor, 13.f * S, true, true);
	}

	const FString Status = DescribeStatus(*Mage.GetStatusEffects());
	if (!Status.IsEmpty())
	{
		DrawString(Status, X + Width * 0.5f, PanelTop - 128.f * S, FLinearColor(0.6f, 0.9f, 1.f), 18.f * S, true);
	}
}

void ARPGHUD::DrawSpellBar(const AMageCharacter& Mage)
{
	using namespace RPGHUDPrivate;

	const URPGSpellbookComponent* Spellbook = Mage.GetSpellbook();
	const int32 NumSpells = Spellbook->GetNumSpells();
	if (NumSpells == 0)
	{
		return;
	}

	const float S = UIScale;
	const float SlotSize = 74.f * S;
	const float Gap = 10.f * S;
	const float TotalWidth = NumSpells * SlotSize + (NumSpells - 1) * Gap;
	const float StartX = (Canvas->ClipX - TotalWidth) * 0.5f;
	const float Y = Canvas->ClipY - 100.f * S - 16.f * S - SlotSize;
	const float Mana = Mage.GetAttributes()->GetMana();

	for (int32 Index = 0; Index < NumSpells; ++Index)
	{
		const URPGSpell* Spell = Spellbook->GetSpell(Index);
		if (!Spell)
		{
			continue;
		}

		const float X = StartX + Index * (SlotSize + Gap);
		const FLinearColor& SpellColor = Spell->GetColor();
		const float CooldownRemaining = Spell->GetCooldownRemaining();
		const bool bReady = CooldownRemaining <= 0.f;
		const bool bEnoughMana = Mana >= Spell->GetManaCost();

		DrawRect(PanelColor, X, Y, SlotSize, SlotSize);
		DrawRect(WithAlpha(SpellColor, 0.3f), X + 3.f * S, Y + 3.f * S, SlotSize - 6.f * S, SlotSize - 6.f * S);

		// Rune-like emblem in the spell color.
		const float Emblem = SlotSize * 0.28f;
		DrawRect(WithAlpha(SpellColor, 0.9f), X + (SlotSize - Emblem) * 0.5f, Y + SlotSize * 0.3f, Emblem, Emblem);

		if (!bReady)
		{
			const float Fraction = FMath::Clamp(CooldownRemaining / FMath::Max(0.01f, Spell->GetCooldown()), 0.f, 1.f);
			DrawRect(FLinearColor(0.f, 0.f, 0.f, 0.72f), X, Y, SlotSize, SlotSize * Fraction);
			const FString Seconds = CooldownRemaining >= 1.f ? FString::Printf(TEXT("%d"), FMath::CeilToInt(CooldownRemaining)) : FString::Printf(TEXT("%.1f"), CooldownRemaining);
			DrawString(Seconds, X + SlotSize * 0.5f, Y + SlotSize * 0.45f, FLinearColor::White, 28.f * S, true, true);
		}
		else if (!bEnoughMana)
		{
			DrawRect(FLinearColor(0.05f, 0.1f, 0.45f, 0.6f), X, Y, SlotSize, SlotSize);
		}

		DrawFrame(X, Y, SlotSize, SlotSize, FMath::Max(1.f, 2.f * S), bReady && bEnoughMana ? SpellColor : WithAlpha(SpellColor, 0.35f));

		DrawString(FString::FromInt(Index + 1), X + 5.f * S, Y + 3.f * S, GoldColor, 17.f * S);

		const FString Cost = FString::FromInt(FMath::RoundToInt(Spell->GetManaCost()));
		DrawString(Cost, X + SlotSize - 5.f * S - MeasureString(Cost, 13.f * S).X, Y + 4.f * S, FLinearColor(0.5f, 0.7f, 1.f), 13.f * S);

		// Shrink long names to fit the slot.
		const FString Name = Spell->GetDisplayName().ToString();
		float NameHeight = 13.f * S;
		const float NameWidth = MeasureString(Name, NameHeight).X;
		if (NameWidth > SlotSize - 6.f * S)
		{
			NameHeight *= (SlotSize - 6.f * S) / NameWidth;
		}
		DrawString(Name, X + SlotSize * 0.5f, Y + SlotSize - 17.f * S, TextColor, NameHeight, true);
	}
}

void ARPGHUD::DrawEnemyBars()
{
	using namespace RPGHUDPrivate;

	const APawn* PlayerPawn = GetOwningPawn();
	if (!PlayerOwner || !PlayerOwner->PlayerCameraManager)
	{
		return;
	}

	const FVector ViewLocation = PlayerOwner->PlayerCameraManager->GetCameraLocation();
	const float S = UIScale;

	for (TActorIterator<ARPGCharacterBase> It(GetWorld()); It; ++It)
	{
		const ARPGCharacterBase* Character = *It;
		if (Character == PlayerPawn || !Character->IsAlive() || Character->GetTeam() == ERPGTeam::Player)
		{
			continue;
		}
		if (FVector::Dist(ViewLocation, Character->GetActorLocation()) > 5000.f || !Character->WasRecentlyRendered(0.25f))
		{
			continue;
		}

		const FVector Screen = Project(Character->GetActorLocation() + FVector(0.f, 0.f, 135.f), true);
		if (Screen.Z <= 0.f)
		{
			continue;
		}

		const URPGAttributeComponent* Attributes = Character->GetAttributes();
		const float Width = 110.f * S;
		const float Height = 9.f * S;
		DrawString(Character->GetCharacterName().ToString(), Screen.X, Screen.Y - 20.f * S, FLinearColor(1.f, 0.82f, 0.75f), 15.f * S, true);
		DrawBar(Screen.X - Width * 0.5f, Screen.Y, Width, Height, Attributes->GetHealth() / Attributes->GetMaxHealth(), HealthColor, BarBackground);

		const FString Status = DescribeStatus(*Character->GetStatusEffects());
		if (!Status.IsEmpty())
		{
			DrawString(Status, Screen.X, Screen.Y + Height + 3.f * S, FLinearColor(0.6f, 0.9f, 1.f), 13.f * S, true);
		}
	}
}

void ARPGHUD::DrawFloatingTexts(float DeltaSeconds)
{
	const float S = UIScale;
	for (int32 Index = FloatingTexts.Num() - 1; Index >= 0; --Index)
	{
		FFloatingText& Entry = FloatingTexts[Index];
		Entry.Age += DeltaSeconds;
		if (Entry.Age >= Entry.Lifetime)
		{
			FloatingTexts.RemoveAtSwap(Index);
			continue;
		}

		const float Alpha = Entry.Age / Entry.Lifetime;
		const FVector Screen = Project(Entry.WorldLocation + FVector(0.f, 0.f, 90.f * Alpha), true);
		if (Screen.Z <= 0.f)
		{
			continue;
		}

		const float Pop = 1.f + 0.5f * (1.f - FMath::Min(1.f, Entry.Age / 0.12f));
		FLinearColor Color = Entry.Color;
		Color.A = 1.f - Alpha * Alpha;
		DrawString(Entry.Text, Screen.X + Entry.Drift.X * Alpha * S, Screen.Y, Color, 30.f * S * Entry.Scale * Pop, true, true);
	}
}

void ARPGHUD::DrawZoneBanner(const AMageCharacter& Mage, float DeltaSeconds)
{
	FText Zone;
	if (const ARPGWorldGenerator* Generator = ARPGWorldGenerator::FindInWorld(GetWorld()))
	{
		Zone = Generator->GetZoneNameAt(Mage.GetActorLocation());
	}
	else if (const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>())
	{
		// Maps without zones announce the map itself.
		const int32 MapIndex = GameInstance->FindMapIndex(GetWorld());
		Zone = GameInstance->GetMaps().IsValidIndex(MapIndex) ? GameInstance->GetMaps()[MapIndex].DisplayName : FText::GetEmpty();
	}

	if (!Zone.EqualTo(CurrentZone))
	{
		CurrentZone = Zone;
		ZoneBannerTime = 0.f;
	}

	constexpr float BannerDuration = 4.f;
	ZoneBannerTime += DeltaSeconds;
	if (ZoneBannerTime > BannerDuration || CurrentZone.IsEmpty())
	{
		return;
	}

	const float FadeIn = FMath::Clamp(ZoneBannerTime / 0.5f, 0.f, 1.f);
	const float FadeOut = FMath::Clamp((BannerDuration - ZoneBannerTime) / 1.f, 0.f, 1.f);
	const float Alpha = FMath::Min(FadeIn, FadeOut);
	const float S = UIScale;
	const float CenterX = Canvas->ClipX * 0.5f;

	DrawString(CurrentZone.ToString(), CenterX, 120.f * S, RPGHUDPrivate::WithAlpha(RPGHUDPrivate::GoldColor, Alpha), 46.f * S, true, true);
	DrawRect(RPGHUDPrivate::WithAlpha(RPGHUDPrivate::GoldColor, 0.6f * Alpha), CenterX - 180.f * S, 150.f * S, 360.f * S, FMath::Max(1.f, 2.f * S));
}

void ARPGHUD::DrawDeathScreen(const AMageCharacter& Mage)
{
	const float S = UIScale;
	DrawRect(FLinearColor(0.08f, 0.f, 0.f, 0.45f), 0.f, 0.f, Canvas->ClipX, Canvas->ClipY);
	DrawString(TEXT("You have fallen"), Canvas->ClipX * 0.5f, Canvas->ClipY * 0.4f, FLinearColor(0.9f, 0.15f, 0.1f), 64.f * S, true, true);

	if (const ARPGTestGameMode* GameMode = GetWorld()->GetAuthGameMode<ARPGTestGameMode>())
	{
		const float Remaining = GameMode->GetRespawnTimeRemaining();
		if (Remaining > 0.f)
		{
			DrawString(FString::Printf(TEXT("Respawning in %d"), FMath::CeilToInt(Remaining)), Canvas->ClipX * 0.5f, Canvas->ClipY * 0.4f + 60.f * S, RPGHUDPrivate::TextColor, 26.f * S, true, true);
		}
	}
}

void ARPGHUD::DrawMessage(float DeltaSeconds)
{
	if (MessageTimeRemaining <= 0.f)
	{
		return;
	}

	MessageTimeRemaining -= DeltaSeconds;
	FLinearColor Color = MessageColor;
	Color.A = FMath::Clamp(MessageTimeRemaining / 0.4f, 0.f, 1.f);
	DrawString(MessageText.ToString(), Canvas->ClipX * 0.5f, Canvas->ClipY * 0.32f, Color, 26.f * UIScale, true, true);
}

void ARPGHUD::DrawHelp()
{
	using namespace RPGHUDPrivate;

	static const TCHAR* Lines[] =
	{
		TEXT("WASD / Arrows   Move"),
		TEXT("Mouse           Look & aim"),
		TEXT("Mouse Wheel     Zoom"),
		TEXT("Space           Jump"),
		TEXT("Left Shift      Sprint"),
		TEXT("1  Fireball"),
		TEXT("2  Frost Nova"),
		TEXT("3  Lightning Strike"),
		TEXT("4  Blink"),
		TEXT("5  Arcane Shield"),
		TEXT("F2              Change map"),
		TEXT("F1              Hide this panel"),
	};

	const float S = UIScale;
	const float LineHeight = 20.f * S;
	const float X = 24.f * S;
	const float Y = 24.f * S;
	const float Width = 300.f * S;
	const float Height = (UE_ARRAY_COUNT(Lines) + 1.6f) * LineHeight + 16.f * S;

	DrawRect(PanelColor, X, Y, Width, Height);
	DrawString(TEXT("CONTROLS"), X + 12.f * S, Y + 8.f * S, GoldColor, 20.f * S);
	for (int32 Index = 0; Index < UE_ARRAY_COUNT(Lines); ++Index)
	{
		const bool bSpellLine = Index >= 5 && Index <= 9;
		DrawString(Lines[Index], X + 12.f * S, Y + 8.f * S + (Index + 1.4f) * LineHeight, bSpellLine ? FLinearColor(0.8f, 0.75f, 1.f) : TextColor, 16.f * S);
	}
}

void ARPGHUD::DrawMapSelector(ARPGPlayerController& PlayerController)
{
	using namespace RPGHUDPrivate;

	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (!GameInstance)
	{
		return;
	}

	const TArray<FRPGMapInfo>& Maps = GameInstance->GetMaps();
	const int32 CurrentMap = GameInstance->FindMapIndex(GetWorld());
	const float S = UIScale;
	const float CenterX = Canvas->ClipX * 0.5f;
	const float CardWidth = 720.f * S;
	const float CardHeight = 92.f * S;
	const float Gap = 14.f * S;
	const float Left = CenterX - CardWidth * 0.5f;
	const float Top = (Canvas->ClipY - (Maps.Num() * (CardHeight + Gap) - Gap)) * 0.5f;

	const bool bJustOpened = MapSelectorEntryBoxes.Num() == 0;
	MapSelectorEntryBoxes.Reset();
	for (int32 Index = 0; Index < Maps.Num(); ++Index)
	{
		const float Y = Top + Index * (CardHeight + Gap);
		MapSelectorEntryBoxes.Emplace(FVector2D(Left, Y), FVector2D(Left + CardWidth, Y + CardHeight));
	}

	// Hovering highlights an entry, but only when the mouse moves, so it does not fight the keyboard.
	float MouseX = 0.f;
	float MouseY = 0.f;
	if (PlayerController.GetMousePosition(MouseX, MouseY))
	{
		const FVector2D MousePosition(MouseX, MouseY);
		const int32 Hovered = GetMapSelectorEntryAt(MousePosition);
		if (!bJustOpened && Hovered != INDEX_NONE && !MousePosition.Equals(LastMousePosition, 0.5f))
		{
			PlayerController.SetMapSelectorIndex(Hovered);
		}
		LastMousePosition = MousePosition;
	}

	DrawRect(FLinearColor(0.f, 0.f, 0.f, 0.62f), 0.f, 0.f, Canvas->ClipX, Canvas->ClipY);
	DrawString(TEXT("CHOOSE A MAP"), CenterX, Top - 64.f * S, GoldColor, 42.f * S, true, true);
	DrawRect(WithAlpha(GoldColor, 0.6f), CenterX - 180.f * S, Top - 38.f * S, 360.f * S, FMath::Max(1.f, 2.f * S));

	const float TextLeft = Left + 78.f * S;
	const float TextWidth = CardWidth - 78.f * S - 16.f * S;
	for (int32 Index = 0; Index < Maps.Num(); ++Index)
	{
		const FRPGMapInfo& Map = Maps[Index];
		const FBox2D& Box = MapSelectorEntryBoxes[Index];
		const bool bSelected = Index == PlayerController.GetMapSelectorIndex();

		DrawRect(bSelected ? FLinearColor(0.07f, 0.06f, 0.1f, 0.94f) : PanelColor, Box.Min.X, Box.Min.Y, CardWidth, CardHeight);
		DrawFrame(Box.Min.X, Box.Min.Y, CardWidth, CardHeight, FMath::Max(1.f, (bSelected ? 3.f : 1.f) * S), bSelected ? GoldColor : WithAlpha(TextColor, 0.25f));
		DrawString(FString::FromInt(Index + 1), Box.Min.X + 40.f * S, Box.Min.Y + CardHeight * 0.5f, bSelected ? GoldColor : WithAlpha(GoldColor, 0.6f), 36.f * S, true, true);
		DrawString(Map.DisplayName.ToString(), TextLeft, Box.Min.Y + 14.f * S, bSelected ? FLinearColor::White : TextColor, 30.f * S);

		// Shrink long descriptions to fit the card.
		const FString Description = Map.Description.ToString();
		float DescriptionHeight = 17.f * S;
		const float DescriptionWidth = MeasureString(Description, DescriptionHeight).X;
		if (DescriptionWidth > TextWidth)
		{
			DescriptionHeight *= TextWidth / DescriptionWidth;
		}
		DrawString(Description, TextLeft, Box.Min.Y + 56.f * S, WithAlpha(TextColor, 0.7f), DescriptionHeight);

		if (Index == CurrentMap)
		{
			const FString Tag = TEXT("CURRENT");
			DrawString(Tag, Box.Max.X - 14.f * S - MeasureString(Tag, 14.f * S).X, Box.Min.Y + 12.f * S, FLinearColor(0.5f, 0.85f, 0.5f), 14.f * S);
		}
	}

	const FString Hint = FString::Printf(TEXT("W/S or Up/Down to choose    Enter or click to play    1-%d quick pick    F2 reopens this later"), Maps.Num());
	DrawString(Hint, CenterX, Top + Maps.Num() * (CardHeight + Gap) + 24.f * S, WithAlpha(TextColor, 0.75f), 16.f * S, true);
}

int32 ARPGHUD::GetMapSelectorEntryAt(const FVector2D& ScreenPosition) const
{
	return MapSelectorEntryBoxes.IndexOfByPredicate([&ScreenPosition](const FBox2D& Box) { return Box.IsInside(ScreenPosition); });
}

void ARPGHUD::DrawBar(float X, float Y, float Width, float Height, float Fraction, const FLinearColor& Fill, const FLinearColor& Background)
{
	DrawRect(Background, X, Y, Width, Height);
	const float Clamped = FMath::Clamp(Fraction, 0.f, 1.f);
	if (Clamped > 0.f)
	{
		DrawRect(Fill, X, Y, Width * Clamped, Height);
		// Subtle highlight on the top half.
		DrawRect(FLinearColor(1.f, 1.f, 1.f, 0.08f), X, Y, Width * Clamped, Height * 0.45f);
	}
}

void ARPGHUD::DrawFrame(float X, float Y, float Width, float Height, float Thickness, const FLinearColor& Color)
{
	DrawRect(Color, X, Y, Width, Thickness);
	DrawRect(Color, X, Y + Height - Thickness, Width, Thickness);
	DrawRect(Color, X, Y, Thickness, Height);
	DrawRect(Color, X + Width - Thickness, Y, Thickness, Height);
}

void ARPGHUD::DrawString(const FString& Text, float X, float Y, const FLinearColor& Color, float PixelHeight, bool bCenterX, bool bCenterY)
{
	if (Text.IsEmpty() || !Font || Color.A <= 0.f)
	{
		return;
	}

	const float Scale = PixelHeight / FontLineHeight;
	FCanvasTextItem Item(FVector2D(X, Y), FText::FromString(Text), Font, Color);
	Item.Scale = FVector2D(Scale, Scale);
	Item.bCentreX = bCenterX;
	Item.bCentreY = bCenterY;
	Item.BlendMode = SE_BLEND_Translucent;
	Item.EnableShadow(FLinearColor(0.f, 0.f, 0.f, 0.85f * Color.A), FVector2D(1.5f, 1.5f));
	Canvas->DrawItem(Item);
}

FVector2D ARPGHUD::MeasureString(const FString& Text, float PixelHeight) const
{
	if (!Font || !Canvas)
	{
		return FVector2D::ZeroVector;
	}

	const float Scale = PixelHeight / FontLineHeight;
	float Width = 0.f;
	float Height = 0.f;
	Canvas->TextSize(Font, Text, Width, Height, Scale, Scale);
	return FVector2D(Width, Height);
}
