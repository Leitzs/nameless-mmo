#pragma once

#include "CoreMinimal.h"
#include "Engine/LocalPlayer.h"
#include "RPGLocalPlayer.generated.h"

/**
 * Sends the local profile (URPGGameInstance) to the server every time this player logs in: when a map opens
 * (offline or hosting), when joining a host and on map changes. The engine adds GetNickname() as ?Name= and
 * GetGameLoginOptions() to the login URL; ARPGTestGameMode::InitNewPlayer reads the class back.
 */
UCLASS()
class RPGTEST_API URPGLocalPlayer : public ULocalPlayer
{
	GENERATED_BODY()

public:
	virtual FString GetNickname() const override;
	virtual FString GetGameLoginOptions() const override;
};
