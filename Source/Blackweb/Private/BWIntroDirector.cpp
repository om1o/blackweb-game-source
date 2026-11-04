#include "BWIntroDirector.h"
#include "BWPlayerCharacter.h"
#include "BWSaveGame.h"
#include "EngineUtils.h"
#include "Engine/Engine.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"

#define LOCTEXT_NAMESPACE "BlackwebIntro"
static_assert(static_cast<uint8>(EBWIntroStage::Complete) == static_cast<uint8>(Blackweb::Stage::Complete), "Stage enums must stay aligned");

ABWIntroDirector::ABWIntroDirector()
{
    PrimaryActorTick.bCanEverTick = true;
    auto AddLine = [this](const FText& Text, float Duration)
    {
        FBWMaraLine Line; Line.Text = Text; Line.Duration = Duration; MaraLines.Add(Line);
    };
    AddLine(LOCTEXT("Mara1", "Mara: Luke? If you get this, stay home."), 3.5f);
    AddLine(LOCTEXT("Mara2", "Mara: Something's happening in Greyhaven. The streets are—"), 4.0f);
    AddLine(LOCTEXT("Mara3", "Mara: Don't come looking for me. Please. I can hear—"), 4.0f);
    AddLine(LOCTEXT("MessageLost", "[Connection lost]"), 2.0f);
    AddLine(LOCTEXT("LukeDecision", "Luke: Mara. Pick up. ...I'm coming."), 3.0f);
}

void ABWIntroDirector::BeginPlay()
{
    Super::BeginPlay();
    if (!bAutoLoadCheckpoint || !ReloadCheckpoint()) RefreshState(true);
}

ABWIntroDirector* ABWIntroDirector::FindDirector(const UObject* WorldContextObject)
{
    UWorld* World = GEngine ? GEngine->GetWorldFromContextObject(WorldContextObject, EGetWorldErrorMode::ReturnNull) : nullptr;
    if (World) for (TActorIterator<ABWIntroDirector> It(World); It; ++It) return *It;
    return nullptr;
}

void ABWIntroDirector::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);
    if (!ActivePlayer.IsValid()) ActivePlayer = Cast<ABWPlayerCharacter>(UGameplayStatics::GetPlayerCharacter(this, 0));
    // A fatal hit cannot be converted into survival by the timed fallback during recovery.
    if (ActivePlayer.IsValid() && ActivePlayer->bIsRecovering) return;
    StageElapsed += DeltaSeconds;
    if (NoticeRemaining > 0.0f)
    {
        NoticeRemaining -= DeltaSeconds;
        if (NoticeRemaining <= 0.0f) Notice = FText::GetEmpty();
    }
    if (Stage == EBWIntroStage::Message) UpdateMessage();
    else if (bAutoAdvanceAtmosphere && Stage == EBWIntroStage::Presence && StageElapsed >= PresenceDuration) TriggerPowerLoss();
    else if (bAutoAdvanceAtmosphere && Stage == EBWIntroStage::PowerLoss && StageElapsed >= PowerLossDuration) StartEncounter();
    else if (bUseTimedEncounterResolution && Stage == EBWIntroStage::Encounter && StageElapsed >= EncounterDuration) ResolveEncounter();
}

void ABWIntroDirector::UpdateMessage()
{
    float End = 0.0f;
    for (const FBWMaraLine& Line : MaraLines)
    {
        End += FMath::Max(0.5f, Line.Duration);
        if (StageElapsed < End) { Subtitle = Line.Text; return; }
    }
    Apply(Blackweb::Action::FinishMessage);
}

bool ABWIntroDirector::Apply(Blackweb::Action Action)
{
    if (!Progress.Apply(Action)) return false;
    RefreshState();
    SaveCheckpoint();
    return true;
}

void ABWIntroDirector::RefreshState(bool bForceEvents)
{
    const EBWIntroStage Previous = Stage;
    const bool bPreviousPower = bPowerAvailable;
    Stage = static_cast<EBWIntroStage>(Progress.Current);
    bWarningHeard = Progress.WarningHeard;
    bHasFlashlight = Progress.Flashlight;
    bHasKeys = Progress.Keys;
    bEncounterSurvived = Progress.EncounterSurvived;
    bPowerAvailable = Stage < EBWIntroStage::PowerLoss;
    if (Stage != Previous || bForceEvents)
    {
        StageElapsed = 0.0f;
        Subtitle = FText::GetEmpty();
        if (Stage == EBWIntroStage::Message && MaraLines.Num() > 0) Subtitle = MaraLines[0].Text;
        StageChanged.Broadcast(Stage);
        OnStageChanged(Stage);
        if (Stage == EBWIntroStage::Encounter) OnEncounterStarted();
        if (Stage == EBWIntroStage::Complete) OnHouseDeparture();
    }
    if (bForceEvents || bPreviousPower != bPowerAvailable)
    {
        PowerChanged.Broadcast(bPowerAvailable);
        OnPowerChanged(bPowerAvailable);
    }
}

