#include "UI/RPGHUD.h"

#include "CanvasItem.h"
#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGGameplayAbility.h"
#include "Abilities/RPGStatusEffects.h"
#include "Camera/PlayerCameraManager.h"
#include "Characters/RPGPlayerCharacter.h"
#include "Core/RPGGameInstance.h"
#include "Core/RPGPlayerController.h"
#include "Core/RPGPlayerState.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "Engine/Font.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/GameStateBase.h"
#include "Net/RPGSessionSubsystem.h"
#include "World/RPGWorldGenerator.h"

namespace RPGHUDPrivate
{
	const FLinearColor PanelColor(0.015f, 0.015f, 0.025f, 0.72f);
	const FLinearColor BarBackground(0.f, 0.f, 0.f, 0.65f);
	const FLinearColor HealthColor(0.72f, 0.09f, 0.08f);
	const FLinearColor ShieldColor(0.7f, 0.45f, 1.f);
	const FLinearColor TextColor(0.95f, 0.92f, 0.85f);
	const FLinearColor GoldColor(1.f, 0.82f, 0.35f);

	/** Names of the character's active statuses, harmful or helpful. */
	FString DescribeStatus(const ARPGCharacterBase& Character, bool bHarmful)
	{
		TArray<FString> Parts;
		for (const FRPGStatusDefinition& Definition : RPGStatusEffects::GetDefinitions())
		{
			if (Definition.bHarmful == bHarmful && Character.HasStatus(Definition.Tag))
			{
				Parts.Add(Definition.DisplayName.ToString());
			}
		}
		return FString::Join(Parts, TEXT("  "));
	}

