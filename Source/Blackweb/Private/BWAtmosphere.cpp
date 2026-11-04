#include "BWAtmosphere.h"
#include "BWIntroDirector.h"
#include "Components/AudioComponent.h"
#include "Components/LightComponent.h"
#include "Components/LightComponentBase.h"
#include "Components/SceneComponent.h"
#include "Components/SkyLightComponent.h"
#include "Sound/SoundAttenuation.h"
#include "Sound/SoundBase.h"

ABWAtmosphere::ABWAtmosphere()
{
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.bStartWithTickEnabled = false;
    PrimaryActorTick.TickInterval = 0.05f;
    SetRootComponent(CreateDefaultSubobject<USceneComponent>(TEXT("Root")));
    RoomAudio = CreateDefaultSubobject<UAudioComponent>(TEXT("RoomAudio"));
    RoomAudio->SetupAttachment(RootComponent);
    RoomAudio->bAutoActivate = false;
    RoomAudio->bAllowSpatialization = false;
    RoomAudio->bAutoDestroy = false;
    ScratchAudio = CreateDefaultSubobject<UAudioComponent>(TEXT("ScratchAudio"));
    ScratchAudio->SetupAttachment(RootComponent);
    ScratchAudio->bAutoActivate = false;
    ScratchAudio->bAutoDestroy = false;
    ScratchAudio->bAllowSpatialization = true;
    ScratchAudio->bOverrideAttenuation = true;
    ScratchAudio->AttenuationOverrides.bAttenuate = true;
    ScratchAudio->AttenuationOverrides.bSpatialize = true;
    ScratchAudio->AttenuationOverrides.AttenuationShapeExtents = FVector(80.0f);
    ScratchAudio->AttenuationOverrides.FalloffDistance = 1000.0f;
    PowerAudio = CreateDefaultSubobject<UAudioComponent>(TEXT("PowerAudio"));
    PowerAudio->SetupAttachment(RootComponent);
    PowerAudio->bAutoActivate = false;
    PowerAudio->bAutoDestroy = false;
    PowerAudio->bAllowSpatialization = true;
    PowerAudio->bOverrideAttenuation = true;
    PowerAudio->AttenuationOverrides = ScratchAudio->AttenuationOverrides;
}

void ABWAtmosphere::CacheLights()
{
    CachedPracticals.Reset();
    CachedFill.Reset();
    TSet<ULightComponentBase*> Seen;
    auto Cache = [&Seen](const TArray<AActor*>& Actors, TArray<FCachedLight>& Destination)
    {
        for (AActor* Actor : Actors)
        {
            if (!IsValid(Actor)) continue;
            TArray<ULightComponentBase*> Lights;
            Actor->GetComponents<ULightComponentBase>(Lights);
            for (ULightComponentBase* Light : Lights)
            {
                if (!IsValid(Light) || Seen.Contains(Light)) continue;
                Seen.Add(Light);
                FCachedLight Entry;
                Entry.Light = Light;
                Entry.Intensity = Light->Intensity;
                Entry.bVisible = Light->IsVisible();
                Entry.Phase = Destination.Num() * 0.79f;
                Destination.Add(Entry);
            }
        }
    };
    Cache(FillLights, CachedFill);
    Cache(PracticalLights, CachedPracticals);
}

void ABWAtmosphere::BeginPlay()
{
    Super::BeginPlay();
    CacheLights();
    RoomAudio->SetSound(RoomTone);
    RoomAudio->SetVolumeMultiplier(0.0f);
    RoomAudio->OnAudioFinished.AddUniqueDynamic(this, &ABWAtmosphere::HandleRoomFinished);
    ScratchAudio->SetSound(PresenceScratch);
    PowerAudio->SetSound(PowerCut);
    if (SpatialAttenuation)
    {
        ScratchAudio->bOverrideAttenuation = false;
        PowerAudio->bOverrideAttenuation = false;
        ScratchAudio->AttenuationSettings = SpatialAttenuation;
        PowerAudio->AttenuationSettings = SpatialAttenuation;
    }
    if (!IsValid(IntroDirector)) IntroDirector = ABWIntroDirector::FindDirector(this);
    if (IsValid(IntroDirector))
    {
        IntroDirector->StageChanged.AddUniqueDynamic(this, &ABWAtmosphere::HandleStageChanged);
        IntroDirector->PowerChanged.AddUniqueDynamic(this, &ABWAtmosphere::HandlePowerChanged);
        HandleStageChanged(IntroDirector->Stage);
        HandlePowerChanged(IntroDirector->bPowerAvailable);
    }
    else
    {
        TargetRoomVolume = NormalRoomVolume;
        bAllowRoomLoop = RoomTone != nullptr;
        HandleRoomFinished();
        UpdateTickState();
    }
}