bool ABWIntroDirector::StartMaraMessage() { return Apply(Blackweb::Action::StartMessage); }
bool ABWIntroDirector::AdvancePresence() { return Apply(Blackweb::Action::RevealPresence); }
bool ABWIntroDirector::TriggerPowerLoss() { return Apply(Blackweb::Action::LosePower); }
bool ABWIntroDirector::StartEncounter() { return Apply(Blackweb::Action::StartEncounter); }
bool ABWIntroDirector::ResolveEncounter() { return Apply(Blackweb::Action::SurviveEncounter); }
bool ABWIntroDirector::TryLeaveHouse() { return Apply(Blackweb::Action::Leave); }

bool ABWIntroDirector::CanInteract(EBWInteractionKind Kind) const
{
    switch (Kind)
    {
    case EBWInteractionKind::Phone: return Stage == EBWIntroStage::Normal;
    case EBWInteractionKind::Flashlight: return bWarningHeard && !bHasFlashlight && Stage != EBWIntroStage::Complete;
    case EBWInteractionKind::Keys: return bWarningHeard && !bHasKeys && Stage != EBWIntroStage::Complete;
    case EBWInteractionKind::ExitDoor: return Progress.CanLeave();
    }
    return false;
}

bool ABWIntroDirector::Interact(EBWInteractionKind Kind)
{
    if (!CanInteract(Kind)) { ShowNotice(GetInteractionHint(Kind)); return false; }
    switch (Kind)
    {
    case EBWInteractionKind::Phone: return StartMaraMessage();
    case EBWInteractionKind::Flashlight:
        if (Apply(Blackweb::Action::TakeFlashlight)) { ShowNotice(LOCTEXT("FlashlightTaken", "Flashlight ready.  F  ·  Switch light")); return true; }
        break;
    case EBWInteractionKind::Keys:
        if (Apply(Blackweb::Action::TakeKeys)) { ShowNotice(LOCTEXT("KeysTaken", "Car keys.")); return true; }
        break;
    case EBWInteractionKind::ExitDoor: return TryLeaveHouse();
    }
    return false;
}

FText ABWIntroDirector::GetInteractionHint(EBWInteractionKind Kind) const
{
    if (Kind == EBWInteractionKind::Phone && bWarningHeard) return LOCTEXT("PhoneAfter", "Mara isn't answering.");
    if (Kind == EBWInteractionKind::Phone && Stage == EBWIntroStage::Message) return FText::GetEmpty();
    if (!bWarningHeard) return LOCTEXT("PhoneFirst", "A message from Mara. I should listen.");
    if (Kind == EBWInteractionKind::ExitDoor)
    {
        if (!bHasKeys) return LOCTEXT("NeedKeys", "I need my car keys.");
        if (!bHasFlashlight) return LOCTEXT("NeedLight", "The flashlight. I'll need it.");
        if (!bEncounterSurvived) return LOCTEXT("ExitDanger", "Something's between me and the way out.");
    }
    return FText::GetEmpty();
}

FText ABWIntroDirector::GetObjective() const
{
    switch (Stage)
    {
    case EBWIntroStage::Normal: return LOCTEXT("ObjectiveNormal", "A message from Mara");
    case EBWIntroStage::Message: return FText::GetEmpty();
    case EBWIntroStage::Preparation:
        if (!bHasFlashlight && !bHasKeys) return LOCTEXT("ObjectivePrepare", "Find the car keys and flashlight");
        return bHasKeys ? LOCTEXT("ObjectiveLight", "Find the flashlight") : LOCTEXT("ObjectiveKeys", "Find the car keys");
    case EBWIntroStage::Presence: return LOCTEXT("ObjectivePresence", "Get ready to leave");
    case EBWIntroStage::PowerLoss: return LOCTEXT("ObjectivePower", "Keep your light close");
    case EBWIntroStage::Encounter: return LOCTEXT("ObjectiveEncounter", "Keep your distance. Find room to move.");
    case EBWIntroStage::ReadyToLeave: return LOCTEXT("ObjectiveExit", "Leave the house. Find Mara.");
    case EBWIntroStage::Complete: return LOCTEXT("ObjectiveComplete", "GREYHAVEN\nEnd of the house opening");
    }
    return FText::GetEmpty();
}

