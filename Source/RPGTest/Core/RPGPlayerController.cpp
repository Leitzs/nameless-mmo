#include "Core/RPGPlayerController.h"

#include "Abilities/RPGAbilitySystemComponent.h"
#include "Abilities/RPGGameplayAbility.h"
#include "Abilities/RPGGameplayTags.h"
#include "Abilities/RPGStatusEffects.h"
#include "Camera/PlayerCameraManager.h"
#include "Characters/EnemyBotCharacter.h"
#include "Characters/RPGPlayerCharacter.h"
#include "Core/RPGGameInstance.h"
#include "Core/RPGPlayerState.h"
#include "Core/RPGTestGameMode.h"
#include "Engine/Engine.h"
#include "Engine/GameViewportClient.h"
#include "Engine/LocalPlayer.h"
#include "EngineUtils.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "InputAction.h"
#include "InputCoreTypes.h"
#include "InputMappingContext.h"
#include "InputModifiers.h"
#include "Misc/CommandLine.h"
#include "Net/RPGSessionSubsystem.h"
#include "RPGTest.h"
#include "TimerManager.h"
#include "UI/RPGHUD.h"
#include "UI/SRPGMenuWidgets.h"
#include "Widgets/SWeakWidget.h"

namespace RPGPlayerControllerPrivate
{
	constexpr int32 NumSpellSlots = 5;
	constexpr int32 NumQuickPickKeys = 9;
	constexpr int32 MenuContextPriority = 1;
	constexpr int32 MenuWidgetZOrder = 10;
	/** How long the world keeps running behind the menu opened at level start, so the camera boom can settle. */
	constexpr float StartupMenuPauseDelay = 0.3f;
	constexpr float SelfTestStepInterval = 0.6f;

	URPGSessionSubsystem* GetSession(const APlayerController* Controller)
	{
		const UGameInstance* GameInstance = Controller ? Controller->GetGameInstance() : nullptr;
		return GameInstance ? GameInstance->GetSubsystem<URPGSessionSubsystem>() : nullptr;
	}

	/** Debug text: the character's active statuses. */
	FString DescribeStatuses(const ARPGCharacterBase& Character)
	{
		TArray<FString> Names;
		for (const FRPGStatusDefinition& Definition : RPGStatusEffects::GetDefinitions())
		{
			if (Character.HasStatus(Definition.Tag))
			{
				Names.Add(Definition.DisplayName.ToString());
			}
		}
		return FString::Join(Names, TEXT(", "));
	}

	UGameViewportClient* GetViewport(const APlayerController* Controller)
	{
		const ULocalPlayer* LocalPlayer = Controller->GetLocalPlayer();
		return LocalPlayer && LocalPlayer->ViewportClient ? LocalPlayer->ViewportClient.Get() : (GEngine ? GEngine->GameViewport.Get() : nullptr);
	}
}

using RPGPlayerControllerPrivate::GetSession;

ARPGPlayerController::ARPGPlayerController()
{
	bShowMouseCursor = false;
}

void ARPGPlayerController::BeginPlay()
{
	Super::BeginPlay();

	if (!IsLocalController())
	{
		return;
	}

	BuildInputActions();
	if (UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer()))
	{
		Subsystem->AddMappingContext(DefaultMappingContext, 0);
	}

	SetInputMode(FInputModeGameOnly());
	bShowMouseCursor = false;

	if (PlayerCameraManager)
	{
		PlayerCameraManager->ViewPitchMin = -70.f;
		PlayerCameraManager->ViewPitchMax = 40.f;
	}

#if !UE_BUILD_SHIPPING
	// Automated test hook: -RPGAutoSelfTest=All (or a class id) runs the self test once the level has settled.
	FString AutoSelfTest;
	if (FParse::Value(FCommandLine::Get(), TEXT("RPGAutoSelfTest="), AutoSelfTest))
	{
		FTimerHandle AutoTestTimer;
		GetWorldTimerManager().SetTimer(AutoTestTimer, FTimerDelegate::CreateWeakLambda(this, [this, AutoSelfTest]() { RpgSelfTest(AutoSelfTest); }), 4.f, false);
	}
#endif

	URPGSessionSubsystem* Session = GetSession(this);
	if (!Session)
	{
		return;
	}

	if (GetNetMode() != NM_Standalone)
	{
		// Hosting or connected: the join (if any) worked.
		Session->NotifyEnteredNetworkGame();
	}
	else if (Session->ShouldShowMainMenu())
	{
		OpenMainMenu(RPGPlayerControllerPrivate::StartupMenuPauseDelay);
	}
}

void ARPGPlayerController::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
	// The game viewport outlives the level: take the menus down with the controller.
	HideMenuWidget(MainMenuWidget);
	HideMenuWidget(ClassPickerWidget);
	Super::EndPlay(EndPlayReason);
}

UInputAction* ARPGPlayerController::MakeAction(const TCHAR* Name, EInputActionValueType ValueType, bool bTriggerWhenPaused)
{
	UInputAction* Action = NewObject<UInputAction>(this, Name);
	Action->ValueType = ValueType;
	Action->bTriggerWhenPaused = bTriggerWhenPaused;
	return Action;
}

