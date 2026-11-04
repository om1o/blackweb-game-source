#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "BWTypes.h"
#include "BWInteractable.generated.h"

class UStaticMeshComponent;
class UBoxComponent;
class ABWIntroDirector;

UCLASS(Blueprintable)
class BLACKWEB_API ABWInteractable : public AActor
{
    GENERATED_BODY()
public:
    ABWInteractable();
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;
    UFUNCTION(BlueprintCallable) bool Use(ABWIntroDirector* Director);
    UFUNCTION(BlueprintPure) FText GetPrompt() const;
    UFUNCTION(BlueprintPure) FVector GetInteractionLocation() const;
    UFUNCTION(BlueprintImplementableEvent) void OnUsed();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) UBoxComponent* InteractionBounds;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) UStaticMeshComponent* Visual;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Interaction") EBWInteractionKind Kind = EBWInteractionKind::Phone;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Interaction") FText Prompt;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Interaction") FText InspectText;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Interaction") bool bHideWhenCollected = true;
private:
    TWeakObjectPtr<ABWIntroDirector> Intro;
};