void ABWIntroDirector::ShowNotice(const FText& Text, float Duration)
{
    Notice = Text; NoticeRemaining = FMath::Max(0.1f, Duration);
}

bool ABWIntroDirector::ReadSave(const UBWSaveGame* Save, Blackweb::Progress& OutProgress) const
{
    if (!Save) return false;
    OutProgress.Version = Save->SchemaVersion;
    OutProgress.Current = static_cast<Blackweb::Stage>(Save->Stage);
    OutProgress.WarningHeard = Save->bWarningHeard;
    OutProgress.Flashlight = Save->bHasFlashlight;
    OutProgress.Keys = Save->bHasKeys;
    OutProgress.EncounterSurvived = Save->bEncounterSurvived;
    OutProgress.Departed = Save->bDeparted;
    return OutProgress.Normalize();
}

UBWSaveGame* ABWIntroDirector::CreateSave() const
{
    UBWSaveGame* Save = Cast<UBWSaveGame>(UGameplayStatics::CreateSaveGameObject(UBWSaveGame::StaticClass()));
    if (!Save) return nullptr;
    Save->SchemaVersion = Blackweb::Progress::CurrentVersion;
    Save->Stage = static_cast<uint8>(Progress.Current);
    Save->bWarningHeard = Progress.WarningHeard;
    Save->bHasFlashlight = Progress.Flashlight;
    Save->bHasKeys = Progress.Keys;
    Save->bEncounterSurvived = Progress.EncounterSurvived;
    Save->bDeparted = Progress.Departed;
    return Save;
}

bool ABWIntroDirector::SaveCheckpoint()
{
    if (bSaveWritesBlocked) return false;
    // Keep the last valid milestone as a separate fallback before replacing main.
    UBWSaveGame* Previous = Cast<UBWSaveGame>(UGameplayStatics::LoadGameFromSlot(SaveSlot, 0));
    Blackweb::Progress Checked;
    if (ReadSave(Previous, Checked)) UGameplayStatics::SaveGameToSlot(Previous, SaveSlot + TEXT("_backup"), 0);
    UBWSaveGame* Save = CreateSave();
    bLastSaveSucceeded = Save && UGameplayStatics::SaveGameToSlot(Save, SaveSlot, 0);
    if (!bLastSaveSucceeded) ShowNotice(LOCTEXT("SaveFailed", "Checkpoint could not be saved. You can keep playing."), 5.0f);
    return bLastSaveSucceeded;
}

bool ABWIntroDirector::ReloadCheckpoint()
{
    const bool bHadMain = UGameplayStatics::DoesSaveGameExist(SaveSlot, 0);
    UBWSaveGame* Save = Cast<UBWSaveGame>(UGameplayStatics::LoadGameFromSlot(SaveSlot, 0));
    if (Save && Save->SchemaVersion != Blackweb::Progress::CurrentVersion)
    {
        bSaveWritesBlocked = true;
        ShowNotice(LOCTEXT("UnknownSave", "This checkpoint belongs to another version. Starting without overwriting it."), 7.0f);
        return false;
    }
    Blackweb::Progress Restored;
    if (!ReadSave(Save, Restored))
    {
        Save = Cast<UBWSaveGame>(UGameplayStatics::LoadGameFromSlot(SaveSlot + TEXT("_backup"), 0));
        if (!ReadSave(Save, Restored))
        {
            if (bHadMain) ShowNotice(LOCTEXT("UnreadableSave", "Checkpoint could not be read. The opening is available from the start."), 6.0f);
            return false;
        }
    }
    Progress = Restored;
    RetryCurrentMilestone();
    return true;
}

void ABWIntroDirector::RetryCurrentMilestone()
{
    RefreshState(true);
    if (ABWPlayerCharacter* Player = Cast<ABWPlayerCharacter>(UGameplayStatics::GetPlayerCharacter(this, 0)))
    {
        Player->ResetAfterCheckpoint(CheckpointAnchor);
    }
    OnCheckpointRestored();
}

void ABWIntroDirector::RestartOpening()
{
    Progress = Blackweb::Progress();
    bSaveWritesBlocked = false;
    RefreshState(true);
    SaveCheckpoint();
    if (ABWPlayerCharacter* Player = Cast<ABWPlayerCharacter>(UGameplayStatics::GetPlayerCharacter(this, 0))) Player->ResetAfterCheckpoint(CheckpointAnchor);
    OnCheckpointRestored();
}
#undef LOCTEXT_NAMESPACE