void ARPGPlayerController::BuildInputActions()
{
	if (DefaultMappingContext)
	{
		return;
	}

	MoveAction = MakeAction(TEXT("IA_Move"), EInputActionValueType::Axis2D);
	LookAction = MakeAction(TEXT("IA_Look"), EInputActionValueType::Axis2D);
	ZoomAction = MakeAction(TEXT("IA_Zoom"), EInputActionValueType::Axis1D);
	JumpAction = MakeAction(TEXT("IA_Jump"), EInputActionValueType::Boolean);
	SprintAction = MakeAction(TEXT("IA_Sprint"), EInputActionValueType::Boolean);
	HelpAction = MakeAction(TEXT("IA_Help"), EInputActionValueType::Boolean);
	MapSelectorAction = MakeAction(TEXT("IA_MapSelector"), EInputActionValueType::Boolean, true);
	ClassPickerAction = MakeAction(TEXT("IA_ClassPicker"), EInputActionValueType::Boolean, true);
	LeaveGameAction = MakeAction(TEXT("IA_LeaveGame"), EInputActionValueType::Boolean, true);
	ScoreboardAction = MakeAction(TEXT("IA_Scoreboard"), EInputActionValueType::Boolean);

	DefaultMappingContext = NewObject<UInputMappingContext>(this, TEXT("IMC_RPGDefault"));
	UInputMappingContext* Context = DefaultMappingContext;

	// Move is (Forward, Right): forward keys feed X, strafe keys are swizzled into Y.
	auto MapMoveKey = [this, Context](const FKey& Key, bool bStrafe, bool bNegate)
	{
		FEnhancedActionKeyMapping& Mapping = Context->MapKey(MoveAction, Key);
		if (bStrafe)
		{
			Mapping.Modifiers.Add(NewObject<UInputModifierSwizzleAxis>(Context));
		}
		if (bNegate)
		{
			Mapping.Modifiers.Add(NewObject<UInputModifierNegate>(Context));
		}
	};
	MapMoveKey(EKeys::W, false, false);
	MapMoveKey(EKeys::S, false, true);
	MapMoveKey(EKeys::D, true, false);
	MapMoveKey(EKeys::A, true, true);
	MapMoveKey(EKeys::Up, false, false);
	MapMoveKey(EKeys::Down, false, true);
	MapMoveKey(EKeys::Right, true, false);
	MapMoveKey(EKeys::Left, true, true);

	Context->MapKey(LookAction, EKeys::Mouse2D);
	Context->MapKey(ZoomAction, EKeys::MouseWheelAxis);
	Context->MapKey(JumpAction, EKeys::SpaceBar);
	Context->MapKey(SprintAction, EKeys::LeftShift);
	Context->MapKey(HelpAction, EKeys::F1);
	Context->MapKey(MapSelectorAction, EKeys::F2);
	Context->MapKey(ClassPickerAction, EKeys::F3);
	Context->MapKey(LeaveGameAction, EKeys::F10);
	Context->MapKey(ScoreboardAction, EKeys::Tab);

	// Hotbar: slot 0 is the basic attack (left mouse), slots 1-5 the number keys.
	BasicAttackAction = MakeAction(TEXT("IA_BasicAttack"), EInputActionValueType::Boolean);
	Context->MapKey(BasicAttackAction, EKeys::LeftMouseButton);

	const FKey SpellKeys[RPGPlayerControllerPrivate::NumSpellSlots] = { EKeys::One, EKeys::Two, EKeys::Three, EKeys::Four, EKeys::Five };
	for (int32 Index = 0; Index < RPGPlayerControllerPrivate::NumSpellSlots; ++Index)
	{
		UInputAction* SpellAction = MakeAction(*FString::Printf(TEXT("IA_Spell%d"), Index + 1), EInputActionValueType::Boolean);
		SpellActions.Add(SpellAction);
		Context->MapKey(SpellAction, SpellKeys[Index]);
	}

	// Map selector navigation. Higher priority than the default context, so these keys stop moving/casting while it is open.
	MenuUpAction = MakeAction(TEXT("IA_MenuUp"), EInputActionValueType::Boolean, true);
	MenuDownAction = MakeAction(TEXT("IA_MenuDown"), EInputActionValueType::Boolean, true);
	MenuConfirmAction = MakeAction(TEXT("IA_MenuConfirm"), EInputActionValueType::Boolean, true);
	MenuClickAction = MakeAction(TEXT("IA_MenuClick"), EInputActionValueType::Boolean, true);

	MenuMappingContext = NewObject<UInputMappingContext>(this, TEXT("IMC_RPGMenu"));
	MenuMappingContext->MapKey(MenuUpAction, EKeys::Up);
	MenuMappingContext->MapKey(MenuUpAction, EKeys::W);
	MenuMappingContext->MapKey(MenuDownAction, EKeys::Down);
	MenuMappingContext->MapKey(MenuDownAction, EKeys::S);
	MenuMappingContext->MapKey(MenuConfirmAction, EKeys::Enter);
	MenuMappingContext->MapKey(MenuConfirmAction, EKeys::SpaceBar);
	MenuMappingContext->MapKey(MenuClickAction, EKeys::LeftMouseButton);

	const FKey QuickPickKeys[RPGPlayerControllerPrivate::NumQuickPickKeys] = { EKeys::One, EKeys::Two, EKeys::Three, EKeys::Four, EKeys::Five, EKeys::Six, EKeys::Seven, EKeys::Eight, EKeys::Nine };
	for (int32 Index = 0; Index < RPGPlayerControllerPrivate::NumQuickPickKeys; ++Index)
	{
		UInputAction* PickAction = MakeAction(*FString::Printf(TEXT("IA_MenuPick%d"), Index + 1), EInputActionValueType::Boolean, true);
		MenuQuickPickActions.Add(PickAction);
		MenuMappingContext->MapKey(PickAction, QuickPickKeys[Index]);
	}
}

