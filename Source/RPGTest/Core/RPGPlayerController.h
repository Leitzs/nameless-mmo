#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "InputActionValue.h"
#include "Core/RPGTypes.h"
#include "RPGPlayerController.generated.h"

class ARPGCharacterBase;
class ARPGPlayerCharacter;
class SWidget;
class UInputAction;
class UInputMappingContext;

/**
 * Owns the player's input. The Enhanced Input actions and mapping context are built in code so the controls
 * work without any input assets:
 *   WASD / arrows move, mouse looks (free orbit camera), wheel zooms, Space jumps, Shift sprints,
 *   left mouse is the basic attack (hold to keep attacking), 1-5 use the hotbar abilities,
 *   F1 toggles the controls help, F2 opens the map selector, F3 the class picker,
 *   F10 leaves the current game (back to the main menu), Tab shows the scoreboard.
 * The main menu (offline / host / join by IP, name, class) opens by itself on the first level of a play session
 * and after leaving or losing a game. Menus pause the game only when playing offline.
 * Also exposes debug console commands (Rpg*), which only work offline or on the host.
 */
UCLASS()
class RPGTEST_API ARPGPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	ARPGPlayerController();

	bool IsHelpVisible() const { return bShowHelp; }
	bool IsScoreboardVisible() const { return bShowScoreboard; }

	bool IsMapSelectorOpen() const { return bMapSelectorOpen; }
	int32 GetMapSelectorIndex() const { return MapSelectorIndex; }

	/** Highlights a map selector entry (keyboard navigation or mouse hover). */
	void SetMapSelectorIndex(int32 Index);

	/** True while a full-screen Slate menu (main menu or class picker) is shown; the HUD hides its gameplay elements. */
	bool IsMenuOpen() const { return MainMenuWidget.IsValid() || ClassPickerWidget.IsValid(); }

	// Main menu actions.
	bool MainMenuPlay(int32 MapIndex, bool bHost, FText& OutError);
	bool MainMenuJoin(const FString& Address, FText& OutError);
	void MainMenuCancelJoin();

	/** Saves the class in the profile and, when in game, asks the server to switch to it. */
	void SelectCharacterClass(FName ClassId);
	void SetProfileName(const FString& Name);
	FName GetCurrentCharacterClassId() const;

	void OpenClassPicker();
	void CloseClassPicker();

	/** Shows the reason an ability failed ("Not enough mana", ...). */
	void ReportCastResult(ERPGCastResult Result);

	/** Toggles damage immunity for the player (health cannot drop below 1). */
	UFUNCTION(Exec)
	void RpgGod();

	/** Uses hotbar slot 1-5 (0 = basic attack), as if the key had been pressed. */
	UFUNCTION(Exec)
	void RpgCast(int32 SlotNumber);

	/** Restores health and the class resource, clears statuses and cooldowns. */
	UFUNCTION(Exec)
	void RpgRefill();

	/** Teleports the player in front of the nearest living bot. */
	UFUNCTION(Exec)
	void RpgGoToBot();

	/** Logs the state of the player and every bot. */
	UFUNCTION(Exec)
	void RpgStatus();

	/**
	 * Uses every ability of a class on the nearest bot and logs what each one did.
	 * No argument tests the current class; a class id (Mage, Warlock...) switches to it first; "All" tests every class.
	 * Works on the host and on a connected client (development builds): the abilities are used from this machine,
	 * so a client exercises the networked path. Launching with -RPGAutoSelfTest=<class|All> runs it after joining.
	 */
	UFUNCTION(Exec)
	void RpgSelfTest(const FString& ClassName = TEXT(""));

	/** Plays map 1-N of the map selector list, as if it had been picked in the selector. */
	UFUNCTION(Exec)
	void RpgMap(int32 MapNumber);

protected:
	virtual void BeginPlay() override;
	virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;
	virtual void SetupInputComponent() override;

