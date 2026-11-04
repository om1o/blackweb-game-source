#pragma once
#include <cstdint>

// Independent of Unreal: the same state rules drive the game and portable tests.
namespace Blackweb
{
enum class Stage : std::uint8_t
{
    Normal, Message, Preparation, Presence, PowerLoss, Encounter, ReadyToLeave, Complete
};
enum class Action : std::uint8_t
{
    StartMessage, FinishMessage, TakeFlashlight, TakeKeys, RevealPresence,
    LosePower, StartEncounter, SurviveEncounter, Leave
};

struct Progress
{
    static constexpr int CurrentVersion = 1;
    int Version = CurrentVersion;
    Stage Current = Stage::Normal;
    bool WarningHeard = false;
    bool Flashlight = false;
    bool Keys = false;
    bool EncounterSurvived = false;
    bool Departed = false;

    bool Prepared() const { return WarningHeard && Flashlight && Keys; }
    bool CanLeave() const { return Prepared() && EncounterSurvived && !Departed; }

    // Corrupt/impossible flags are repaired toward the earliest playable stage.
    // Unknown schemas are rejected, never interpreted as current saves.
    bool Normalize()
    {
        if (Version != CurrentVersion) return false;
        if (!WarningHeard)
        {
            Flashlight = Keys = EncounterSurvived = Departed = false;
            Current = Current == Stage::Message ? Stage::Message : Stage::Normal;
        }
        else if (!Prepared())
        {
            EncounterSurvived = Departed = false;
            Current = Stage::Preparation;
        }
        else if (EncounterSurvived)
            Current = Departed ? Stage::Complete : Stage::ReadyToLeave;
        else
        {
            Departed = false;
            if (Current != Stage::Presence && Current != Stage::PowerLoss && Current != Stage::Encounter)
                Current = Stage::Presence;
        }
        return true;
    }

    bool Apply(Action Event)
    {
        if (Version != CurrentVersion || Current == Stage::Complete) return false;
        switch (Event)
        {
        case Action::StartMessage:
            if (Current != Stage::Normal) return false;
            Current = Stage::Message; return true;
        case Action::FinishMessage:
            if (Current != Stage::Message) return false;
            WarningHeard = true; Current = Stage::Preparation; return true;
        case Action::TakeFlashlight:
            if (!WarningHeard || Flashlight) return false;
            Flashlight = true; break;
        case Action::TakeKeys:
            if (!WarningHeard || Keys) return false;
            Keys = true; break;
        case Action::RevealPresence:
            if (!Prepared() || Current != Stage::Preparation) return false;
            Current = Stage::Presence; return true;
        case Action::LosePower:
            if (Current != Stage::Presence) return false;
            Current = Stage::PowerLoss; return true;
        case Action::StartEncounter:
            if (Current != Stage::PowerLoss) return false;
            Current = Stage::Encounter; return true;
        case Action::SurviveEncounter:
            if (Current != Stage::Encounter) return false;
            EncounterSurvived = true; Current = Stage::ReadyToLeave; return true;
        case Action::Leave:
            if (!CanLeave() || Current != Stage::ReadyToLeave) return false;
            Departed = true; Current = Stage::Complete; return true;
        }
        // Either pickup order leads to the same next stage, without another trigger.
        if (Prepared()) Current = Stage::Presence;
        return true;
    }
};
}
