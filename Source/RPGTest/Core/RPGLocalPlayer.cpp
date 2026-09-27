#include "Core/RPGLocalPlayer.h"

#include "Core/RPGGameInstance.h"
#include "Core/RPGTestGameMode.h"

FString URPGLocalPlayer::GetNickname() const
{
	const URPGGameInstance* GameInstance = Cast<URPGGameInstance>(GetGameInstance());
	return GameInstance && !GameInstance->GetPlayerName().IsEmpty() ? GameInstance->GetPlayerName() : Super::GetNickname();
}

FString URPGLocalPlayer::GetGameLoginOptions() const
{
	const URPGGameInstance* GameInstance = Cast<URPGGameInstance>(GetGameInstance());
	if (!GameInstance || GameInstance->GetSelectedClassId().IsNone())
	{
		return Super::GetGameLoginOptions();
	}
	return FString::Printf(TEXT("%s=%s"), ARPGTestGameMode::ClassOption, *GameInstance->GetSelectedClassId().ToString());
}
