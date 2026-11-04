#pragma once
#include "CoreMinimal.h"
#include "BWTypes.generated.h"

UENUM(BlueprintType)
enum class EBWIntroStage : uint8
{
    Normal, Message, Preparation, Presence, PowerLoss, Encounter, ReadyToLeave, Complete
};

UENUM(BlueprintType)
enum class EBWInteractionKind : uint8
{
    Phone, Flashlight, Keys, ExitDoor
};

USTRUCT(BlueprintType)
struct BLACKWEB_API FBWMaraLine
{
    GENERATED_BODY()
    UPROPERTY(EditAnywhere, BlueprintReadWrite) FText Text;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, meta=(ClampMin="0.5")) float Duration = 3.5f;
};
