#include "UI/SRPGMenuWidgets.h"

#include "Core/RPGGameInstance.h"
#include "Core/RPGPlayerController.h"
#include "Engine/World.h"
#include "InputCoreTypes.h"
#include "Net/RPGSessionSubsystem.h"
#include "Styling/CoreStyle.h"
#include "Widgets/Input/SButton.h"
#include "Widgets/Input/SEditableTextBox.h"
#include "Widgets/Layout/SBorder.h"
#include "Widgets/Layout/SBox.h"
#include "Widgets/Layout/SSpacer.h"
#include "Widgets/SBoxPanel.h"
#include "Widgets/Text/STextBlock.h"

#define LOCTEXT_NAMESPACE "RPGMenu"

namespace RPGMenuPrivate
{
	const FLinearColor Backdrop(0.f, 0.f, 0.f, 0.7f);
	const FLinearColor PanelColor(0.02f, 0.02f, 0.035f, 0.94f);
	const FLinearColor GoldColor(1.f, 0.82f, 0.35f);
	const FLinearColor TextColor(0.95f, 0.92f, 0.85f);
	const FLinearColor DimTextColor(0.95f, 0.92f, 0.85f, 0.6f);
	const FLinearColor ErrorColor(1.f, 0.42f, 0.35f);
	const FLinearColor GoodColor(0.5f, 0.9f, 0.5f);

	const FSlateBrush* WhiteBrush()
	{
		return FCoreStyle::Get().GetBrush(TEXT("WhiteBrush"));
	}

	FSlateFontInfo Font(int32 Size, bool bBold = false)
	{
		return FCoreStyle::GetDefaultFontStyle(bBold ? "Bold" : "Regular", Size);
	}

	TSharedRef<SWidget> Heading(const FText& Text)
	{
		return SNew(STextBlock).Text(Text).Font(Font(14, true)).ColorAndOpacity(GoldColor);
	}

	TSharedRef<SWidget> Panel(const TSharedRef<SWidget>& Content, float Width)
	{
		return SNew(SBox)
			.WidthOverride(Width)
			[
				SNew(SBorder)
				.BorderImage(WhiteBrush())
				.BorderBackgroundColor(PanelColor)
				.Padding(FMargin(28.f, 22.f))
				[
					Content
				]
			];
	}

	/** A wide text button; Highlighted makes it look selected. */
	TSharedRef<SButton> MakeButton(const TAttribute<FText>& Label, FOnClicked OnClicked, TAttribute<bool> Highlighted = false, TAttribute<bool> Enabled = true, const FLinearColor& Accent = GoldColor)
	{
		return SNew(SButton)
			.OnClicked(OnClicked)
			.IsEnabled(Enabled)
			.ContentPadding(FMargin(14.f, 8.f))
			.ButtonColorAndOpacity_Lambda([Highlighted, Accent]() { return Highlighted.Get() ? Accent : FLinearColor(0.25f, 0.25f, 0.3f); })
			[
				SNew(STextBlock)
				.Text(Label)
				.Font(Font(15, true))
				.ColorAndOpacity_Lambda([Highlighted]() { return FSlateColor(Highlighted.Get() ? FLinearColor(0.05f, 0.03f, 0.08f) : TextColor); })
			];
	}