void ARPGPlayerController::SetupInputComponent()
{
	Super::SetupInputComponent();

	BuildInputActions();

	UEnhancedInputComponent* EnhancedInput = Cast<UEnhancedInputComponent>(InputComponent);
	if (!EnhancedInput)
	{
		UE_LOG(LogRPG, Error, TEXT("RPGPlayerController requires the Enhanced Input component (check DefaultInput.ini)."));
		return;
	}

	EnhancedInput->BindAction(MoveAction, ETriggerEvent::Triggered, this, &ThisClass::HandleMove);
	EnhancedInput->BindAction(LookAction, ETriggerEvent::Triggered, this, &ThisClass::HandleLook);
	EnhancedInput->BindAction(ZoomAction, ETriggerEvent::Triggered, this, &ThisClass::HandleZoom);
	EnhancedInput->BindAction(JumpAction, ETriggerEvent::Started, this, &ThisClass::HandleJumpStarted);
	EnhancedInput->BindAction(JumpAction, ETriggerEvent::Completed, this, &ThisClass::HandleJumpCompleted);
	EnhancedInput->BindAction(SprintAction, ETriggerEvent::Started, this, &ThisClass::HandleSprintStarted);
	EnhancedInput->BindAction(SprintAction, ETriggerEvent::Completed, this, &ThisClass::HandleSprintCompleted);
	EnhancedInput->BindAction(HelpAction, ETriggerEvent::Started, this, &ThisClass::HandleToggleHelp);
	EnhancedInput->BindAction(MapSelectorAction, ETriggerEvent::Started, this, &ThisClass::HandleToggleMapSelector);
	EnhancedInput->BindAction(ClassPickerAction, ETriggerEvent::Started, this, &ThisClass::HandleToggleClassPicker);
	EnhancedInput->BindAction(LeaveGameAction, ETriggerEvent::Started, this, &ThisClass::HandleLeaveGame);
	EnhancedInput->BindAction(ScoreboardAction, ETriggerEvent::Started, this, &ThisClass::HandleScoreboardStarted);
	EnhancedInput->BindAction(ScoreboardAction, ETriggerEvent::Completed, this, &ThisClass::HandleScoreboardCompleted);

	// Holding the basic attack keeps attacking; failures (busy, cooldown) are silent.
	EnhancedInput->BindAction(BasicAttackAction, ETriggerEvent::Triggered, this, &ThisClass::HandleAbility, 0, false);
	for (int32 Index = 0; Index < SpellActions.Num(); ++Index)
	{
		EnhancedInput->BindAction(SpellActions[Index], ETriggerEvent::Started, this, &ThisClass::HandleAbility, Index + 1, true);
	}

	EnhancedInput->BindAction(MenuUpAction, ETriggerEvent::Started, this, &ThisClass::HandleMenuUp);
	EnhancedInput->BindAction(MenuDownAction, ETriggerEvent::Started, this, &ThisClass::HandleMenuDown);
	EnhancedInput->BindAction(MenuConfirmAction, ETriggerEvent::Started, this, &ThisClass::HandleMenuConfirm);
	EnhancedInput->BindAction(MenuClickAction, ETriggerEvent::Started, this, &ThisClass::HandleMenuClick);
	for (int32 Index = 0; Index < MenuQuickPickActions.Num(); ++Index)
	{
		EnhancedInput->BindAction(MenuQuickPickActions[Index], ETriggerEvent::Started, this, &ThisClass::HandleMenuQuickPick, Index);
	}
}

ARPGPlayerCharacter* ARPGPlayerController::GetPlayerCharacter() const
{
	return Cast<ARPGPlayerCharacter>(GetPawn());
}

void ARPGPlayerController::HandleMove(const FInputActionValue& Value)
{
	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		PlayerCharacter->Move(Value.Get<FVector2D>());
	}
}

void ARPGPlayerController::HandleLook(const FInputActionValue& Value)
{
	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		PlayerCharacter->Look(Value.Get<FVector2D>());
	}
}

void ARPGPlayerController::HandleZoom(const FInputActionValue& Value)
{
	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		PlayerCharacter->Zoom(Value.Get<float>());
	}
}

void ARPGPlayerController::HandleJumpStarted()
{
	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		PlayerCharacter->Jump();
	}
}

void ARPGPlayerController::HandleJumpCompleted()
{
	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		PlayerCharacter->StopJumping();
	}
}

void ARPGPlayerController::HandleSprintStarted()
{
	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		PlayerCharacter->SetSprinting(true);
	}
}

void ARPGPlayerController::HandleSprintCompleted()
{
	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		PlayerCharacter->SetSprinting(false);
	}
}

void ARPGPlayerController::HandleToggleHelp()
{
	bShowHelp = !bShowHelp;
}

void ARPGPlayerController::HandleScoreboardStarted()
{
	bShowScoreboard = true;
}

void ARPGPlayerController::HandleScoreboardCompleted()
{
	bShowScoreboard = false;
}

void ARPGPlayerController::HandleAbility(int32 Slot, bool bReportFailure)
{
	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		const ERPGCastResult Result = PlayerCharacter->UseAbility(Slot);
		if (bReportFailure)
		{
			ReportCastResult(Result);
		}
	}
}

