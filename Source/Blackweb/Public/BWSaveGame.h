#pragma once
#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "BWSaveGame.generated.h"

UCLASS()
class BLACKWEB_API UBWSaveGame : public USaveGame
{
    GENERATED_BODY()
public:
    UPROPERTY(SaveGame) int32 SchemaVersion = 1;
    UPROPERTY(SaveGame) uint8 Stage = 0;
    UPROPERTY(SaveGame) bool bWarningHeard = false;
    UPROPERTY(SaveGame) bool bHasFlashlight = false;
    UPROPERTY(SaveGame) bool bHasKeys = false;
    UPROPERTY(SaveGame) bool bEncounterSurvived = false;
    UPROPERTY(SaveGame) bool bDeparted = false;
};