	TSharedRef<SWidget> Backdropped(const TSharedRef<SWidget>& Content)
	{
		return SNew(SBorder)
			.BorderImage(WhiteBrush())
			.BorderBackgroundColor(Backdrop)
			.HAlign(HAlign_Center)
			.VAlign(VAlign_Center)
			[
				Content
			];
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Class list

void SRPGClassList::Construct(const FArguments& InArgs)
{
	using namespace RPGMenuPrivate;

	SelectedClass = InArgs._SelectedClass;
	OnClassPicked = InArgs._OnClassPicked;

	TSharedRef<SVerticalBox> List = SNew(SVerticalBox);
	const ARPGPlayerController* Controller = InArgs._OwningController.Get();
	const URPGGameInstance* GameInstance = Controller ? Controller->GetGameInstance<URPGGameInstance>() : nullptr;
	if (GameInstance)
	{
		for (const FRPGCharacterClassInfo& ClassInfo : GameInstance->GetCharacterClasses())
		{
			const FName ClassId = ClassInfo.Id;
			List->AddSlot()
				.AutoHeight()
				.Padding(0.f, 0.f, 0.f, 6.f)
				[
					SNew(SVerticalBox)
					+ SVerticalBox::Slot()
					.AutoHeight()
					[
						MakeButton(ClassInfo.DisplayName,
							FOnClicked::CreateLambda([this, ClassId]() { OnClassPicked.ExecuteIfBound(ClassId); return FReply::Handled(); }),
							TAttribute<bool>::CreateLambda([this, ClassId]() { return SelectedClass.Get() == ClassId; }),
							true, ClassInfo.Color)
					]
					+ SVerticalBox::Slot()
					.AutoHeight()
					.Padding(4.f, 3.f, 0.f, 0.f)
					[
						SNew(STextBlock)
						.Text(ClassInfo.Description)
						.Font(Font(11))
						.ColorAndOpacity(DimTextColor)
						.AutoWrapText(true)
					]
				];
		}
	}

	ChildSlot
	[
		List
	];
}

// ---------------------------------------------------------------------------------------------------------------------
// Main menu

void SRPGMainMenu::Construct(const FArguments& InArgs)
{
	using namespace RPGMenuPrivate;

	OwningController = InArgs._OwningController;
	const ARPGPlayerController* Controller = OwningController.Get();
	const URPGGameInstance* GameInstance = Controller ? Controller->GetGameInstance<URPGGameInstance>() : nullptr;
	const URPGSessionSubsystem* Session = GameInstance ? GameInstance->GetSubsystem<URPGSessionSubsystem>() : nullptr;
	if (!GameInstance || !Session)
	{
		return;
	}

	SelectedMap = FMath::Max(0, GameInstance->FindMapIndex(Controller->GetWorld()));

	// Map choice (used by Play offline and Host).
	TSharedRef<SVerticalBox> MapList = SNew(SVerticalBox);
	for (int32 Index = 0; Index < GameInstance->GetMaps().Num(); ++Index)
	{
		const FRPGMapInfo& Map = GameInstance->GetMaps()[Index];
		MapList->AddSlot()
			.AutoHeight()
			.Padding(0.f, 0.f, 0.f, 6.f)
			[
				SNew(SVerticalBox)
				+ SVerticalBox::Slot()
				.AutoHeight()
				[
					MakeButton(Map.DisplayName,
						FOnClicked::CreateLambda([this, Index]() { SelectedMap = Index; return FReply::Handled(); }),
						TAttribute<bool>::CreateLambda([this, Index]() { return SelectedMap == Index; }))
				]
				+ SVerticalBox::Slot()
				.AutoHeight()
				.Padding(4.f, 3.f, 0.f, 0.f)
				[
					SNew(STextBlock).Text(Map.Description).Font(Font(11)).ColorAndOpacity(DimTextColor).AutoWrapText(true)
				]
			];
	}

	const FString LocalAddress = Session->GetLocalAddressHint();
	const FText HostHint = LocalAddress.IsEmpty()
		? LOCTEXT("HostHintNoIp", "Other players join with your IP address.")
		: FText::Format(LOCTEXT("HostHint", "Other players join with your IP: {0} (same network). Over the internet: your public IP, with UDP port {1} forwarded to this PC."),
			FText::FromString(LocalAddress), FText::AsNumber(URPGSessionSubsystem::GetGamePort(), &FNumberFormattingOptions::DefaultNoGrouping()));

	const TAttribute<bool> Idle = TAttribute<bool>::CreateSP(this, &SRPGMainMenu::IsIdle);

	TSharedRef<SWidget> LeftColumn =
		SNew(SVerticalBox)
		+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 6.f)[Heading(LOCTEXT("NameHeading", "YOUR NAME"))]
		+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 18.f)
		[
			SAssignNew(NameBox, SEditableTextBox)
			.Text(FText::FromString(GameInstance->GetPlayerName()))
			.Font(Font(15))
			.OnTextCommitted_Lambda([this](const FText&, ETextCommit::Type) { CommitName(); })
		]
		+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 6.f)[Heading(LOCTEXT("ClassHeading", "CLASS"))]
		+ SVerticalBox::Slot().AutoHeight()
		[
			SNew(SRPGClassList)
			.OwningController(OwningController)
			.SelectedClass_Lambda([this]()
			{
				const ARPGPlayerController* PC = OwningController.Get();
				const URPGGameInstance* GI = PC ? PC->GetGameInstance<URPGGameInstance>() : nullptr;
				return GI ? GI->GetSelectedClassId() : NAME_None;
			})
			.OnClassPicked_Lambda([this](FName ClassId)
			{
				if (ARPGPlayerController* PC = OwningController.Get())
				{
					PC->SelectCharacterClass(ClassId);
				}
			})
		];

	TSharedRef<SWidget> RightColumn =
		SNew(SVerticalBox)
		+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 6.f)[Heading(LOCTEXT("MapHeading", "MAP"))]
		+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 10.f)[MapList]
		+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 6.f)
		[
			SNew(SHorizontalBox)
			+ SHorizontalBox::Slot().FillWidth(1.f).Padding(0.f, 0.f, 6.f, 0.f)
			[
				MakeButton(LOCTEXT("PlayOffline", "PLAY OFFLINE"), FOnClicked::CreateSP(this, &SRPGMainMenu::HandlePlay, false), false, Idle)
			]
			+ SHorizontalBox::Slot().FillWidth(1.f)
			[
				MakeButton(LOCTEXT("Host", "HOST GAME"), FOnClicked::CreateSP(this, &SRPGMainMenu::HandlePlay, true), true, Idle)
			]
		]
		+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 20.f)
		[
			SNew(STextBlock).Text(HostHint).Font(Font(11)).ColorAndOpacity(DimTextColor).AutoWrapText(true)
		]
		+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 0.f, 0.f, 6.f)[Heading(LOCTEXT("JoinHeading", "JOIN A HOST"))]
		+ SVerticalBox::Slot().AutoHeight()
		[
			SNew(SHorizontalBox)
			+ SHorizontalBox::Slot().FillWidth(1.f).Padding(0.f, 0.f, 6.f, 0.f)
			[
				SAssignNew(AddressBox, SEditableTextBox)
				.Text(FText::FromString(GameInstance->GetLastJoinAddress()))
				.HintText(LOCTEXT("AddressHint", "Host IP, e.g. 192.168.1.20"))
				.Font(Font(15))
				.IsEnabled(Idle)
				.OnTextCommitted_Lambda([this](const FText&, ETextCommit::Type CommitType)
				{
					if (CommitType == ETextCommit::OnEnter)
					{
						HandleJoin();
					}
				})
			]
			+ SHorizontalBox::Slot().AutoWidth()
			[
				SNew(SBox)
				.Visibility_Lambda([this]() { return IsIdle() ? EVisibility::Visible : EVisibility::Collapsed; })
				[
					MakeButton(LOCTEXT("Join", "JOIN"), FOnClicked::CreateSP(this, &SRPGMainMenu::HandleJoin), true)
				]
			]
			+ SHorizontalBox::Slot().AutoWidth()
			[
				SNew(SBox)
				.Visibility_Lambda([this]() { return IsIdle() ? EVisibility::Collapsed : EVisibility::Visible; })
				[
					MakeButton(LOCTEXT("Cancel", "CANCEL"), FOnClicked::CreateSP(this, &SRPGMainMenu::HandleCancelJoin))
				]
			]
		];

	ChildSlot
	[
		Backdropped(Panel(
			SNew(SVerticalBox)
			+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0.f, 0.f, 0.f, 4.f)
			[
				SNew(STextBlock).Text(LOCTEXT("Title", "RPG TEST")).Font(Font(34, true)).ColorAndOpacity(GoldColor)
			]
			+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0.f, 0.f, 0.f, 20.f)
			[
				SNew(STextBlock).Text(LOCTEXT("Subtitle", "Deathmatch: every other player is an enemy.")).Font(Font(12)).ColorAndOpacity(DimTextColor)
			]
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SHorizontalBox)
				+ SHorizontalBox::Slot().FillWidth(1.f).Padding(0.f, 0.f, 24.f, 0.f)[LeftColumn]
				+ SHorizontalBox::Slot().FillWidth(1.2f)[RightColumn]
			]
			+ SVerticalBox::Slot().AutoHeight().Padding(0.f, 18.f, 0.f, 0.f)
			[
				SNew(STextBlock)
				.Text(this, &SRPGMainMenu::GetStatusText)
				.ColorAndOpacity(this, &SRPGMainMenu::GetStatusColor)
				.Font(Font(13, true))
				.AutoWrapText(true)
			],
			900.f))
	];
}

