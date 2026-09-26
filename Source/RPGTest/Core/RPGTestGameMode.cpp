#include "Core/RPGTestGameMode.h"

#include "Characters/MageCharacter.h"
#include "Core/RPGPlayerController.h"
#include "GameFramework/Controller.h"
#include "TimerManager.h"
#include "UI/RPGHUD.h"

ARPGTestGameMode::ARPGTestGameMode()
{
	DefaultPawnClass = AMageCharacter::StaticClass();
	PlayerControllerClass = ARPGPlayerController::StaticClass();
	HUDClass = ARPGHUD::StaticClass();
}

void ARPGTestGameMode::NotifyPlayerDied(AController* PlayerController)
{
	if (!PlayerController)
	{
		return;
	}

	GetWorldTimerManager().SetTimer(RespawnTimer, FTimerDelegate::CreateUObject(this, &ThisClass::RespawnPlayer, TWeakObjectPtr<AController>(PlayerController)), FMath::Max(0.1f, PlayerRespawnDelay), false);
}

float ARPGTestGameMode::GetRespawnTimeRemaining() const
{
	const FTimerManager& TimerManager = GetWorldTimerManager();
	return TimerManager.IsTimerActive(RespawnTimer) ? TimerManager.GetTimerRemaining(RespawnTimer) : 0.f;
}

void ARPGTestGameMode::RespawnPlayer(TWeakObjectPtr<AController> PlayerController)
{
	AController* Controller = PlayerController.Get();
	if (!Controller)
	{
		return;
	}

	if (APawn* OldPawn = Controller->GetPawn())
	{
		Controller->UnPossess();
		OldPawn->Destroy();
	}

	RestartPlayer(Controller);
}
