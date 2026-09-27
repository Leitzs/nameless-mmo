#include "Net/RPGSessionSubsystem.h"

#include "Core/RPGGameInstance.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "GameMapsSettings.h"
#include "IPAddress.h"
#include "Kismet/GameplayStatics.h"
#include "RPGTest.h"
#include "SocketSubsystem.h"

#define LOCTEXT_NAMESPACE "RPGSession"

void URPGSessionSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
	Super::Initialize(Collection);

	if (GEngine)
	{
		NetworkFailureHandle = GEngine->OnNetworkFailure().AddUObject(this, &ThisClass::HandleNetworkFailure);
		TravelFailureHandle = GEngine->OnTravelFailure().AddUObject(this, &ThisClass::HandleTravelFailure);
	}
}

void URPGSessionSubsystem::Deinitialize()
{
	if (GEngine)
	{
		GEngine->OnNetworkFailure().Remove(NetworkFailureHandle);
		GEngine->OnTravelFailure().Remove(TravelFailureHandle);
	}
	Super::Deinitialize();
}

int32 URPGSessionSubsystem::GetGamePort()
{
	// A default URL carries the port from [URL] Port in DefaultEngine.ini.
	return FURL().Port;
}

bool URPGSessionSubsystem::NormalizeAddress(const FString& Address, FString& OutAddress, FText& OutError)
{
	FString Host = Address.TrimStartAndEnd();
	int32 Port = GetGamePort();

	FString PortText;
	if (Host.Split(TEXT(":"), &Host, &PortText, ESearchCase::IgnoreCase, ESearchDir::FromEnd))
	{
		if (!PortText.IsNumeric() || !FMath::IsWithinInclusive(FCString::Atoi(*PortText), 1, 65535))
		{
			OutError = LOCTEXT("BadPort", "The port must be a number between 1 and 65535.");
			return false;
		}
		Port = FCString::Atoi(*PortText);
	}

	if (Host.IsEmpty())
	{
		OutError = LOCTEXT("NoAddress", "Enter the IP address of the player who is hosting.");
		return false;
	}

	for (const TCHAR Character : Host)
	{
		if (!FChar::IsAlnum(Character) && Character != TEXT('.') && Character != TEXT('-'))
		{
			OutError = LOCTEXT("BadAddress", "That does not look like an IP address (example: 192.168.1.20 or 192.168.1.20:7777).");
			return false;
		}
	}

	OutAddress = FString::Printf(TEXT("%s:%d"), *Host, Port);
	return true;
}

const FString& URPGSessionSubsystem::GetLocalAddressHint() const
{
	// Looked up once: the HUD shows it every frame while hosting.
	if (!bLocalAddressResolved)
	{
		bLocalAddressResolved = true;
		if (ISocketSubsystem* Sockets = ISocketSubsystem::Get(PLATFORM_SOCKETSUBSYSTEM))
		{
			bool bCanBindAll = false;
			const TSharedRef<FInternetAddr> Address = Sockets->GetLocalHostAddr(*GLog, bCanBindAll);
			if (Address->IsValid())
			{
				LocalAddressHint = FString::Printf(TEXT("%s:%d"), *Address->ToString(false), GetGamePort());
			}
		}
	}
	return LocalAddressHint;
}

bool URPGSessionSubsystem::OpenMapLocally(int32 MapIndex, bool bListen, FText& OutError)
{
	const URPGGameInstance* GameInstance = Cast<URPGGameInstance>(GetGameInstance());
	if (!GameInstance || !GameInstance->GetMaps().IsValidIndex(MapIndex))
	{
		OutError = LOCTEXT("NoMap", "Pick a map first.");
		return false;
	}

	ClearLastError();
	bShowMainMenu = false;
	ConnectingAddress.Reset();

	const TSoftObjectPtr<UWorld>& Level = GameInstance->GetMaps()[MapIndex].Level;
	UE_LOG(LogRPG, Log, TEXT("Opening map '%s'%s"), *Level.GetLongPackageName(), bListen ? TEXT(" as a listen server") : TEXT(""));
	UGameplayStatics::OpenLevelBySoftObjectPtr(this, Level, true, bListen ? TEXT("listen") : TEXT(""));
	return true;
}

bool URPGSessionSubsystem::PlayOffline(int32 MapIndex, FText& OutError)
{
	return OpenMapLocally(MapIndex, false, OutError);
}

bool URPGSessionSubsystem::HostGame(int32 MapIndex, FText& OutError)
{
	return OpenMapLocally(MapIndex, true, OutError);
}

bool URPGSessionSubsystem::JoinGame(const FString& Address, FText& OutError)
{
	FString NormalizedAddress;
	if (!NormalizeAddress(Address, NormalizedAddress, OutError))
	{
		return false;
	}

	UWorld* World = GetGameInstance()->GetWorld();
	if (!World || !GEngine)
	{
		OutError = LOCTEXT("NoWorld", "The game is not ready to connect yet.");
		return false;
	}

	if (URPGGameInstance* GameInstance = Cast<URPGGameInstance>(GetGameInstance()))
	{
		GameInstance->SetLastJoinAddress(Address.TrimStartAndEnd());
	}

	ClearLastError();
	ConnectingAddress = NormalizedAddress;
	UE_LOG(LogRPG, Log, TEXT("Joining %s"), *NormalizedAddress);

	// The engine connects in the background (pending net game) and loads the host's map once it is accepted.
	// The main menu stays open meanwhile; it closes when the new map loads.
	GEngine->SetClientTravel(World, *NormalizedAddress, TRAVEL_Absolute);
	return true;
}

