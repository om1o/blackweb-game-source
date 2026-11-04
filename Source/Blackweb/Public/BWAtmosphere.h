#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "BWTypes.h"
#include "BWAtmosphere.generated.h"

class ABWIntroDirector;
class UAudioComponent;
class ULightComponentBase;
class USoundBase;
class USoundAttenuation;

UCLASS(Blueprintable)
class BLACKWEB_API ABWAtmosphere : public AActor
{
    GENERATED_BODY()
public:
    ABWAtmosphere();
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type Reason) override;
    virtual void Tick(float DeltaSeconds) override;

    UPROPERTY(EditInstanceOnly, BlueprintReadWrite, Category="Atmosphere") ABWIntroDirector* IntroDirector = nullptr;
    UPROPERTY(EditInstanceOnly, BlueprintReadWrite, Category="Lighting") TArray<AActor*> PracticalLights;
    // Fill/window lights take precedence if an actor appears in both arrays.
    UPROPERTY(EditInstanceOnly, BlueprintReadWrite, Category="Lighting") TArray<AActor*> FillLights;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Lighting", meta=(ClampMin="0.0", ClampMax="0.2")) float FlickerDepth = 0.10f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Lighting", meta=(ClampMin="0.25", ClampMax="8.0")) float PowerFadeSeconds = 1.5f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Audio") USoundBase* RoomTone = nullptr;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Audio") USoundBase* PresenceScratch = nullptr;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Audio") USoundBase* PowerCut = nullptr;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Audio") USoundAttenuation* SpatialAttenuation = nullptr;
    UPROPERTY(EditInstanceOnly, BlueprintReadWrite, Category="Audio") AActor* ScratchSourceMarker = nullptr;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Audio", meta=(ClampMin="0.0", ClampMax="1.0")) float NormalRoomVolume = 0.22f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Audio", meta=(ClampMin="0.0", ClampMax="1.0")) float DarkRoomVolume = 0.035f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Audio", meta=(ClampMin="0.0", ClampMax="1.0")) float ScratchVolume = 0.20f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Audio", meta=(ClampMin="0.0", ClampMax="1.0")) float PowerCutVolume = 0.30f;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Audio") UAudioComponent* RoomAudio;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Audio") UAudioComponent* ScratchAudio;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Audio") UAudioComponent* PowerAudio;

private:
    struct FCachedLight
    {
        TWeakObjectPtr<ULightComponentBase> Light;
        float Intensity = 0.0f;
        bool bVisible = true;
        float Phase = 0.0f;
    };
    TArray<FCachedLight> CachedPracticals;
    TArray<FCachedLight> CachedFill;
    EBWIntroStage LastStage = EBWIntroStage::Normal;
    bool bStageInitialized = false;
    bool bPowerInitialized = false;
    bool bLastPowerAvailable = true;
    bool bPresence = false;
    bool bAllowRoomLoop = false;
    float LightLevel = 1.0f;
    float TargetLightLevel = 1.0f;
    float RoomVolume = 0.0f;
    float TargetRoomVolume = 0.0f;
    float AtmosphereTime = 0.0f;

    UFUNCTION() void HandleStageChanged(EBWIntroStage NewStage);
    UFUNCTION() void HandlePowerChanged(bool bAvailable);
    UFUNCTION() void HandleRoomFinished();
    void CacheLights();
    void ApplyLights();
    void RestoreLights();
    void UpdateTickState();
    static void SetLightIntensity(ULightComponentBase* Light, float Intensity);
};
