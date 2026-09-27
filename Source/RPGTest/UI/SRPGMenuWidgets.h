#pragma once

#include "CoreMinimal.h"
#include "Widgets/DeclarativeSyntaxSupport.h"
#include "Widgets/SCompoundWidget.h"

class ARPGPlayerController;
class SEditableTextBox;
class SVerticalBox;

DECLARE_DELEGATE_OneParam(FOnRPGClassPicked, FName /*ClassId*/);

/** Vertical list of the playable classes (URPGGameInstance::GetCharacterClasses) with the selected one highlighted. */
class SRPGClassList : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SRPGClassList) {}
		SLATE_ARGUMENT(TWeakObjectPtr<ARPGPlayerController>, OwningController)
		SLATE_ATTRIBUTE(FName, SelectedClass)
		SLATE_EVENT(FOnRPGClassPicked, OnClassPicked)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

private:
	TAttribute<FName> SelectedClass;
	FOnRPGClassPicked OnClassPicked;
};

/**
 * First screen of a play session (and after leaving or losing a game): player name, class, map,
 * and the three ways to play: offline, host a game, or join a host by IP.
 */
class SRPGMainMenu : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SRPGMainMenu) {}
		SLATE_ARGUMENT(TWeakObjectPtr<ARPGPlayerController>, OwningController)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

	virtual bool SupportsKeyboardFocus() const override { return true; }

private:
	FReply HandlePlay(bool bHost);
	FReply HandleJoin();
	FReply HandleCancelJoin();
	void CommitName();
	FText GetStatusText() const;
	FSlateColor GetStatusColor() const;
	bool IsIdle() const;

	TWeakObjectPtr<ARPGPlayerController> OwningController;
	TSharedPtr<SEditableTextBox> NameBox;
	TSharedPtr<SEditableTextBox> AddressBox;
	int32 SelectedMap = 0;
	FText LocalMessage;
};

/** In-game class picker (F3): changing class respawns the character as the new class. */
class SRPGClassPicker : public SCompoundWidget
{
public:
	SLATE_BEGIN_ARGS(SRPGClassPicker) {}
		SLATE_ARGUMENT(TWeakObjectPtr<ARPGPlayerController>, OwningController)
	SLATE_END_ARGS()

	void Construct(const FArguments& InArgs);

	virtual bool SupportsKeyboardFocus() const override { return true; }
	virtual FReply OnKeyDown(const FGeometry& MyGeometry, const FKeyEvent& InKeyEvent) override;

private:
	TWeakObjectPtr<ARPGPlayerController> OwningController;
};
