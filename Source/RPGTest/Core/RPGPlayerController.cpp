#include "Core/RPGPlayerController.h"

#include "Camera/PlayerCameraManager.h"
#include "Characters/EnemyBotCharacter.h"
#include "Characters/MageCharacter.h"
#include "Components/RPGAttributeComponent.h"
#include "Components/RPGSpellbookComponent.h"
#include "Components/RPGStatusEffectComponent.h"
#include "EngineUtils.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "Engine/LocalPlayer.h"
#include "InputAction.h"
#include "InputCoreTypes.h"
#include "InputMappingContext.h"
#include "InputModifiers.h"
#include "RPGTest.h"
#include "Spells/RPGSpell.h"
#include "TimerManager.h"
#include "UI/RPGHUD.h"

namespace RPGPlayerControllerPrivate
{
	constexpr int32 NumSpellSlots = 5;
	constexpr float SelfTestStepInterval = 1.5f;
}

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
}

UInputAction* ARPGPlayerController::MakeAction(const TCHAR* Name, EInputActionValueType ValueType)
{
	UInputAction* Action = NewObject<UInputAction>(this, Name);
	Action->ValueType = ValueType;
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

	const FKey SpellKeys[RPGPlayerControllerPrivate::NumSpellSlots] = { EKeys::One, EKeys::Two, EKeys::Three, EKeys::Four, EKeys::Five };
	for (int32 Slot = 0; Slot < RPGPlayerControllerPrivate::NumSpellSlots; ++Slot)
	{
		UInputAction* SpellAction = MakeAction(*FString::Printf(TEXT("IA_Spell%d"), Slot + 1), EInputActionValueType::Boolean);
		SpellActions.Add(SpellAction);
		Context->MapKey(SpellAction, SpellKeys[Slot]);
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

	for (int32 Slot = 0; Slot < SpellActions.Num(); ++Slot)
	{
		EnhancedInput->BindAction(SpellActions[Slot], ETriggerEvent::Started, this, &ThisClass::HandleSpell, Slot);
	}
}

AMageCharacter* ARPGPlayerController::GetMage() const
{
	return Cast<AMageCharacter>(GetPawn());
}

void ARPGPlayerController::HandleMove(const FInputActionValue& Value)
{
	if (AMageCharacter* Mage = GetMage())
	{
		Mage->Move(Value.Get<FVector2D>());
	}
}

void ARPGPlayerController::HandleLook(const FInputActionValue& Value)
{
	if (AMageCharacter* Mage = GetMage())
	{
		Mage->Look(Value.Get<FVector2D>());
	}
}

void ARPGPlayerController::HandleZoom(const FInputActionValue& Value)
{
	if (AMageCharacter* Mage = GetMage())
	{
		Mage->Zoom(Value.Get<float>());
	}
}

void ARPGPlayerController::HandleJumpStarted()
{
	if (AMageCharacter* Mage = GetMage())
	{
		Mage->Jump();
	}
}

void ARPGPlayerController::HandleJumpCompleted()
{
	if (AMageCharacter* Mage = GetMage())
	{
		Mage->StopJumping();
	}
}

void ARPGPlayerController::HandleSprintStarted()
{
	if (AMageCharacter* Mage = GetMage())
	{
		Mage->SetSprinting(true);
	}
}

void ARPGPlayerController::HandleSprintCompleted()
{
	if (AMageCharacter* Mage = GetMage())
	{
		Mage->SetSprinting(false);
	}
}

void ARPGPlayerController::HandleToggleHelp()
{
	bShowHelp = !bShowHelp;
}

void ARPGPlayerController::HandleSpell(int32 SlotIndex)
{
	if (AMageCharacter* Mage = GetMage())
	{
		ReportCastResult(Mage->CastSpell(SlotIndex));
	}
}

void ARPGPlayerController::ReportCastResult(ERPGCastResult Result)
{
	switch (Result)
	{
	case ERPGCastResult::Cooldown:
		ShowMessage(TEXT("That spell is not ready yet"), FLinearColor(1.f, 0.8f, 0.3f));
		break;
	case ERPGCastResult::NotEnoughMana:
		ShowMessage(TEXT("Not enough mana"), FLinearColor(0.4f, 0.6f, 1.f));
		break;
	case ERPGCastResult::Incapacitated:
		ShowMessage(TEXT("You cannot cast right now"), FLinearColor(1.f, 0.5f, 0.4f));
		break;
	default:
		// Success, Busy (key mashing during a cast) and Dead need no feedback.
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
// Debug commands

void ARPGPlayerController::RpgGod()
{
	if (AMageCharacter* Mage = GetMage())
	{
		URPGAttributeComponent* Attributes = Mage->GetAttributes();
		Attributes->SetInvulnerable(!Attributes->IsInvulnerable());
		ShowMessage(Attributes->IsInvulnerable() ? TEXT("God mode ON") : TEXT("God mode OFF"), FLinearColor::Yellow);
	}
}

void ARPGPlayerController::RpgCast(int32 SlotNumber)
{
	HandleSpell(SlotNumber - 1);
}

void ARPGPlayerController::RpgRefill()
{
	if (AMageCharacter* Mage = GetMage())
	{
		Mage->GetAttributes()->RestoreAll();
		Mage->GetSpellbook()->ResetCooldowns();
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

void ARPGPlayerController::PlaceMageFacing(ARPGCharacterBase* Bot, float Distance)
{
	AMageCharacter* Mage = GetMage();
	if (!Mage || !Bot)
	{
		return;
	}

	const FVector BotLocation = Bot->GetActorLocation();
	const FVector Offset = Bot->GetActorForwardVector().GetSafeNormal2D() * Distance;
	Mage->TeleportTo(BotLocation + Offset + FVector(0.f, 0.f, 50.f), (-Offset).Rotation());
	SetControlRotation(FRotator(-10.f, (-Offset).Rotation().Yaw, 0.f));
}

void ARPGPlayerController::RpgGoToBot()
{
	if (ARPGCharacterBase* Bot = FindNearestBot())
	{
		PlaceMageFacing(Bot, 900.f);
	}
	else
	{
		ShowMessage(TEXT("No bot found"), FLinearColor::Red);
	}
}

void ARPGPlayerController::RpgStatus()
{
	if (AMageCharacter* Mage = GetMage())
	{
		const URPGAttributeComponent* Attributes = Mage->GetAttributes();
		UE_LOG(LogRPG, Display, TEXT("Player %s: HP %.0f/%.0f MP %.0f/%.0f Shield %.0f at %s"), *Mage->GetName(),
			Attributes->GetHealth(), Attributes->GetMaxHealth(), Attributes->GetMana(), Attributes->GetMaxMana(), Attributes->GetShield(), *Mage->GetActorLocation().ToCompactString());
	}

	for (TActorIterator<AEnemyBotCharacter> It(GetWorld()); It; ++It)
	{
		const URPGAttributeComponent* Attributes = It->GetAttributes();
		const URPGStatusEffectComponent* Status = It->GetStatusEffects();
		UE_LOG(LogRPG, Display, TEXT("Bot %s: HP %.0f/%.0f frozen=%d stunned=%d slowed=%d burning=%d at %s"), *It->GetName(),
			Attributes->GetHealth(), Attributes->GetMaxHealth(), Status->IsFrozen(), Status->IsStunned(), Status->IsSlowed(), Status->IsBurning(), *It->GetActorLocation().ToCompactString());
	}
}

void ARPGPlayerController::RpgSelfTest()
{
	SelfTestStep = 0;
	SelfTestPassed = 0;
	SelfTestBot = FindNearestBot();
	if (!GetMage() || !SelfTestBot.IsValid())
	{
		UE_LOG(LogRPG, Warning, TEXT("SelfTest: needs a living player and a living bot."));
		return;
	}

	UE_LOG(LogRPG, Display, TEXT("SelfTest: starting against %s"), *SelfTestBot->GetName());
	GetWorldTimerManager().SetTimer(SelfTestTimer, this, &ThisClass::RunSelfTestStep, RPGPlayerControllerPrivate::SelfTestStepInterval, true, 0.1f);
}

void ARPGPlayerController::RunSelfTestStep()
{
	AMageCharacter* Mage = GetMage();
	ARPGCharacterBase* Bot = SelfTestBot.Get();
	if (!Mage || !Bot || !Bot->IsAlive())
	{
		UE_LOG(LogRPG, Warning, TEXT("SelfTest: aborted at step %d (player or bot missing/dead)."), SelfTestStep);
		GetWorldTimerManager().ClearTimer(SelfTestTimer);
		return;
	}

	URPGAttributeComponent* BotAttributes = Bot->GetAttributes();
	URPGStatusEffectComponent* BotStatus = Bot->GetStatusEffects();
	auto Check = [this](bool bPassed, const TCHAR* Description)
	{
		SelfTestPassed += bPassed ? 1 : 0;
		UE_LOG(LogRPG, Display, TEXT("SelfTest: %s -> %s"), Description, bPassed ? TEXT("PASS") : TEXT("FAIL"));
	};
	auto CastSlot = [Mage](int32 Slot)
	{
		const ERPGCastResult Result = Mage->CastSpell(Slot);
		UE_LOG(LogRPG, Display, TEXT("SelfTest: cast '%s' result=%d"), *Mage->GetSpellbook()->GetSpell(Slot)->GetDisplayName().ToString(), static_cast<int32>(Result));
	};

	switch (SelfTestStep++)
	{
	case 0:
		Mage->GetAttributes()->SetInvulnerable(true);
		RpgRefill();
		PlaceMageFacing(Bot, 1200.f);
		break;
	case 1:
		SelfTestValue = BotAttributes->GetHealth();
		AimAt(Bot->GetTargetPoint());
		CastSlot(0);
		break;
	case 2:
		Check(BotAttributes->GetHealth() < SelfTestValue && BotStatus->IsBurning(), TEXT("Fireball damages and burns"));
		SelfTestValue = BotAttributes->GetHealth();
		AimAt(Bot->GetTargetPoint());
		CastSlot(2);
		break;
	case 3:
		Check(BotAttributes->GetHealth() < SelfTestValue, TEXT("Lightning Strike damages"));
		PlaceMageFacing(Bot, 350.f);
		break;
	case 4:
		SelfTestValue = BotAttributes->GetHealth();
		CastSlot(1);
		break;
	case 5:
		Check(BotStatus->IsFrozen() && BotAttributes->GetHealth() < SelfTestValue, TEXT("Frost Nova damages and freezes"));
		CastSlot(4);
		break;
	case 6:
		Check(Mage->GetAttributes()->GetShield() > 0.f, TEXT("Arcane Shield grants a barrier"));
		SelfTestPosition = Mage->GetActorLocation();
		AimAt(Mage->GetActorLocation() - (Bot->GetActorLocation() - Mage->GetActorLocation()) * 10.f);
		CastSlot(3);
		break;
	case 7:
		Check(FVector::Dist2D(Mage->GetActorLocation(), SelfTestPosition) > 300.f, TEXT("Blink teleports"));
		UE_LOG(LogRPG, Display, TEXT("SelfTest: finished, %d/5 checks passed."), SelfTestPassed);
		Mage->GetAttributes()->SetInvulnerable(false);
		GetWorldTimerManager().ClearTimer(SelfTestTimer);
		ShowMessage(FString::Printf(TEXT("Self test: %d/5 passed (see Output Log)"), SelfTestPassed), SelfTestPassed == 5 ? FLinearColor::Green : FLinearColor::Red);
		break;
	default:
		GetWorldTimerManager().ClearTimer(SelfTestTimer);
		break;
	}
}
