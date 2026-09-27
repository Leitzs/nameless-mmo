#include "Core/RPGTestGameMode.h"

#include "Characters/MageCharacter.h"
#include "Combat/RPGCombatLibrary.h"
#include "Core/RPGGameInstance.h"
#include "Core/RPGGameState.h"
#include "Core/RPGPlayerController.h"
#include "Core/RPGPlayerState.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/Controller.h"
#include "GameFramework/PlayerStart.h"
#include "Kismet/GameplayStatics.h"
#include "RPGTest.h"
#include "TimerManager.h"
#include "UI/RPGHUD.h"

ARPGTestGameMode::ARPGTestGameMode()
{
	DefaultPawnClass = AMageCharacter::StaticClass();
	PlayerControllerClass = ARPGPlayerController::StaticClass();
	PlayerStateClass = ARPGPlayerState::StaticClass();
	GameStateClass = ARPGGameState::StaticClass();
	HUDClass = ARPGHUD::StaticClass();
}

void ARPGTestGameMode::InitGameState()
{
	Super::InitGameState();

	if (ARPGGameState* RPGGameState = GetGameState<ARPGGameState>())
	{
		RPGGameState->SetPlayersHostile(bPlayersHostile);
	}
}

FString ARPGTestGameMode::InitNewPlayer(APlayerController* NewPlayerController, const FUniqueNetIdRepl& UniqueId, const FString& Options, const FString& Portal)
{
	// The base class applies ?Name=.
	const FString Error = Super::InitNewPlayer(NewPlayerController, UniqueId, Options, Portal);

	ARPGPlayerState* PlayerState = NewPlayerController ? NewPlayerController->GetPlayerState<ARPGPlayerState>() : nullptr;
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (PlayerState && GameInstance)
	{
		const FName RequestedClass(*UGameplayStatics::ParseOption(Options, ClassOption));
		PlayerState->SetCharacterClassId(GameInstance->FindCharacterClass(RequestedClass) ? RequestedClass : GameInstance->GetDefaultCharacterClassId());

		const FString SafeName = URPGGameInstance::SanitizePlayerName(PlayerState->GetPlayerName());
		ChangeName(NewPlayerController, SafeName.IsEmpty() ? FString::Printf(TEXT("Player%d"), GetNumPlayers() + 1) : SafeName, false);

		UE_LOG(LogRPG, Log, TEXT("%s joined as %s"), *PlayerState->GetPlayerName(), *PlayerState->GetCharacterClassId().ToString());
	}

	return Error;
}

UClass* ARPGTestGameMode::GetDefaultPawnClassForController_Implementation(AController* InController)
{
	const ARPGPlayerState* PlayerState = InController ? InController->GetPlayerState<ARPGPlayerState>() : nullptr;
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (PlayerState && GameInstance)
	{
		if (const FRPGCharacterClassInfo* ClassInfo = GameInstance->FindCharacterClass(PlayerState->GetCharacterClassId()); ClassInfo && ClassInfo->PawnClass)
		{
			return ClassInfo->PawnClass;
		}
	}
	return Super::GetDefaultPawnClassForController_Implementation(InController);
}

AActor* ARPGTestGameMode::ChoosePlayerStart_Implementation(AController* Player)
{
	// Spawn as far as possible from the other living players (random among equally good starts).
	TArray<APlayerStart*> Starts;
	for (TActorIterator<APlayerStart> It(GetWorld()); It; ++It)
	{
		Starts.Add(*It);
	}
	if (Starts.Num() == 0)
	{
		return Super::ChoosePlayerStart_Implementation(Player);
	}

	TArray<FVector> Others;
	for (FConstPlayerControllerIterator It = GetWorld()->GetPlayerControllerIterator(); It; ++It)
	{
		const APlayerController* Other = It->Get();
		const ARPGCharacterBase* OtherCharacter = Other && Other != Player ? Cast<ARPGCharacterBase>(Other->GetPawn()) : nullptr;
		if (OtherCharacter && OtherCharacter->IsAlive())
		{
			Others.Add(OtherCharacter->GetActorLocation());
		}
	}

	APlayerStart* Best = nullptr;
	float BestScore = -1.f;
	for (APlayerStart* Start : Starts)
	{
		float Score = UE_BIG_NUMBER;
		for (const FVector& OtherLocation : Others)
		{
			Score = FMath::Min(Score, static_cast<float>(FVector::Dist(Start->GetActorLocation(), OtherLocation)));
		}
		Score += FMath::FRand() * 100.f;
		if (Score > BestScore)
		{
			Best = Start;
			BestScore = Score;
		}
	}
	return Best;
}

