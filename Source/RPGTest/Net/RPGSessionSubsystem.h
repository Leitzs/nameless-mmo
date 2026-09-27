#pragma once

#include "CoreMinimal.h"
#include "Engine/EngineBaseTypes.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "RPGSessionSubsystem.generated.h"

class UNetDriver;

/**
 * Connection layer: offline play, hosting a listen server and joining a host by IP, over the engine's own
 * replication system and UDP net driver (IpNetDriver, see [/Script/OnlineSubsystemUtils.IpNetDriver] in DefaultEngine.ini).
 *
 *   Host:  opens the map with ?listen. Other players join with the host's IP; the host plays as well (listen server).
 *   Join:  travels to "ip[:port]". Name and class go to the server in the login URL (URPGLocalPlayer).
 *   Leave: goes back to the default map offline, which closes the server for a host.
 * Connection errors (wrong IP, host closed, timeout) are kept and shown in the main menu, which reopens by itself.
 */
UCLASS()
class RPGTEST_API URPGSessionSubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	virtual void Initialize(FSubsystemCollectionBase& Collection) override;
	virtual void Deinitialize() override;

	/** Opens a map of URPGGameInstance::GetMaps() without networking. */
	bool PlayOffline(int32 MapIndex, FText& OutError);

	/** Opens a map as a listen server on the port in [URL] Port (7777 by default). */
	bool HostGame(int32 MapIndex, FText& OutError);

	/** Connects to a host. Address is "ip", "ip:port" or a host name. */
	bool JoinGame(const FString& Address, FText& OutError);

	/** Stops a connection attempt that has not finished yet. */
	void CancelJoin();

	/** Leaves the current game (or stops hosting) and returns to the main menu offline. */
	void LeaveGame();

	/** Offline: opens the map. Host: moves everyone to the map. Clients cannot change the map. */
	bool ChangeMap(int32 MapIndex, FText& OutError);

	bool IsConnecting() const;
	const FString& GetConnectingAddress() const { return ConnectingAddress; }

	/** The main menu opens on the first level of the session and after leaving or losing a game. */
	bool ShouldShowMainMenu() const { return bShowMainMenu; }
	void SetMainMenuHandled() { bShowMainMenu = false; }

	/** Called when a networked game has loaded on this machine (the join worked). */
	void NotifyEnteredNetworkGame();

	/** Last connection error; empty when there is none. Cleared by ClearLastError. */
	const FText& GetLastError() const { return LastError; }
	void ClearLastError() { LastError = FText::GetEmpty(); }

	/** This machine's LAN address and the port a hosted game listens on, e.g. "192.168.1.20:7777". */
	const FString& GetLocalAddressHint() const;

	/** Port used by hosted games and by addresses given without one. */
	static int32 GetGamePort();

	/** Validates "host[:port]" and returns it with an explicit port. */
	static bool NormalizeAddress(const FString& Address, FString& OutAddress, FText& OutError);

private:
	void HandleNetworkFailure(UWorld* World, UNetDriver* NetDriver, ENetworkFailure::Type FailureType, const FString& ErrorString);
	void HandleTravelFailure(UWorld* World, ETravelFailure::Type FailureType, const FString& ErrorString);
	bool OpenMapLocally(int32 MapIndex, bool bListen, FText& OutError);

	FDelegateHandle NetworkFailureHandle;
	FDelegateHandle TravelFailureHandle;
	FText LastError;
	FString ConnectingAddress;
	mutable FString LocalAddressHint;
	mutable bool bLocalAddressResolved = false;
	bool bShowMainMenu = true;
};
