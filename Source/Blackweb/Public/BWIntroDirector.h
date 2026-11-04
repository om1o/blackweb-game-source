#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "BWProgression.h"
#include "BWTypes.h"
#include "BWIntroDirector.generated.h"

class ABWPlayerCharacter;
class UBWSaveGame;
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FBWStageChanged, EBWIntroStage, NewStage);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FBWPowerChanged, bool, bPowerAvailable);

UCLASS(Blueprintable)
class BLACKWEB_API ABWIntroDirector : public AActor
{
    GENERATED_BODY()
public:
    ABWIntroDirector();
    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;

    UFUNCTION(BlueprintPure, meta=(WorldContext="WorldContextObject"))
    static ABWIntroDirector* FindDirector(const UObject* WorldContextObject);
    UFUNCTION(BlueprintCallable) bool StartMaraMessage();
    UFUNCTION(BlueprintCallable) bool AdvancePresence();
    UFUNCTION(BlueprintCallable) bool TriggerPowerLoss();
    UFUNCTION(BlueprintCallable) bool StartEncounter();
    UFUNCTION(BlueprintCallable) bool ResolveEncounter();
    UFUNCTION(BlueprintCallable) bool TryLeaveHouse();
    UFUNCTION(BlueprintCallable) bool Interact(EBWInteractionKind Kind);
    UFUNCTION(BlueprintPure) bool CanInteract(EBWInteractionKind Kind) const;
    UFUNCTION(BlueprintPure) FText GetObjective() const;
    UFUNCTION(BlueprintPure) FText GetInteractionHint(EBWInteractionKind Kind) const;
    UFUNCTION(BlueprintCallable) bool SaveCheckpoint();
    UFUNCTION(BlueprintCallable) bool ReloadCheckpoint();
    UFUNCTION(BlueprintCallable) void RetryCurrentMilestone();
    UFUNCTION(BlueprintCallable) void RestartOpening();
    UFUNCTION(BlueprintCallable) void ShowNotice(const FText& Text, float Duration = 3.0f);

    UPROPERTY(BlueprintReadOnly, Category="Story") EBWIntroStage Stage = EBWIntroStage::Normal;
    UPROPERTY(BlueprintReadOnly, Category="Story") bool bWarningHeard = false;
    UPROPERTY(BlueprintReadOnly, Category="Story") bool bHasFlashlight = false;
    UPROPERTY(BlueprintReadOnly, Category="Story") bool bHasKeys = false;
    UPROPERTY(BlueprintReadOnly, Category="Story") bool bPowerAvailable = true;
    UPROPERTY(BlueprintReadOnly, Category="Story") bool bEncounterSurvived = false;
    UPROPERTY(BlueprintReadOnly, Category="Presentation") FText Subtitle;
    UPROPERTY(BlueprintReadOnly, Category="Presentation") FText Notice;
    UPROPERTY(BlueprintReadOnly, Category="Save") bool bLastSaveSucceeded = true;
    UPROPERTY(BlueprintReadOnly, Category="Save") bool bSaveWritesBlocked = false;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Story") TArray<FBWMaraLine> MaraLines;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Pacing") bool bAutoAdvanceAtmosphere = true;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Pacing", meta=(ClampMin="1.0")) float PresenceDuration = 8.0f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Pacing", meta=(ClampMin="1.0")) float PowerLossDuration = 6.0f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Pacing") bool bUseTimedEncounterResolution = true;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Pacing", meta=(ClampMin="3.0")) float EncounterDuration = 18.0f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Save") bool bAutoLoadCheckpoint = true;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Save") FString SaveSlot = TEXT("BlackwebHouse_Phase0_v1");
    UPROPERTY(EditInstanceOnly, BlueprintReadWrite, Category="Save") AActor* CheckpointAnchor = nullptr;

    UPROPERTY(BlueprintAssignable) FBWStageChanged StageChanged;
    UPROPERTY(BlueprintAssignable) FBWPowerChanged PowerChanged;
    UFUNCTION(BlueprintImplementableEvent) void OnStageChanged(EBWIntroStage NewStage);
    UFUNCTION(BlueprintImplementableEvent) void OnPowerChanged(bool bPowerIsAvailable);
    UFUNCTION(BlueprintImplementableEvent) void OnEncounterStarted();
    UFUNCTION(BlueprintImplementableEvent) void OnHouseDeparture();
    UFUNCTION(BlueprintImplementableEvent) void OnCheckpointRestored();

private:
    Blackweb::Progress Progress;
    TWeakObjectPtr<ABWPlayerCharacter> ActivePlayer;
    float StageElapsed = 0.0f;
    float NoticeRemaining = 0.0f;
    bool Apply(Blackweb::Action Action);
    void RefreshState(bool bForceEvents = false);
    void UpdateMessage();
    bool ReadSave(const UBWSaveGame* Save, Blackweb::Progress& OutProgress) const;
    UBWSaveGame* CreateSave() const;
};