APawn* ARPGTestGameMode::SpawnDefaultPawnAtTransform_Implementation(AController* NewPlayer, const FTransform& SpawnTransform)
{
	// Maps with a single player start still have to fit several players: nudge the pawn out of anyone standing there.
	FActorSpawnParameters SpawnInfo;
	SpawnInfo.Instigator = GetInstigator();
	SpawnInfo.ObjectFlags |= RF_Transient;
	SpawnInfo.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn;

	FTransform Transform = SpawnTransform;
	for (FConstPlayerControllerIterator It = GetWorld()->GetPlayerControllerIterator(); It; ++It)
	{
		const APawn* OtherPawn = It->Get() && It->Get() != NewPlayer ? It->Get()->GetPawn() : nullptr;
		if (OtherPawn && FVector::Dist2D(OtherPawn->GetActorLocation(), Transform.GetLocation()) < 150.f)
		{
			const FVector2D Offset = FVector2D(FMath::RandPointInCircle(1.f)).GetSafeNormal() * 250.f;
			Transform.AddToTranslation(FVector(Offset, 0.f));
		}
	}

	return GetWorld()->SpawnActor<APawn>(GetDefaultPawnClassForController(NewPlayer), Transform, SpawnInfo);
}

void ARPGTestGameMode::Logout(AController* Exiting)
{
	if (FTimerHandle* Timer = RespawnTimers.Find(Exiting))
	{
		GetWorldTimerManager().ClearTimer(*Timer);
		RespawnTimers.Remove(Exiting);
	}
	Super::Logout(Exiting);
}

void ARPGTestGameMode::NotifyCharacterDied(ARPGCharacterBase* Victim, AActor* Killer)
{
	AController* VictimController = Victim ? Victim->GetController() : nullptr;
	ARPGPlayerState* VictimState = Victim ? Victim->GetPlayerState<ARPGPlayerState>() : nullptr;
	if (!VictimController || !VictimState)
	{
		// Bots respawn through their spawner.
		return;
	}

	VictimState->AddDeath();

	const ARPGCharacterBase* KillerCharacter = URPGCombatLibrary::GetResponsibleCharacter(Killer);
	ARPGPlayerState* KillerState = KillerCharacter && KillerCharacter != Victim ? KillerCharacter->GetPlayerState<ARPGPlayerState>() : nullptr;
	if (KillerState)
	{
		KillerState->AddKill();
	}

	if (ARPGGameState* RPGGameState = GetGameState<ARPGGameState>())
	{
		RPGGameState->MulticastKillMessage(KillerState, VictimState);
	}

	const float Delay = FMath::Max(0.1f, PlayerRespawnDelay);
	VictimState->SetRespawnTime(GetGameState<AGameStateBase>()->GetServerWorldTimeSeconds() + Delay);

	FTimerHandle& Timer = RespawnTimers.FindOrAdd(VictimController);
	GetWorldTimerManager().SetTimer(Timer, FTimerDelegate::CreateUObject(this, &ThisClass::RespawnPlayer, TWeakObjectPtr<AController>(VictimController)), Delay, false);
}

void ARPGTestGameMode::RespawnPlayer(TWeakObjectPtr<AController> PlayerController)
{
	AController* Controller = PlayerController.Get();
	if (!Controller)
	{
		return;
	}

	RespawnTimers.Remove(Controller);
	if (ARPGPlayerState* PlayerState = Controller->GetPlayerState<ARPGPlayerState>())
	{
		PlayerState->SetRespawnTime(0.0);
	}

	if (APawn* OldPawn = Controller->GetPawn())
	{
		Controller->UnPossess();
		OldPawn->Destroy();
	}

	RestartPlayer(Controller);
}

bool ARPGTestGameMode::ChangeCharacterClass(APlayerController* PlayerController, FName ClassId)
{
	ARPGPlayerState* PlayerState = PlayerController ? PlayerController->GetPlayerState<ARPGPlayerState>() : nullptr;
	const URPGGameInstance* GameInstance = GetGameInstance<URPGGameInstance>();
	if (!PlayerState || !GameInstance || !GameInstance->FindCharacterClass(ClassId))
	{
		return false;
	}

	PlayerState->SetCharacterClassId(ClassId);
	UE_LOG(LogRPG, Log, TEXT("%s switched to %s"), *PlayerState->GetPlayerName(), *ClassId.ToString());

	// A dead player keeps the pending respawn, which uses the new class.
	const ARPGCharacterBase* Character = Cast<ARPGCharacterBase>(PlayerController->GetPawn());
	if (Character && Character->IsAlive())
	{
		RespawnPlayer(PlayerController);
	}
	return true;
}

void ARPGTestGameMode::ChangePlayerName(APlayerController* PlayerController, const FString& NewName)
{
	const FString SafeName = URPGGameInstance::SanitizePlayerName(NewName);
	if (PlayerController && !SafeName.IsEmpty())
	{
		ChangeName(PlayerController, SafeName, true);
	}
}