bool SRPGMainMenu::IsIdle() const
{
	const ARPGPlayerController* Controller = OwningController.Get();
	const URPGGameInstance* GameInstance = Controller ? Controller->GetGameInstance<URPGGameInstance>() : nullptr;
	const URPGSessionSubsystem* Session = GameInstance ? GameInstance->GetSubsystem<URPGSessionSubsystem>() : nullptr;
	return !Session || !Session->IsConnecting();
}

void SRPGMainMenu::CommitName()
{
	if (ARPGPlayerController* Controller = OwningController.Get(); Controller && NameBox.IsValid())
	{
		Controller->SetProfileName(NameBox->GetText().ToString());
		if (const URPGGameInstance* GameInstance = Controller->GetGameInstance<URPGGameInstance>())
		{
			NameBox->SetText(FText::FromString(GameInstance->GetPlayerName()));
		}
	}
}

FReply SRPGMainMenu::HandlePlay(bool bHost)
{
	CommitName();
	if (ARPGPlayerController* Controller = OwningController.Get())
	{
		FText Error;
		if (!Controller->MainMenuPlay(SelectedMap, bHost, Error))
		{
			LocalMessage = Error;
		}
	}
	return FReply::Handled();
}

FReply SRPGMainMenu::HandleJoin()
{
	CommitName();
	if (ARPGPlayerController* Controller = OwningController.Get(); Controller && AddressBox.IsValid())
	{
		FText Error;
		LocalMessage = Controller->MainMenuJoin(AddressBox->GetText().ToString(), Error) ? FText::GetEmpty() : Error;
	}
	return FReply::Handled();
}