void ABWAtmosphere::HandleStageChanged(EBWIntroStage NewStage)
{
    const bool bNewPresence = NewStage == EBWIntroStage::Presence;
    const bool bEnteringPresence = bNewPresence && (!bStageInitialized || LastStage != NewStage);
    const bool bRestart = NewStage == EBWIntroStage::Normal || NewStage == EBWIntroStage::Message || NewStage == EBWIntroStage::Preparation;
    bPresence = bNewPresence;
    if (bRestart)
    {
        ScratchAudio->Stop();
        PowerAudio->Stop();
        AtmosphereTime = 0.0f;
    }
    if (bEnteringPresence && PresenceScratch)
    {
        ScratchAudio->SetWorldLocation(IsValid(ScratchSourceMarker) ? ScratchSourceMarker->GetActorLocation() : GetActorLocation());
        ScratchAudio->SetVolumeMultiplier(FMath::Clamp(ScratchVolume, 0.0f, 1.0f));
        ScratchAudio->Play();
    }
    LastStage = NewStage;
    bStageInitialized = true;
    TargetLightLevel = NewStage < EBWIntroStage::PowerLoss ? 1.0f : 0.0f;
    TargetRoomVolume = NewStage == EBWIntroStage::Complete ? 0.0f :
        (NewStage >= EBWIntroStage::PowerLoss ? DarkRoomVolume : NormalRoomVolume * (bPresence ? 0.65f : 1.0f));
    TargetRoomVolume = FMath::Clamp(TargetRoomVolume, 0.0f, 1.0f);
    bAllowRoomLoop = RoomTone && NewStage != EBWIntroStage::Complete;
    if (bAllowRoomLoop && !RoomAudio->IsPlaying()) RoomAudio->Play();
    ApplyLights();
    UpdateTickState();
}

void ABWAtmosphere::HandlePowerChanged(bool bAvailable)
{
    const bool bPlayCut = bPowerInitialized && bLastPowerAvailable && !bAvailable;
    bPowerInitialized = true;
    bLastPowerAvailable = bAvailable;
    TargetLightLevel = bAvailable ? 1.0f : 0.0f;
    if (bPlayCut && PowerCut)
    {
        PowerAudio->SetVolumeMultiplier(FMath::Clamp(PowerCutVolume, 0.0f, 1.0f));
        PowerAudio->Play();
    }
    UpdateTickState();
}

void ABWAtmosphere::HandleRoomFinished()
{
    if (bAllowRoomLoop && RoomTone && !RoomAudio->IsPlaying()) RoomAudio->Play();
}

void ABWAtmosphere::SetLightIntensity(ULightComponentBase* Light, float Intensity)
{
    if (ULightComponent* Standard = Cast<ULightComponent>(Light)) Standard->SetIntensity(Intensity);
    else if (USkyLightComponent* Sky = Cast<USkyLightComponent>(Light)) Sky->SetIntensity(Intensity);
}

void ABWAtmosphere::ApplyLights()
{
    for (const FCachedLight& Entry : CachedPracticals)
    {
        if (!Entry.Light.IsValid()) continue;
        // A slow dimming pulse, never an on/off strobe; peak change is capped at 20%.
        const float Wave = 0.5f + 0.5f * FMath::Sin(AtmosphereTime * 1.35f + Entry.Phase);
        const float Dim = bPresence ? 1.0f - FMath::Clamp(FlickerDepth, 0.0f, 0.2f) * FMath::Pow(Wave, 8.0f) : 1.0f;
        SetLightIntensity(Entry.Light.Get(), Entry.Intensity * LightLevel * Dim);
        Entry.Light->SetVisibility(Entry.bVisible);
    }
    // Fill lights are deliberately not dimmed. Windows/skylight keep the house readable.
    for (const FCachedLight& Entry : CachedFill)
    {
        if (!Entry.Light.IsValid()) continue;
        SetLightIntensity(Entry.Light.Get(), Entry.Intensity);
        Entry.Light->SetVisibility(Entry.bVisible);
    }
}

void ABWAtmosphere::UpdateTickState()
{
    SetActorTickEnabled(bPresence || !FMath::IsNearlyEqual(LightLevel, TargetLightLevel, 0.001f) ||
                        !FMath::IsNearlyEqual(RoomVolume, TargetRoomVolume, 0.001f));
}

void ABWAtmosphere::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);
    AtmosphereTime += DeltaSeconds;
    LightLevel = FMath::FInterpTo(LightLevel, TargetLightLevel, DeltaSeconds, 5.0f / FMath::Max(0.25f, PowerFadeSeconds));
    RoomVolume = FMath::FInterpTo(RoomVolume, TargetRoomVolume, DeltaSeconds, 2.5f);
    if (FMath::IsNearlyEqual(LightLevel, TargetLightLevel, 0.001f)) LightLevel = TargetLightLevel;
    if (FMath::IsNearlyEqual(RoomVolume, TargetRoomVolume, 0.001f)) RoomVolume = TargetRoomVolume;
    ApplyLights();
    RoomAudio->SetVolumeMultiplier(RoomVolume);
    if (!bAllowRoomLoop && RoomVolume <= 0.001f) RoomAudio->Stop();
    UpdateTickState();
}

void ABWAtmosphere::RestoreLights()
{
    auto Restore = [](const TArray<FCachedLight>& Lights)
    {
        for (const FCachedLight& Entry : Lights)
        {
            if (!Entry.Light.IsValid()) continue;
            SetLightIntensity(Entry.Light.Get(), Entry.Intensity);
            Entry.Light->SetVisibility(Entry.bVisible);
        }
    };
    Restore(CachedPracticals);
    Restore(CachedFill);
}

void ABWAtmosphere::EndPlay(const EEndPlayReason::Type Reason)
{
    bAllowRoomLoop = false;
    RoomAudio->OnAudioFinished.RemoveDynamic(this, &ABWAtmosphere::HandleRoomFinished);
    RoomAudio->Stop();
    ScratchAudio->Stop();
    PowerAudio->Stop();
    if (IsValid(IntroDirector))
    {
        IntroDirector->StageChanged.RemoveDynamic(this, &ABWAtmosphere::HandleStageChanged);
        IntroDirector->PowerChanged.RemoveDynamic(this, &ABWAtmosphere::HandlePowerChanged);
    }
    RestoreLights();
    Super::EndPlay(Reason);
}