void ARPGPlayerController::ReportCastResult(ERPGCastResult Result)
{
	const ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter();
	switch (Result)
	{
	case ERPGCastResult::Cooldown:
		ShowMessage(TEXT("That ability is not ready yet"), FLinearColor(1.f, 0.8f, 0.3f));
		break;
	case ERPGCastResult::NotEnoughResource:
		if (PlayerCharacter)
		{
			const FRPGResourceConfig& Resource = PlayerCharacter->GetResourceConfig();
			ShowMessage(FString::Printf(TEXT("Not enough %s"), *Resource.GetDisplayName().ToString()), FLinearColor::LerpUsingHSV(Resource.GetColor(), FLinearColor::White, 0.4f));
		}
		break;
	case ERPGCastResult::Incapacitated:
		ShowMessage(TEXT("You cannot act right now"), FLinearColor(1.f, 0.5f, 0.4f));
		break;
	case ERPGCastResult::NoTarget:
		ShowMessage(TEXT("No target: aim at an enemy"), FLinearColor(1.f, 0.8f, 0.3f));
		break;
	case ERPGCastResult::OutOfRange:
		ShowMessage(TEXT("Target is too close"), FLinearColor(1.f, 0.8f, 0.3f));
		break;
	case ERPGCastResult::InCombat:
		ShowMessage(TEXT("You cannot hide while taking damage over time"), FLinearColor(1.f, 0.5f, 0.4f));
		break;
	case ERPGCastResult::Rooted:
		ShowMessage(TEXT("You cannot move right now"), FLinearColor(1.f, 0.5f, 0.4f));
		break;
	default:
		// Success, Busy (key mashing during a cast), Dead and Blocked need no feedback.
		break;
	}
}