FReply SRPGMainMenu::HandleCancelJoin()
{
	if (ARPGPlayerController* Controller = OwningController.Get())
	{
		Controller->MainMenuCancelJoin();
	}
	return FReply::Handled();
}

FText SRPGMainMenu::GetStatusText() const
{
	const ARPGPlayerController* Controller = OwningController.Get();
	const URPGGameInstance* GameInstance = Controller ? Controller->GetGameInstance<URPGGameInstance>() : nullptr;
	const URPGSessionSubsystem* Session = GameInstance ? GameInstance->GetSubsystem<URPGSessionSubsystem>() : nullptr;
	if (!Session)
	{
		return FText::GetEmpty();
	}
	if (Session->IsConnecting())
	{
		return FText::Format(LOCTEXT("Connecting", "Connecting to {0}..."), FText::FromString(Session->GetConnectingAddress()));
	}
	if (!LocalMessage.IsEmpty())
	{
		return LocalMessage;
	}
	return Session->GetLastError();
}

FSlateColor SRPGMainMenu::GetStatusColor() const
{
	return IsIdle() ? RPGMenuPrivate::ErrorColor : RPGMenuPrivate::GoodColor;
}

// ---------------------------------------------------------------------------------------------------------------------
// In-game class picker

void SRPGClassPicker::Construct(const FArguments& InArgs)
{
	using namespace RPGMenuPrivate;

	OwningController = InArgs._OwningController;

	ChildSlot
	[
		Backdropped(Panel(
			SNew(SVerticalBox)
			+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0.f, 0.f, 0.f, 16.f)
			[
				SNew(STextBlock).Text(LOCTEXT("PickerTitle", "CHOOSE YOUR CLASS")).Font(Font(26, true)).ColorAndOpacity(GoldColor)
			]
			+ SVerticalBox::Slot().AutoHeight()
			[
				SNew(SRPGClassList)
				.OwningController(OwningController)
				.SelectedClass_Lambda([this]()
				{
					const ARPGPlayerController* PC = OwningController.Get();
					return PC ? PC->GetCurrentCharacterClassId() : NAME_None;
				})
				.OnClassPicked_Lambda([this](FName ClassId)
				{
					if (ARPGPlayerController* PC = OwningController.Get())
					{
						PC->SelectCharacterClass(ClassId);
						PC->CloseClassPicker();
					}
				})
			]
			+ SVerticalBox::Slot().AutoHeight().HAlign(HAlign_Center).Padding(0.f, 14.f, 0.f, 0.f)
			[
				SNew(STextBlock)
				.Text(LOCTEXT("PickerHint", "Changing class respawns your character. F3 or Esc closes this."))
				.Font(Font(12))
				.ColorAndOpacity(DimTextColor)
			],
			460.f))
	];
}

FReply SRPGClassPicker::OnKeyDown(const FGeometry& MyGeometry, const FKeyEvent& InKeyEvent)
{
	if (InKeyEvent.GetKey() == EKeys::Escape || InKeyEvent.GetKey() == EKeys::F3)
	{
		if (ARPGPlayerController* Controller = OwningController.Get())
		{
			Controller->CloseClassPicker();
		}
		return FReply::Handled();
	}
	return SCompoundWidget::OnKeyDown(MyGeometry, InKeyEvent);
}

#undef LOCTEXT_NAMESPACE
