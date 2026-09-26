#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "InputActionValue.h"
#include "Core/RPGTypes.h"
#include "RPGPlayerController.generated.h"

class AMageCharacter;
class ARPGCharacterBase;
class UInputAction;
class UInputMappingContext;

/**
 * Owns the player's input. The Enhanced Input actions and mapping context are built in code so the controls
 * work without any input assets:
 *   WASD / arrows move, mouse looks (free orbit camera), wheel zooms, Space jumps, Shift sprints,
 *   1-5 cast the hotbar spells, F1 toggles the controls help, F2 opens the map selector.
 * The map selector opens by itself on the first level of a play session and pauses the game while it is shown.
 * Also exposes debug console commands (Rpg*).
 */
UCLASS()
class RPGTEST_API ARPGPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	ARPGPlayerController();

	bool IsHelpVisible() const { return bShowHelp; }

	bool IsMapSelectorOpen() const { return bMapSelectorOpen; }
	int32 GetMapSelectorIndex() const { return MapSelectorIndex; }

	/** Highlights a map selector entry (keyboard navigation or mouse hover). */
	void SetMapSelectorIndex(int32 Index);

	/** Toggles damage immunity for the player (health cannot drop below 1). */
	UFUNCTION(Exec)
	void RpgGod();

	/** Casts hotbar spell 1-5, as if the key had been pressed. */
	UFUNCTION(Exec)
	void RpgCast(int32 SlotNumber);

	/** Restores health and mana and clears spell cooldowns. */
	UFUNCTION(Exec)
	void RpgRefill();

	/** Teleports the player in front of the nearest living bot. */
	UFUNCTION(Exec)
	void RpgGoToBot();

	/** Logs the state of the player and every bot. */
	UFUNCTION(Exec)
	void RpgStatus();

	/** Casts every spell at the nearest bot and logs whether each one had its intended effect. */
	UFUNCTION(Exec)
	void RpgSelfTest();

	/** Plays map 1-N of the map selector list, as if it had been picked in the selector. */
	UFUNCTION(Exec)
	void RpgMap(int32 MapNumber);

protected:
	virtual void BeginPlay() override;
	virtual void SetupInputComponent() override;

private:
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
	void HandleSpell(int32 SlotIndex);

	// Map selector
	/** Shows the selector and pauses the game, optionally a moment later (lets the camera settle on the first frames). */
	void OpenMapSelector(float PauseDelay = 0.f);
	/** Hides the selector and resumes play on the current map. */
	void CloseMapSelector();
	void ConfirmMapSelection(int32 Index);
	void HandleToggleMapSelector();
	void HandleMenuUp();
	void HandleMenuDown();
	void HandleMenuConfirm();
	void HandleMenuClick();
	void HandleMenuQuickPick(int32 Index);

	void ReportCastResult(ERPGCastResult Result);
	void ShowMessage(const FString& Message, const FLinearColor& Color);
	AMageCharacter* GetMage() const;
	ARPGCharacterBase* FindNearestBot() const;
	void AimAt(const FVector& Location);
	void PlaceMageFacing(ARPGCharacterBase* Bot, float Distance);
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
	TArray<TObjectPtr<UInputAction>> SpellActions;

	UPROPERTY(Transient)
	TObjectPtr<UInputAction> MapSelectorAction;

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

	bool bShowHelp = true;
	bool bMapSelectorOpen = false;
	int32 MapSelectorIndex = 0;
	FTimerHandle MapSelectorPauseTimer;

	// Self-test state.
	int32 SelfTestStep = 0;
	int32 SelfTestPassed = 0;
	float SelfTestValue = 0.f;
	FVector SelfTestPosition = FVector::ZeroVector;
	TWeakObjectPtr<ARPGCharacterBase> SelfTestBot;
	FTimerHandle SelfTestTimer;
};