void ARPGPlayerController::ShowMessage(const FString& Message, const FLinearColor& Color)
{
	if (ARPGHUD* RPGHUD = GetHUD<ARPGHUD>())
	{
		RPGHUD->ShowMessage(FText::FromString(Message), Color);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Class and name

FName ARPGPlayerController::GetCurrentCharacterClassId() const
{
	const ARPGPlayerState* RPGPlayerState = GetPlayerState<ARPGPlayerState>();
	return RPGPlayerState ? RPGPlayerState->GetCharacterClassId() : NAME_None;
}

void ARPGPlayerController::SelectCharacterClass(FName ClassId)
{
	if (URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>())
	{
		GameInstance->SetSelectedClassId(ClassId);
	}

	// From the main menu the choice is applied when the game starts; in game it applies right away.
	if (!MainMenuWidget.IsValid() && ClassId != GetCurrentCharacterClassId())
	{
		ServerSelectCharacterClass(ClassId);
	}
}

void ARPGPlayerController::ServerSelectCharacterClass_Implementation(FName ClassId)
{
	if (ARPGTestGameMode* GameMode = GetWorld()->GetAuthGameMode<ARPGTestGameMode>())
	{
		GameMode->ChangeCharacterClass(this, ClassId);
	}
}

void ARPGPlayerController::SetProfileName(const FString& Name)
{
	URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (!GameInstance)
	{
		return;
	}

	GameInstance->SetPlayerName(Name);
	if (PlayerState && PlayerState->GetPlayerName() != GameInstance->GetPlayerName())
	{
		ServerSetPlayerName(GameInstance->GetPlayerName());
	}
}

void ARPGPlayerController::ServerSetPlayerName_Implementation(const FString& Name)
{
	if (ARPGTestGameMode* GameMode = GetWorld()->GetAuthGameMode<ARPGTestGameMode>())
	{
		GameMode->ChangePlayerName(this, Name);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Slate menus

void ARPGPlayerController::ShowMenuWidget(const TSharedRef<SWidget>& Widget)
{
	if (UGameViewportClient* Viewport = RPGPlayerControllerPrivate::GetViewport(this))
	{
		Viewport->AddViewportWidgetContent(Widget, RPGPlayerControllerPrivate::MenuWidgetZOrder);
	}

	FInputModeUIOnly InputMode;
	InputMode.SetWidgetToFocus(Widget);
	InputMode.SetLockMouseToViewportBehavior(EMouseLockMode::DoNotLock);
	SetInputMode(InputMode);
	bShowMouseCursor = true;
}

void ARPGPlayerController::HideMenuWidget(TSharedPtr<SWidget>& Widget)
{
	if (!Widget.IsValid())
	{
		return;
	}

	if (UGameViewportClient* Viewport = RPGPlayerControllerPrivate::GetViewport(this))
	{
		Viewport->RemoveViewportWidgetContent(Widget.ToSharedRef());
	}
	Widget.Reset();
}

void ARPGPlayerController::RestoreGameInput()
{
	if (IsMenuOpen() || bMapSelectorOpen)
	{
		return;
	}
	SetInputMode(FInputModeGameOnly());
	bShowMouseCursor = false;
}

void ARPGPlayerController::SetMenuPause(bool bPaused, float Delay)
{
	GetWorldTimerManager().ClearTimer(MenuPauseTimer);

	// A networked game never pauses for one player's menu.
	if (GetNetMode() != NM_Standalone)
	{
		return;
	}

	if (bPaused && Delay > 0.f)
	{
		GetWorldTimerManager().SetTimer(MenuPauseTimer, FTimerDelegate::CreateWeakLambda(this, [this]() { SetPause(true); }), Delay, false);
	}
	else
	{
		SetPause(bPaused);
	}
}

void ARPGPlayerController::OpenMainMenu(float PauseDelay)
{
	if (MainMenuWidget.IsValid() || !IsLocalController())
	{
		return;
	}

	CloseMapSelector();
	CloseClassPicker();

	MainMenuWidget = SNew(SRPGMainMenu).OwningController(this);
	ShowMenuWidget(MainMenuWidget.ToSharedRef());
	SetMenuPause(true, PauseDelay);
}

void ARPGPlayerController::CloseMainMenu()
{
	if (!MainMenuWidget.IsValid())
	{
		return;
	}

	HideMenuWidget(MainMenuWidget);
	SetMenuPause(false);
	RestoreGameInput();
}

bool ARPGPlayerController::MainMenuPlay(int32 MapIndex, bool bHost, FText& OutError)
{
	URPGSessionSubsystem* Session = GetSession(this);
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (!Session || !GameInstance)
	{
		return false;
	}

	// Offline on the map already loaded: just start playing (with the chosen class and name).
	if (!bHost && GetNetMode() == NM_Standalone && GameInstance->FindMapIndex(GetWorld()) == MapIndex)
	{
		Session->SetMainMenuHandled();
		Session->ClearLastError();
		CloseMainMenu();
		SelectCharacterClass(GameInstance->GetSelectedClassId());
		SetProfileName(GameInstance->GetPlayerName());
		return true;
	}

	return bHost ? Session->HostGame(MapIndex, OutError) : Session->PlayOffline(MapIndex, OutError);
}

bool ARPGPlayerController::MainMenuJoin(const FString& Address, FText& OutError)
{
	URPGSessionSubsystem* Session = GetSession(this);
	return Session && Session->JoinGame(Address, OutError);
}

void ARPGPlayerController::MainMenuCancelJoin()
{
	if (URPGSessionSubsystem* Session = GetSession(this))
	{
		Session->CancelJoin();
	}
}

void ARPGPlayerController::OpenClassPicker()
{
	if (ClassPickerWidget.IsValid() || MainMenuWidget.IsValid() || !IsLocalController())
	{
		return;
	}

	CloseMapSelector();
	ClassPickerWidget = SNew(SRPGClassPicker).OwningController(this);
	ShowMenuWidget(ClassPickerWidget.ToSharedRef());
}

void ARPGPlayerController::CloseClassPicker()
{
	if (ClassPickerWidget.IsValid())
	{
		HideMenuWidget(ClassPickerWidget);
		RestoreGameInput();
	}
}

void ARPGPlayerController::HandleToggleClassPicker()
{
	if (ClassPickerWidget.IsValid())
	{
		CloseClassPicker();
	}
	else
	{
		OpenClassPicker();
	}
}

void ARPGPlayerController::HandleLeaveGame()
{
	if (MainMenuWidget.IsValid())
	{
		return;
	}

	if (GetNetMode() == NM_Standalone)
	{
		OpenMainMenu();
	}
	else if (URPGSessionSubsystem* Session = GetSession(this))
	{
		Session->LeaveGame();
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Map selector

void ARPGPlayerController::OpenMapSelector()
{
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (bMapSelectorOpen || IsMenuOpen() || !IsLocalController() || !GameInstance || GameInstance->GetMaps().Num() == 0)
	{
		return;
	}

	if (GetNetMode() == NM_Client)
	{
		ShowMessage(TEXT("Only the host can change the map"), FLinearColor(1.f, 0.8f, 0.3f));
		return;
	}

	bMapSelectorOpen = true;
	MapSelectorIndex = FMath::Max(0, GameInstance->FindMapIndex(GetWorld()));

	if (UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer()))
	{
		Subsystem->AddMappingContext(MenuMappingContext, RPGPlayerControllerPrivate::MenuContextPriority);
	}

	SetMenuPause(true);
	FInputModeGameAndUI InputMode;
	InputMode.SetHideCursorDuringCapture(false);
	SetInputMode(InputMode);
	bShowMouseCursor = true;
}

void ARPGPlayerController::CloseMapSelector()
{
	if (!bMapSelectorOpen)
	{
		return;
	}

	bMapSelectorOpen = false;
	if (UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer()))
	{
		Subsystem->RemoveMappingContext(MenuMappingContext);
	}

	SetMenuPause(false);
	RestoreGameInput();
}

void ARPGPlayerController::SetMapSelectorIndex(int32 Index)
{
	if (const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>(); GameInstance && GameInstance->GetMaps().Num() > 0)
	{
		MapSelectorIndex = FMath::Clamp(Index, 0, GameInstance->GetMaps().Num() - 1);
	}
}

void ARPGPlayerController::ConfirmMapSelection(int32 Index)
{
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	URPGSessionSubsystem* Session = GetSession(this);
	if (!GameInstance || !Session || !GameInstance->GetMaps().IsValidIndex(Index))
	{
		ShowMessage(FString::Printf(TEXT("There is no map %d"), Index + 1), FLinearColor::Red);
		return;
	}

	CloseMapSelector();
	if (GameInstance->FindMapIndex(GetWorld()) == Index)
	{
		return;
	}

	FText Error;
	if (!Session->ChangeMap(Index, Error))
	{
		ShowMessage(Error.ToString(), FLinearColor::Red);
	}
}

void ARPGPlayerController::HandleToggleMapSelector()
{
	if (bMapSelectorOpen)
	{
		CloseMapSelector();
	}
	else
	{
		OpenMapSelector();
	}
}

void ARPGPlayerController::HandleMenuUp()
{
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (bMapSelectorOpen && GameInstance && GameInstance->GetMaps().Num() > 0)
	{
		const int32 NumMaps = GameInstance->GetMaps().Num();
		SetMapSelectorIndex((MapSelectorIndex - 1 + NumMaps) % NumMaps);
	}
}

void ARPGPlayerController::HandleMenuDown()
{
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (bMapSelectorOpen && GameInstance && GameInstance->GetMaps().Num() > 0)
	{
		SetMapSelectorIndex((MapSelectorIndex + 1) % GameInstance->GetMaps().Num());
	}
}

void ARPGPlayerController::HandleMenuConfirm()
{
	if (bMapSelectorOpen)
	{
		ConfirmMapSelection(MapSelectorIndex);
	}
}

void ARPGPlayerController::HandleMenuClick()
{
	float MouseX = 0.f;
	float MouseY = 0.f;
	const ARPGHUD* RPGHUD = GetHUD<ARPGHUD>();
	if (!bMapSelectorOpen || !RPGHUD || !GetMousePosition(MouseX, MouseY))
	{
		return;
	}

	const int32 Index = RPGHUD->GetMapSelectorEntryAt(FVector2D(MouseX, MouseY));
	if (Index != INDEX_NONE)
	{
		ConfirmMapSelection(Index);
	}
}

void ARPGPlayerController::HandleMenuQuickPick(int32 Index)
{
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (bMapSelectorOpen && GameInstance && GameInstance->GetMaps().IsValidIndex(Index))
	{
		ConfirmMapSelection(Index);
	}
}

// ---------------------------------------------------------------------------------------------------------------------
// Debug commands

bool ARPGPlayerController::CheckDebugAllowed()
{
	if (HasAuthority())
	{
		return true;
	}
	ShowMessage(TEXT("Debug commands only work offline or on the host"), FLinearColor::Red);
	return false;
}

void ARPGPlayerController::RpgGod()
{
	ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter();
	if (PlayerCharacter && CheckDebugAllowed())
	{
		URPGAbilitySystemComponent* AbilitySystem = PlayerCharacter->GetRPGAbilitySystem();
		AbilitySystem->SetInvulnerable(!AbilitySystem->IsInvulnerable());
		ShowMessage(AbilitySystem->IsInvulnerable() ? TEXT("God mode ON") : TEXT("God mode OFF"), FLinearColor::Yellow);
	}
}

void ARPGPlayerController::RpgCast(int32 SlotNumber)
{
	HandleAbility(SlotNumber, true);
}

void ARPGPlayerController::RpgMap(int32 MapNumber)
{
	ConfirmMapSelection(MapNumber - 1);
}

void ARPGPlayerController::RpgRefill()
{
	ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter();
	if (PlayerCharacter && CheckDebugAllowed())
	{
		URPGAbilitySystemComponent* AbilitySystem = PlayerCharacter->GetRPGAbilitySystem();
		AbilitySystem->RestoreAll();
		// Rage starts empty on a restore; a refill fills every resource.
		AbilitySystem->AddResource(PlayerCharacter->GetMaxResource());
		AbilitySystem->ResetCooldowns();
	}
}

ARPGCharacterBase* ARPGPlayerController::FindNearestBot() const
{
	const APawn* PlayerPawn = GetPawn();
	if (!PlayerPawn)
	{
		return nullptr;
	}

	AEnemyBotCharacter* Nearest = nullptr;
	float NearestDistance = TNumericLimits<float>::Max();
	for (TActorIterator<AEnemyBotCharacter> It(GetWorld()); It; ++It)
	{
		if (It->IsAlive())
		{
			const float Distance = FVector::Dist(It->GetActorLocation(), PlayerPawn->GetActorLocation());
			if (Distance < NearestDistance)
			{
				Nearest = *It;
				NearestDistance = Distance;
			}
		}
	}
	return Nearest;
}

void ARPGPlayerController::AimAt(const FVector& Location)
{
	const FVector From = PlayerCameraManager ? PlayerCameraManager->GetCameraLocation() : GetPawn()->GetActorLocation();
	SetControlRotation((Location - From).Rotation());
}

void ARPGPlayerController::PlaceCharacterFacing(ARPGCharacterBase* Bot, float Distance)
{
	ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter();
	if (!PlayerCharacter || !Bot)
	{
		return;
	}

	const FVector BotLocation = Bot->GetActorLocation();
	const FVector Offset = Bot->GetActorForwardVector().GetSafeNormal2D() * Distance;
	PlayerCharacter->TeleportTo(BotLocation + Offset + FVector(0.f, 0.f, 50.f), (-Offset).Rotation());
	SetControlRotation(FRotator(-10.f, (-Offset).Rotation().Yaw, 0.f));
}

void ARPGPlayerController::RpgGoToBot()
{
	if (!CheckDebugAllowed())
	{
		return;
	}

	if (ARPGCharacterBase* Bot = FindNearestBot())
	{
		PlaceCharacterFacing(Bot, 900.f);
	}
	else
	{
		ShowMessage(TEXT("No bot found"), FLinearColor::Red);
	}
}

void ARPGPlayerController::RpgStatus()
{
	using RPGPlayerControllerPrivate::DescribeStatuses;

	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		UE_LOG(LogRPG, Display, TEXT("Player %s: HP %.0f/%.0f %s %.0f/%.0f Shield %.0f statuses [%s] at %s"), *PlayerCharacter->GetCombatName(),
			PlayerCharacter->GetHealth(), PlayerCharacter->GetMaxHealth(), *PlayerCharacter->GetResourceConfig().GetDisplayName().ToString(),
			PlayerCharacter->GetResource(), PlayerCharacter->GetMaxResource(), PlayerCharacter->GetShield(), *DescribeStatuses(*PlayerCharacter),
			*PlayerCharacter->GetActorLocation().ToCompactString());
	}

	for (TActorIterator<AEnemyBotCharacter> It(GetWorld()); It; ++It)
	{
		UE_LOG(LogRPG, Display, TEXT("Bot %s: HP %.0f/%.0f statuses [%s] at %s"), *It->GetName(),
			It->GetHealth(), It->GetMaxHealth(), *DescribeStatuses(**It), *It->GetActorLocation().ToCompactString());
	}
}

void ARPGPlayerController::RpgSelfTest(const FString& ClassName)
{
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (!IsLocalController() || !GameInstance)
	{
		return;
	}

	SelfTestClassQueue.Reset();
	SelfTestClassSwitches = 0;
	SelfTestTotalPassed = 0;
	SelfTestTotalChecks = 0;
	if (ClassName.Equals(TEXT("All"), ESearchCase::IgnoreCase))
	{
		for (const FRPGCharacterClassInfo& ClassInfo : GameInstance->GetCharacterClasses())
		{
			SelfTestClassQueue.Add(ClassInfo.Id);
		}
	}
	else if (!ClassName.IsEmpty())
	{
		const FRPGCharacterClassInfo* ClassInfo = GameInstance->GetCharacterClasses().FindByPredicate([&ClassName](const FRPGCharacterClassInfo& Info) { return Info.Id.ToString().Equals(ClassName, ESearchCase::IgnoreCase); });
		if (!ClassInfo)
		{
			UE_LOG(LogRPG, Warning, TEXT("SelfTest: unknown class '%s'."), *ClassName);
			return;
		}
		SelfTestClassQueue.Add(ClassInfo->Id);
	}

	StartNextSelfTest();
}

void ARPGPlayerController::StartNextSelfTest()
{
	// Switch class first (the server respawns the pawn) and give the new pawn a moment to arrive.
	if (SelfTestClassQueue.Num() > 0)
	{
		const FName ClassId = SelfTestClassQueue[0];
		if (ClassId != GetCurrentCharacterClassId() && SelfTestClassSwitches++ < 5)
		{
			UE_LOG(LogRPG, Display, TEXT("SelfTest: switching to %s"), *ClassId.ToString());
			ServerSelectCharacterClass(ClassId);
			GetWorldTimerManager().SetTimer(SelfTestTimer, this, &ThisClass::StartNextSelfTest, 1.5f, false);
			return;
		}
		SelfTestClassSwitches = 0;
		SelfTestClassQueue.RemoveAt(0);
	}

	SelfTestStep = 0;
	SelfTestPassed = 0;

	// The most isolated bot (the test arena's duel bot), so other bots do not get in the way of aim and area effects.
	SelfTestBot = nullptr;
	float BestIsolation = -1.f;
	for (TActorIterator<AEnemyBotCharacter> It(GetWorld()); It; ++It)
	{
		if (!It->IsAlive())
		{
			continue;
		}
		float Isolation = TNumericLimits<float>::Max();
		for (TActorIterator<AEnemyBotCharacter> Other(GetWorld()); Other; ++Other)
		{
			if (*Other != *It && Other->IsAlive())
			{
				Isolation = FMath::Min(Isolation, static_cast<float>(FVector::Dist(It->GetActorLocation(), Other->GetActorLocation())));
			}
		}
		if (Isolation > BestIsolation)
		{
			SelfTestBot = *It;
			BestIsolation = Isolation;
		}
	}
	if (!GetPlayerCharacter() || !SelfTestBot.IsValid())
	{
		UE_LOG(LogRPG, Warning, TEXT("SelfTest: needs a living player and a living bot."));
		return;
	}

	UE_LOG(LogRPG, Display, TEXT("SelfTest: testing %s against %s (%s)"), *GetCurrentCharacterClassId().ToString(), *SelfTestBot->GetName(), HasAuthority() ? TEXT("host") : TEXT("remote client"));
	GetWorldTimerManager().SetTimer(SelfTestTimer, this, &ThisClass::RunSelfTestStep, RPGPlayerControllerPrivate::SelfTestStepInterval, true, 0.1f);
}

void ARPGPlayerController::RunSelfTestStep()
{
	using RPGPlayerControllerPrivate::DescribeStatuses;

	// Uses every hotbar slot of the current class on the nearest bot (keys 1-5, then the basic attack), from this
	// machine, so a remote client exercises the predicted path. Setup (placement, refills) is done by the server.
	static constexpr int32 SlotOrder[] = { 1, 2, 3, 4, 5, 0 };
	constexpr int32 NumChecks = UE_ARRAY_COUNT(SlotOrder);
	constexpr int32 StepsPerCheck = 6;

	ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter();
	ARPGCharacterBase* Bot = SelfTestBot.Get();
	if (!PlayerCharacter || !Bot || !Bot->IsAlive())
	{
		UE_LOG(LogRPG, Warning, TEXT("SelfTest: aborted at step %d (player or bot missing/dead)."), SelfTestStep);
		ServerSelfTestFinish(Bot);
		GetWorldTimerManager().ClearTimer(SelfTestTimer);
		return;
	}

	const URPGAbilitySystemComponent* AbilitySystem = PlayerCharacter->GetRPGAbilitySystem();
	const int32 Step = SelfTestStep++;
	const int32 CheckIndex = Step / StepsPerCheck;
	const int32 Phase = Step % StepsPerCheck;

	if (CheckIndex >= NumChecks)
	{
		UE_LOG(LogRPG, Display, TEXT("SelfTest: %s finished, %d/%d abilities activated."), *GetCurrentCharacterClassId().ToString(), SelfTestPassed, NumChecks);
		ServerSelfTestFinish(Bot);
		GetWorldTimerManager().ClearTimer(SelfTestTimer);
		SelfTestTotalPassed += SelfTestPassed;
		SelfTestTotalChecks += NumChecks;

		if (SelfTestClassQueue.Num() > 0)
		{
			StartNextSelfTest();
			return;
		}
		UE_LOG(LogRPG, Display, TEXT("SelfTest: all done, %d/%d abilities activated."), SelfTestTotalPassed, SelfTestTotalChecks);
		ShowMessage(FString::Printf(TEXT("Self test: %d/%d passed (see Output Log)"), SelfTestTotalPassed, SelfTestTotalChecks), SelfTestTotalPassed == SelfTestTotalChecks ? FLinearColor::Green : FLinearColor::Red);
		return;
	}

	const int32 Slot = SlotOrder[CheckIndex];
	const URPGGameplayAbility* Ability = AbilitySystem->GetSlotAbility(Slot);
	const FString AbilityName = Ability ? Ability->GetDisplayName().ToString() : TEXT("(empty slot)");

	if (Phase == 0)
	{
		// Melee and self abilities from close by, ranged ones from a distance (dashes need some).
		const float Range = Ability ? Ability->GetRange() : 0.f;
		// Crowd-control breakers are tested while stunned.
		ServerSelfTestSetup(Bot, Range <= 500.f ? 180.f : FMath::Min(1000.f, Range * 0.6f), Ability && Ability->IsUsableWhileIncapacitated());
		return;
	}

	if (Phase == 1 || Phase == 2)
	{
		// Once the placement has reached this machine: turn towards the bot, then aim from where the camera ended up
		// (the camera orbits the character, so a big turn moves it). The camera applies each rotation on its next update.
		if (Phase == 1)
		{
			SetControlRotation(FRotator(-10.f, (Bot->GetActorLocation() - PlayerCharacter->GetActorLocation()).Rotation().Yaw, 0.f));
		}
		else
		{
			AimAt(Bot->GetTargetPoint());
		}
		return;
	}

	if (Phase == 3)
	{
		SelfTestValue = Bot->GetHealth();
		SelfTestPosition = PlayerCharacter->GetActorLocation();
		SelfTestResult = PlayerCharacter->UseAbility(Slot);
		UE_LOG(LogRPG, Display, TEXT("SelfTest: slot %d '%s' result=%d"), Slot, *AbilityName, static_cast<int32>(SelfTestResult));
		FVector AimLocation;
		ARPGCharacterBase* AimTarget = nullptr;
		PlayerCharacter->ComputeAim(Ability ? Ability->GetRange() : 1000.f, AimLocation, AimTarget);
		UE_LOG(LogRPG, Verbose, TEXT("SelfTest: player at %s, bot at %s, distance %.0f, control %s, camera %s, aim %s on %s"), *PlayerCharacter->GetActorLocation().ToCompactString(),
			*Bot->GetActorLocation().ToCompactString(), FVector::Dist2D(PlayerCharacter->GetActorLocation(), Bot->GetActorLocation()), *GetControlRotation().ToCompactString(),
			PlayerCameraManager ? *PlayerCameraManager->GetCameraLocation().ToCompactString() : TEXT("?"), *AimLocation.ToCompactString(), AimTarget ? *AimTarget->GetName() : TEXT("nothing"));
		return;
	}

	if (Phase == 4)
	{
		// Leave time for projectiles and delayed strikes to land.
		return;
	}

	const bool bPassed = SelfTestResult == ERPGCastResult::Success;
	SelfTestPassed += bPassed ? 1 : 0;
	UE_LOG(LogRPG, Display, TEXT("SelfTest: %s -> %s (bot damage %.0f, bot statuses [%s] | player moved %.0f, %s %.0f/%.0f, shield %.0f, statuses [%s])"),
		*AbilityName, bPassed ? TEXT("PASS") : TEXT("FAIL"), SelfTestValue - Bot->GetHealth(), *DescribeStatuses(*Bot),
		FVector::Dist2D(SelfTestPosition, PlayerCharacter->GetActorLocation()), *PlayerCharacter->GetResourceConfig().GetDisplayName().ToString(),
		PlayerCharacter->GetResource(), PlayerCharacter->GetMaxResource(), PlayerCharacter->GetShield(), *DescribeStatuses(*PlayerCharacter));
}

void ARPGPlayerController::ServerSelfTestSetup_Implementation(ARPGCharacterBase* Bot, float Distance, bool bStunPlayer)
{
#if !UE_BUILD_SHIPPING
	ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter();
	if (!PlayerCharacter || !Bot)
	{
		return;
	}

	// Fresh start for both sides: nothing still running, full health and resource, no statuses or diminishing returns.
	URPGAbilitySystemComponent* AbilitySystem = PlayerCharacter->GetRPGAbilitySystem();
	AbilitySystem->CancelAllAbilities();
	AbilitySystem->SetInvulnerable(true);
	AbilitySystem->RestoreAll();
	AbilitySystem->AddResource(PlayerCharacter->GetMaxResource());
	AbilitySystem->ResetCooldowns();
	Bot->GetRPGAbilitySystem()->RestoreAll();

	// Every bot stands still (their AI would attack, break stealth, interrupt dashes...).
	for (TActorIterator<AEnemyBotCharacter> It(GetWorld()); It; ++It)
	{
		if (AController* BotController = It->GetController())
		{
			BotController->SetActorTickEnabled(false);
			BotController->StopMovement();
		}
	}

	PlaceCharacterFacing(Bot, Distance);
	if (bStunPlayer)
	{
		AbilitySystem->ApplyStatus(FRPGStatusSpec(RPGTags::Status_CC_Stun, 4.f), Bot);
	}
	UE_LOG(LogRPG, Verbose, TEXT("SelfTest: server placed player at %s"), *PlayerCharacter->GetActorLocation().ToCompactString());
#endif
}

void ARPGPlayerController::ServerSelfTestFinish_Implementation(ARPGCharacterBase* Bot)
{
#if !UE_BUILD_SHIPPING
	if (ARPGPlayerCharacter* PlayerCharacter = GetPlayerCharacter())
	{
		PlayerCharacter->GetRPGAbilitySystem()->SetInvulnerable(false);
	}
	for (TActorIterator<AEnemyBotCharacter> It(GetWorld()); It; ++It)
	{
		if (AController* BotController = It->GetController())
		{
			BotController->SetActorTickEnabled(true);
		}
	}
#endif
}