private:
	UFUNCTION(Server, Reliable)
	void ServerSelectCharacterClass(FName ClassId);

	UFUNCTION(Server, Reliable)
	void ServerSetPlayerName(const FString& Name);

	/** Self test (development builds): resets the player and the bot and places the player Distance in front of it, stunned if asked. */
	UFUNCTION(Server, Reliable)
	void ServerSelfTestSetup(ARPGCharacterBase* Bot, float Distance, bool bStunPlayer);

	/** Self test (development builds): ends god mode and wakes the bot up. */
	UFUNCTION(Server, Reliable)
	void ServerSelfTestFinish(ARPGCharacterBase* Bot);

	void BuildInputActions();
	UInputAction* MakeAction(const TCHAR* Name, EInputActionValueType ValueType, bool bTriggerWhenPaused = false);

	void HandleMove(const FInputActionValue& Value);
	void HandleLook(const FInputActionValue& Value);
	void HandleZoom(const FInputActionValue& Value);
	void HandleJumpStarted();
	void HandleJumpCompleted();
	void HandleSprintStarted();
	void HandleSprintCompleted();
	void HandleToggleHelp();
	/** Uses the ability in a hotbar slot (0 = basic attack). */
	void HandleAbility(int32 Slot, bool bReportFailure);
	void HandleToggleClassPicker();
	void HandleLeaveGame();
	void HandleScoreboardStarted();
	void HandleScoreboardCompleted();

	// Slate menus
	void OpenMainMenu(float PauseDelay = 0.f);
	void CloseMainMenu();
	void ShowMenuWidget(const TSharedRef<SWidget>& Widget);
	void HideMenuWidget(TSharedPtr<SWidget>& Widget);
	/** Restores game input once no menu is open. */
	void RestoreGameInput();
	/** Pauses (offline only) while a menu is open, optionally a moment later so the camera can settle on the first frames. */
	void SetMenuPause(bool bPaused, float Delay = 0.f);

	// Map selector (Canvas, drawn by the HUD)
	void OpenMapSelector();
	void CloseMapSelector();
	void ConfirmMapSelection(int32 Index);
	void HandleToggleMapSelector();
	void HandleMenuUp();
	void HandleMenuDown();
	void HandleMenuConfirm();
	void HandleMenuClick();
	void HandleMenuQuickPick(int32 Index);

	void ShowMessage(const FString& Message, const FLinearColor& Color);
	/** Debug commands change server state: only offline or on the host. */
	bool CheckDebugAllowed();
	ARPGPlayerCharacter* GetPlayerCharacter() const;
	ARPGCharacterBase* FindNearestBot() const;
	void AimAt(const FVector& Location);
	void PlaceCharacterFacing(ARPGCharacterBase* Bot, float Distance);
	/** Starts the self test on the current pawn, or switches to the next queued class first. */
	void StartNextSelfTest();
	void RunSelfTestStep();

	UPROPERTY(Transient)
	TObjectPtr<UInputMappingContext> DefaultMappingContext;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> MoveAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> LookAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> ZoomAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> JumpAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> SprintAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> HelpAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> BasicAttackAction;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UInputAction>> SpellActions;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> MapSelectorAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> ClassPickerAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> LeaveGameAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> ScoreboardAction;

	/** Added on top of the default context while the map selector is open; its actions also fire while paused. */
	UPROPERTY(Transient)
	TObjectPtr<UInputMappingContext> MenuMappingContext;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> MenuUpAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> MenuDownAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> MenuConfirmAction;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> MenuClickAction;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UInputAction>> MenuQuickPickActions;

	TSharedPtr<SWidget> MainMenuWidget;
	TSharedPtr<SWidget> ClassPickerWidget;

	bool bShowHelp = true;
	bool bShowScoreboard = false;
	bool bMapSelectorOpen = false;
	int32 MapSelectorIndex = 0;
	FTimerHandle MenuPauseTimer;

	// Self-test state.
	int32 SelfTestStep = 0;
	int32 SelfTestPassed = 0;
	float SelfTestValue = 0.f;
	FVector SelfTestPosition = FVector::ZeroVector;
	ERPGCastResult SelfTestResult = ERPGCastResult::Success;
	/** Classes still to test (RpgSelfTest All). */
	TArray<FName> SelfTestClassQueue;
	int32 SelfTestClassSwitches = 0;
	int32 SelfTestTotalPassed = 0;
	int32 SelfTestTotalChecks = 0;
	TWeakObjectPtr<ARPGCharacterBase> SelfTestBot;
	FTimerHandle SelfTestTimer;
};