bool URPGSessionSubsystem::IsConnecting() const
{
	const FWorldContext* Context = GetGameInstance()->GetWorldContext();
	return Context && Context->PendingNetGame != nullptr;
}

void URPGSessionSubsystem::NotifyEnteredNetworkGame()
{
	bShowMainMenu = false;
	ConnectingAddress.Reset();
	ClearLastError();
}

void URPGSessionSubsystem::CancelJoin()
{
	UWorld* World = GetGameInstance()->GetWorld();
	if (World && GEngine && IsConnecting())
	{
		GEngine->CancelPending(World);
	}
	ConnectingAddress.Reset();
}

void URPGSessionSubsystem::LeaveGame()
{
	bShowMainMenu = true;
	ConnectingAddress.Reset();

	// Opening a map without ?listen closes the server (for a host) or the connection (for a client).
	const FString DefaultMap = UGameMapsSettings::GetGameDefaultMap();
	UE_LOG(LogRPG, Log, TEXT("Leaving the game, back to %s"), *DefaultMap);
	UGameplayStatics::OpenLevel(this, FName(*DefaultMap), true);
}

bool URPGSessionSubsystem::ChangeMap(int32 MapIndex, FText& OutError)
{
	UWorld* World = GetGameInstance()->GetWorld();
	const URPGGameInstance* GameInstance = Cast<URPGGameInstance>(GetGameInstance());
	if (!World || !GameInstance || !GameInstance->GetMaps().IsValidIndex(MapIndex))
	{
		OutError = LOCTEXT("NoMapIndex", "There is no such map.");
		return false;
	}

	switch (World->GetNetMode())
	{
	case NM_Client:
		OutError = LOCTEXT("ClientCannotChangeMap", "Only the host can change the map.");
		return false;

	case NM_ListenServer:
	case NM_DedicatedServer:
	{
		// Everyone connected follows the host to the new map.
		const FString URL = GameInstance->GetMaps()[MapIndex].Level.GetLongPackageName() + TEXT("?listen");
		UE_LOG(LogRPG, Log, TEXT("Server travel to %s"), *URL);
		bShowMainMenu = false;
		return World->ServerTravel(URL, true);
	}

	default:
		return PlayOffline(MapIndex, OutError);
	}
}

void URPGSessionSubsystem::HandleNetworkFailure(UWorld* World, UNetDriver* NetDriver, ENetworkFailure::Type FailureType, const FString& ErrorString)
{
	// A host losing one client is not an error for the host.
	if (World && World->GetNetMode() == NM_ListenServer && FailureType != ENetworkFailure::NetDriverListenFailure)
	{
		return;
	}

	switch (FailureType)
	{
	case ENetworkFailure::ConnectionLost:
	case ENetworkFailure::ConnectionTimeout:
		LastError = ConnectingAddress.IsEmpty()
			? LOCTEXT("ConnectionLost", "The connection to the host was lost (the host left or the network dropped).")
			: FText::Format(LOCTEXT("ConnectTimeout", "Could not reach {0}. Check the IP, that the host is in the game, and that UDP port {1} is open in the host's firewall."),
				FText::FromString(ConnectingAddress), FText::AsNumber(GetGamePort(), &FNumberFormattingOptions::DefaultNoGrouping()));
		break;
	case ENetworkFailure::NetDriverListenFailure:
		LastError = FText::Format(LOCTEXT("ListenFailure", "Could not host: UDP port {0} is already in use (is another game hosting on this PC?)."),
			FText::AsNumber(GetGamePort(), &FNumberFormattingOptions::DefaultNoGrouping()));
		break;
	case ENetworkFailure::OutdatedClient:
	case ENetworkFailure::OutdatedServer:
		LastError = LOCTEXT("VersionMismatch", "The host is running a different build of the game. Both players need the same version.");
		break;
	default:
		LastError = FText::Format(LOCTEXT("NetworkFailure", "Network error: {0}"), FText::FromString(ErrorString));
		break;
	}

	UE_LOG(LogRPG, Warning, TEXT("Network failure %s: %s"), ENetworkFailure::ToString(FailureType), *ErrorString);
	ConnectingAddress.Reset();
	bShowMainMenu = true;
}

void URPGSessionSubsystem::HandleTravelFailure(UWorld* World, ETravelFailure::Type FailureType, const FString& ErrorString)
{
	LastError = FText::Format(LOCTEXT("TravelFailure", "Could not load the game: {0}"), FText::FromString(ErrorString.IsEmpty() ? ETravelFailure::ToString(FailureType) : ErrorString));
	UE_LOG(LogRPG, Warning, TEXT("Travel failure %s: %s"), ETravelFailure::ToString(FailureType), *ErrorString);
	ConnectingAddress.Reset();
	bShowMainMenu = true;
}

#undef LOCTEXT_NAMESPACE