	/** Hotbar key label of a slot. */
	const TCHAR* GetSlotKeyLabel(int32 Slot)
	{
		static const TCHAR* Labels[] = { TEXT("LMB"), TEXT("1"), TEXT("2"), TEXT("3"), TEXT("4"), TEXT("5") };
		return Slot >= 0 && Slot < UE_ARRAY_COUNT(Labels) ? Labels[Slot] : TEXT("");
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

void ARPGHUD::NotifyText(const UObject* WorldContextObject, const FVector& WorldLocation, const FString& Text, const FLinearColor& Color, float Scale)
{
	const UWorld* World = WorldContextObject ? WorldContextObject->GetWorld() : nullptr;
	const APlayerController* PlayerController = World ? World->GetFirstPlayerController() : nullptr;
	if (ARPGHUD* HUD = PlayerController ? PlayerController->GetHUD<ARPGHUD>() : nullptr)
	{
		HUD->AddFloatingText(WorldLocation, Text, Color, Scale);
	}
}

void ARPGHUD::ShowMessage(const FText& Message, const FLinearColor& Color, float Duration)
{
	MessageText = Message;
	MessageColor = Color;
	MessageTimeRemaining = Duration;
}

void ARPGHUD::AddKillMessage(const FString& Killer, const FString& Victim, bool bLocalPlayerInvolved)
{
	FKillMessage& Entry = KillMessages.AddDefaulted_GetRef();
	Entry.Text = Killer.IsEmpty() ? FString::Printf(TEXT("%s died"), *Victim) : FString::Printf(TEXT("%s  defeated  %s"), *Killer, *Victim);
	Entry.Color = bLocalPlayerInvolved ? RPGHUDPrivate::GoldColor : RPGHUDPrivate::TextColor;

	constexpr int32 MaxKillMessages = 5;
	if (KillMessages.Num() > MaxKillMessages)
	{
		KillMessages.RemoveAt(0);
	}
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
	if (PlayerController && PlayerController->IsMenuOpen())
	{
		// A Slate menu covers the screen.
		MapSelectorEntryBoxes.Reset();
		return;
	}
	if (PlayerController && PlayerController->IsMapSelectorOpen())
	{
		DrawMapSelector(*PlayerController);
		return;
	}
	MapSelectorEntryBoxes.Reset();

	DrawEnemyBars();
	DrawFloatingTexts(DeltaSeconds);

	if (const ARPGPlayerCharacter* PlayerCharacter = Cast<ARPGPlayerCharacter>(GetOwningPawn()))
	{
		if (PlayerCharacter->IsAlive())
		{
			DrawCrosshair(*PlayerCharacter);
		}
		DrawPlayerFrame(*PlayerCharacter);
		DrawSpellBar(*PlayerCharacter);
		DrawZoneBanner(*PlayerCharacter, DeltaSeconds);
		if (!PlayerCharacter->IsAlive())
		{
			DrawDeathScreen();
		}
	}
	else if (const ARPGPlayerState* RPGPlayerState = PlayerController ? PlayerController->GetPlayerState<ARPGPlayerState>() : nullptr; RPGPlayerState && RPGPlayerState->GetRespawnTime() > 0.0)
	{
		// Between the old body being removed and the new one arriving.
		DrawDeathScreen();
	}

	DrawMessage(DeltaSeconds);

	const bool bNetworked = GetNetMode() != NM_Standalone;
	const bool bScoreboardHeld = PlayerController && PlayerController->IsScoreboardVisible();
	if (bNetworked || bScoreboardHeld)
	{
		DrawScoreboard(bScoreboardHeld);
	}
	if (bNetworked)
	{
		DrawNetworkStatus();
	}

	if (PlayerController && PlayerController->IsHelpVisible())
	{
		DrawHelp(Cast<ARPGPlayerCharacter>(GetOwningPawn()));
	}
}

void ARPGHUD::DrawCrosshair(const ARPGPlayerCharacter& PlayerCharacter)
{
	FVector AimLocation;
	ARPGCharacterBase* Target = nullptr;
	PlayerCharacter.ComputeAim(4500.f, AimLocation, Target);

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
		DrawString(Target->GetCombatName(), CenterX, CenterY + 20.f * S, Color, 16.f * S, true);
	}
}

void ARPGHUD::DrawPlayerFrame(const ARPGPlayerCharacter& PlayerCharacter)
{
	using namespace RPGHUDPrivate;

	const float S = UIScale;
	const float Width = 440.f * S;
	const float X = (Canvas->ClipX - Width) * 0.5f;
	const float HealthHeight = 24.f * S;
	const float ResourceHeight = 16.f * S;
	const float ResourceY = Canvas->ClipY - 40.f * S - ResourceHeight;
	const float HealthY = ResourceY - 6.f * S - HealthHeight;
	const float PanelTop = HealthY - 14.f * S;

	DrawRect(PanelColor, X - 8.f * S, PanelTop, Width + 16.f * S, ResourceY + ResourceHeight + 8.f * S - PanelTop);

	DrawBar(X, HealthY, Width, HealthHeight, PlayerCharacter.GetHealth() / PlayerCharacter.GetMaxHealth(), HealthColor, BarBackground);
	DrawString(FString::Printf(TEXT("%d / %d"), FMath::CeilToInt(PlayerCharacter.GetHealth()), FMath::RoundToInt(PlayerCharacter.GetMaxHealth())), X + Width * 0.5f, HealthY + HealthHeight * 0.5f, TextColor, 17.f * S, true, true);

	if (PlayerCharacter.GetShield() > 0.f)
	{
		DrawBar(X, HealthY - 8.f * S, Width, 5.f * S, PlayerCharacter.GetShield() / PlayerCharacter.GetMaxHealth(), ShieldColor, BarBackground);
	}

	const FRPGResourceConfig& Resource = PlayerCharacter.GetResourceConfig();
	if (PlayerCharacter.GetMaxResource() > 0.f)
	{
		DrawBar(X, ResourceY, Width, ResourceHeight, PlayerCharacter.GetResource() / PlayerCharacter.GetMaxResource(), Resource.GetColor(), BarBackground);
		DrawString(FString::Printf(TEXT("%d / %d %s"), FMath::FloorToInt(PlayerCharacter.GetResource()), FMath::RoundToInt(PlayerCharacter.GetMaxResource()), *Resource.GetDisplayName().ToString()),
			X + Width * 0.5f, ResourceY + ResourceHeight * 0.5f, TextColor, 13.f * S, true, true);
	}

	const FString Debuffs = DescribeStatus(PlayerCharacter, true);
	if (!Debuffs.IsEmpty())
	{
		DrawString(Debuffs, X + Width * 0.5f, PanelTop - 150.f * S, FLinearColor(1.f, 0.6f, 0.5f), 18.f * S, true);
	}
	const FString Buffs = DescribeStatus(PlayerCharacter, false);
	if (!Buffs.IsEmpty())
	{
		DrawString(Buffs, X + Width * 0.5f, PanelTop - 128.f * S, FLinearColor(0.6f, 0.9f, 1.f), 16.f * S, true);
	}
}

void ARPGHUD::DrawSpellBar(const ARPGPlayerCharacter& PlayerCharacter)
{
	using namespace RPGHUDPrivate;

	const URPGAbilitySystemComponent* AbilitySystem = PlayerCharacter.GetRPGAbilitySystem();
	if (!AbilitySystem)
	{
		return;
	}

	const float S = UIScale;
	const float SlotSize = 74.f * S;
	const float Gap = 10.f * S;
	const int32 NumSlots = URPGAbilitySystemComponent::NumSlots;
	// The basic attack slot sits a little apart from the numbered ones.
	const float BasicGap = 18.f * S;
	const float TotalWidth = NumSlots * SlotSize + (NumSlots - 2) * Gap + BasicGap;
	const float StartX = (Canvas->ClipX - TotalWidth) * 0.5f;
	const float Y = Canvas->ClipY - 100.f * S - 16.f * S - SlotSize;
	const float Resource = PlayerCharacter.GetResource();
	const FLinearColor CostColor = FLinearColor::LerpUsingHSV(PlayerCharacter.GetResourceConfig().GetColor(), FLinearColor::White, 0.35f);

	for (int32 Index = 0; Index < NumSlots; ++Index)
	{
		const URPGGameplayAbility* Ability = AbilitySystem->GetSlotAbility(Index);
		if (!Ability)
		{
			continue;
		}

		const float X = StartX + Index * (SlotSize + Gap) + (Index > 0 ? BasicGap - Gap : 0.f);
		const FLinearColor& SpellColor = Ability->GetColor();
		float CooldownDuration = 0.f;
		const float CooldownRemaining = AbilitySystem->GetSlotCooldownRemaining(Index, CooldownDuration);
		const bool bReady = CooldownRemaining <= 0.f;
		const bool bEnoughResource = Resource + KINDA_SMALL_NUMBER >= Ability->GetResourceCost();

		DrawRect(PanelColor, X, Y, SlotSize, SlotSize);
		DrawRect(WithAlpha(SpellColor, 0.3f), X + 3.f * S, Y + 3.f * S, SlotSize - 6.f * S, SlotSize - 6.f * S);

		// Rune-like emblem in the ability color.
		const float Emblem = SlotSize * 0.28f;
		DrawRect(WithAlpha(SpellColor, 0.9f), X + (SlotSize - Emblem) * 0.5f, Y + SlotSize * 0.3f, Emblem, Emblem);

		if (!bReady)
		{
			const float Fraction = FMath::Clamp(CooldownRemaining / FMath::Max(0.01f, CooldownDuration), 0.f, 1.f);
			DrawRect(FLinearColor(0.f, 0.f, 0.f, 0.72f), X, Y, SlotSize, SlotSize * Fraction);
			const FString Seconds = CooldownRemaining >= 1.f ? FString::Printf(TEXT("%d"), FMath::CeilToInt(CooldownRemaining)) : FString::Printf(TEXT("%.1f"), CooldownRemaining);
			DrawString(Seconds, X + SlotSize * 0.5f, Y + SlotSize * 0.45f, FLinearColor::White, 28.f * S, true, true);
		}
		else if (!bEnoughResource)
		{
			DrawRect(FLinearColor(0.05f, 0.05f, 0.1f, 0.65f), X, Y, SlotSize, SlotSize);
		}

		DrawFrame(X, Y, SlotSize, SlotSize, FMath::Max(1.f, 2.f * S), bReady && bEnoughResource ? SpellColor : WithAlpha(SpellColor, 0.35f));

		DrawString(GetSlotKeyLabel(Index), X + 5.f * S, Y + 3.f * S, GoldColor, (Index == 0 ? 13.f : 17.f) * S);

		if (Ability->GetResourceCost() > 0.f)
		{
			const FString Cost = FString::FromInt(FMath::RoundToInt(Ability->GetResourceCost()));
			DrawString(Cost, X + SlotSize - 5.f * S - MeasureString(Cost, 13.f * S).X, Y + 4.f * S, CostColor, 13.f * S);
		}

		// Shrink long names to fit the slot.
		const FString Name = Ability->GetSlotLabel(PlayerCharacter).ToString();
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

	const ARPGCharacterBase* PlayerCharacter = Cast<ARPGCharacterBase>(GetOwningPawn());
	if (!PlayerOwner || !PlayerOwner->PlayerCameraManager)
	{
		return;
	}

	const FVector ViewLocation = PlayerOwner->PlayerCameraManager->GetCameraLocation();
	const float S = UIScale;

	for (TActorIterator<ARPGCharacterBase> It(GetWorld()); It; ++It)
	{
		const ARPGCharacterBase* Character = *It;
		if (Character == PlayerCharacter || !Character->IsAlive())
		{
			continue;
		}
		// Bars over enemies: bots, and other players in deathmatch. Without a body of our own, use the team.
		const bool bHostile = PlayerCharacter ? PlayerCharacter->IsHostileTo(Character) : Character->GetTeam() != ERPGTeam::Player;
		if (!bHostile)
		{
			continue;
		}
		if (FVector::Dist(ViewLocation, Character->GetActorLocation()) > 5000.f || !Character->WasRecentlyRendered(0.25f) || !Character->IsVisibleTo(PlayerCharacter))
		{
			continue;
		}

		const FVector Screen = Project(Character->GetActorLocation() + FVector(0.f, 0.f, 135.f), true);
		if (Screen.Z <= 0.f)
		{
			continue;
		}

		const float Width = 110.f * S;
		const float Height = 9.f * S;
		DrawString(Character->GetCombatName(), Screen.X, Screen.Y - 20.f * S, FLinearColor(1.f, 0.82f, 0.75f), 15.f * S, true);
		DrawBar(Screen.X - Width * 0.5f, Screen.Y, Width, Height, Character->GetHealth() / Character->GetMaxHealth(), HealthColor, BarBackground);
		if (Character->GetShield() > 0.f)
		{
			DrawBar(Screen.X - Width * 0.5f, Screen.Y - 4.f * S, Width, 3.f * S, Character->GetShield() / Character->GetMaxHealth(), ShieldColor, BarBackground);
		}

		// Crowd control first: it is what the attacker cares about.
		FString Status = DescribeStatus(*Character, true);
		const FString Buffs = DescribeStatus(*Character, false);
		if (!Buffs.IsEmpty())
		{
			Status = Status.IsEmpty() ? Buffs : Status + TEXT("  ") + Buffs;
		}
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

void ARPGHUD::DrawZoneBanner(const ARPGPlayerCharacter& PlayerCharacter, float DeltaSeconds)
{
	FText Zone;
	if (const ARPGWorldGenerator* Generator = ARPGWorldGenerator::FindInWorld(GetWorld()))
	{
		Zone = Generator->GetZoneNameAt(PlayerCharacter.GetActorLocation());
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

void ARPGHUD::DrawDeathScreen()
{
	const float S = UIScale;
	DrawRect(FLinearColor(0.08f, 0.f, 0.f, 0.45f), 0.f, 0.f, Canvas->ClipX, Canvas->ClipY);
	DrawString(TEXT("You have fallen"), Canvas->ClipX * 0.5f, Canvas->ClipY * 0.4f, FLinearColor(0.9f, 0.15f, 0.1f), 64.f * S, true, true);

	// The respawn time is replicated in server time, which every machine can read from the game state.
	const ARPGPlayerState* RPGPlayerState = PlayerOwner ? PlayerOwner->GetPlayerState<ARPGPlayerState>() : nullptr;
	const AGameStateBase* GameState = GetWorld()->GetGameState();
	if (RPGPlayerState && GameState && RPGPlayerState->GetRespawnTime() > 0.0)
	{
		const float Remaining = static_cast<float>(RPGPlayerState->GetRespawnTime() - GameState->GetServerWorldTimeSeconds());
		if (Remaining > 0.f)
		{
			DrawString(FString::Printf(TEXT("Respawning in %d"), FMath::CeilToInt(Remaining)), Canvas->ClipX * 0.5f, Canvas->ClipY * 0.4f + 60.f * S, RPGHUDPrivate::TextColor, 26.f * S, true, true);
		}
	}
	DrawString(TEXT("F3 to change class"), Canvas->ClipX * 0.5f, Canvas->ClipY * 0.4f + 100.f * S, RPGHUDPrivate::WithAlpha(RPGHUDPrivate::TextColor, 0.7f), 18.f * S, true, true);
}

void ARPGHUD::DrawScoreboard(bool bExpanded)
{
	using namespace RPGHUDPrivate;

	const AGameStateBase* GameState = GetWorld()->GetGameState();
	if (!GameState)
	{
		return;
	}

	TArray<const ARPGPlayerState*> Players;
	for (const APlayerState* State : GameState->PlayerArray)
	{
		if (const ARPGPlayerState* RPGState = Cast<ARPGPlayerState>(State))
		{
			Players.Add(RPGState);
		}
	}
	Players.Sort([](const ARPGPlayerState& A, const ARPGPlayerState& B)
	{
		return A.GetKills() != B.GetKills() ? A.GetKills() > B.GetKills() : A.GetDeaths() < B.GetDeaths();
	});

	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	const float S = UIScale * (bExpanded ? 1.25f : 1.f);
	const float LineHeight = 22.f * S;
	const float Width = (bExpanded ? 380.f : 300.f) * S;
	const float X = Canvas->ClipX - Width - 24.f * UIScale;
	const float Y = 24.f * UIScale;
	const float Height = (Players.Num() + 1.4f) * LineHeight + 14.f * S;

	DrawRect(PanelColor, X, Y, Width, Height);
	DrawString(TEXT("DEATHMATCH"), X + 12.f * S, Y + 7.f * S, GoldColor, 17.f * S);
	DrawString(TEXT("K / D"), X + Width - 12.f * S - MeasureString(TEXT("K / D"), 15.f * S).X, Y + 8.f * S, WithAlpha(TextColor, 0.7f), 15.f * S);

	for (int32 Index = 0; Index < Players.Num(); ++Index)
	{
		const ARPGPlayerState* State = Players[Index];
		const float RowY = Y + 7.f * S + (Index + 1.3f) * LineHeight;
		const bool bIsLocal = PlayerOwner && State == PlayerOwner->PlayerState;

		FString Name = State->GetPlayerName();
		if (const FRPGCharacterClassInfo* ClassInfo = GameInstance ? GameInstance->FindCharacterClass(State->GetCharacterClassId()) : nullptr)
		{
			Name += FString::Printf(TEXT("  (%s)"), *ClassInfo->DisplayName.ToString());
		}
		DrawString(Name, X + 12.f * S, RowY, bIsLocal ? GoldColor : TextColor, 16.f * S);

		const FString Score = FString::Printf(TEXT("%d / %d"), State->GetKills(), State->GetDeaths());
		DrawString(Score, X + Width - 12.f * S - MeasureString(Score, 16.f * S).X, RowY, bIsLocal ? GoldColor : TextColor, 16.f * S);
	}

	DrawKillFeed(FMath::Min(GetWorld()->GetDeltaSeconds(), 0.1f), Y + Height + 10.f * UIScale);
}

void ARPGHUD::DrawKillFeed(float DeltaSeconds, float Top)
{
	constexpr float KillMessageLifetime = 6.f;
	const float S = UIScale;
	for (int32 Index = KillMessages.Num() - 1; Index >= 0; --Index)
	{
		KillMessages[Index].Age += DeltaSeconds;
		if (KillMessages[Index].Age > KillMessageLifetime)
		{
			KillMessages.RemoveAt(Index);
		}
	}

	for (int32 Index = 0; Index < KillMessages.Num(); ++Index)
	{
		const FKillMessage& Entry = KillMessages[Index];
		const float Alpha = FMath::Clamp((KillMessageLifetime - Entry.Age) / 1.f, 0.f, 1.f);
		const float Width = MeasureString(Entry.Text, 16.f * S).X;
		DrawString(Entry.Text, Canvas->ClipX - 24.f * S - Width, Top + Index * 22.f * S, RPGHUDPrivate::WithAlpha(Entry.Color, Alpha), 16.f * S);
	}
}

void ARPGHUD::DrawNetworkStatus()
{
	const float S = UIScale;
	FString Status;
	if (GetNetMode() == NM_Client)
	{
		const APlayerState* State = PlayerOwner ? PlayerOwner->PlayerState.Get() : nullptr;
		Status = FString::Printf(TEXT("Connected   ping %d ms"), State ? FMath::RoundToInt(State->GetPingInMilliseconds()) : 0);
	}
	else
	{
		const URPGSessionSubsystem* Session = GetGameInstance() ? GetGameInstance()->GetSubsystem<URPGSessionSubsystem>() : nullptr;
		const FString Address = Session ? Session->GetLocalAddressHint() : FString();
		const AGameStateBase* GameState = GetWorld()->GetGameState();
		Status = FString::Printf(TEXT("Hosting on %s   %d player(s)"), Address.IsEmpty() ? TEXT("this PC") : *Address, GameState ? GameState->PlayerArray.Num() : 1);
	}
	Status += TEXT("   F10 leave");
	DrawString(Status, 24.f * S, Canvas->ClipY - 34.f * S, RPGHUDPrivate::WithAlpha(RPGHUDPrivate::TextColor, 0.75f), 15.f * S);
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

void ARPGHUD::DrawHelp(const ARPGPlayerCharacter* PlayerCharacter)
{
	using namespace RPGHUDPrivate;

	struct FLine
	{
		FString Text;
		FLinearColor Color;
	};
	TArray<FLine> Lines;
	auto AddLine = [&Lines](const FString& Text, const FLinearColor& Color = TextColor) { Lines.Add({ Text, Color }); };

	AddLine(TEXT("WASD / Arrows   Move"));
	AddLine(TEXT("Mouse           Look & aim"));
	AddLine(TEXT("Mouse Wheel     Zoom"));
	AddLine(TEXT("Space           Jump"));
	AddLine(TEXT("Left Shift      Sprint"));

	// The current class's abilities.
	if (const URPGAbilitySystemComponent* AbilitySystem = PlayerCharacter ? PlayerCharacter->GetRPGAbilitySystem() : nullptr)
	{
		for (int32 Slot = 0; Slot < URPGAbilitySystemComponent::NumSlots; ++Slot)
		{
			if (const URPGGameplayAbility* Ability = AbilitySystem->GetSlotAbility(Slot))
			{
				AddLine(FString::Printf(TEXT("%-4s %s"), GetSlotKeyLabel(Slot), *Ability->GetDisplayName().ToString()), FLinearColor::LerpUsingHSV(Ability->GetColor(), FLinearColor::White, 0.5f));
			}
		}
	}

	AddLine(TEXT("F2              Change map"));
	AddLine(TEXT("F3              Change class"));
	AddLine(TEXT("Tab             Scoreboard"));
	AddLine(TEXT("F10             Main menu / leave"));
	AddLine(TEXT("F1              Hide this panel"));

	const float S = UIScale;
	const float LineHeight = 20.f * S;
	const float X = 24.f * S;
	const float Y = 24.f * S;
	const float Width = 300.f * S;
	const float Height = (Lines.Num() + 1.6f) * LineHeight + 16.f * S;

	DrawRect(PanelColor, X, Y, Width, Height);
	DrawString(TEXT("CONTROLS"), X + 12.f * S, Y + 8.f * S, GoldColor, 20.f * S);
	for (int32 Index = 0; Index < Lines.Num(); ++Index)
	{
		DrawString(Lines[Index].Text, X + 12.f * S, Y + 8.f * S + (Index + 1.4f) * LineHeight, Lines[Index].Color, 16.f * S);
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
