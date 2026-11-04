// Compile with /DBLACKWEB_PORTABLE_TEST to run without an Unreal installation.
#if defined(BLACKWEB_PORTABLE_TEST)
#include "BWProgression.h"
#include <cstdlib>
#include <iostream>
using namespace Blackweb;
static int Checks = 0;
#define CHECK(condition) do { ++Checks; if (!(condition)) { std::cerr << "FAILED line " << __LINE__ << ": " << #condition << '\n'; std::exit(1); } } while (false)

static void AssertInvariants(const Progress& P)
{
    CHECK(static_cast<int>(P.Current) >= 0 && static_cast<int>(P.Current) <= static_cast<int>(Stage::Complete));
    CHECK(!P.EncounterSurvived || P.Prepared());
    CHECK(!P.Departed || (P.Prepared() && P.EncounterSurvived));
    CHECK(P.Current != Stage::Complete || P.Departed);
    CHECK(P.Current != Stage::ReadyToLeave || P.CanLeave());
    CHECK(P.Current < Stage::Presence || P.Prepared());
}

int main()
{
    for (int KeysFirst = 0; KeysFirst < 2; ++KeysFirst)
    {
        Progress P;
        CHECK(!P.Apply(Action::Leave));
        CHECK(!P.Apply(Action::TakeKeys));
        CHECK(!P.Apply(Action::TakeFlashlight));
        CHECK(!P.Apply(Action::SurviveEncounter));
        CHECK(P.Apply(Action::StartMessage));
        CHECK(!P.Apply(Action::StartMessage));
        Progress Interrupted = P;
        CHECK(Interrupted.Normalize());
        CHECK(Interrupted.Current == Stage::Message); // A reload replays the interrupted warning.
        CHECK(P.Apply(Action::FinishMessage));
        CHECK(P.Apply(KeysFirst ? Action::TakeKeys : Action::TakeFlashlight));
        CHECK(P.Current == Stage::Preparation);
        CHECK(!P.Apply(Action::Leave));
        CHECK(!P.Apply(Action::LosePower));
        CHECK(P.Apply(KeysFirst ? Action::TakeFlashlight : Action::TakeKeys));
        CHECK(P.Current == Stage::Presence);
        CHECK(!P.Apply(Action::TakeKeys));
        CHECK(!P.Apply(Action::TakeFlashlight));
        CHECK(!P.Apply(Action::StartEncounter));
        CHECK(P.Apply(Action::LosePower));
        CHECK(!P.Apply(Action::Leave));
        CHECK(P.Apply(Action::StartEncounter));
        Progress Retry = P;
        CHECK(Retry.Normalize());
        CHECK(Retry.Current == Stage::Encounter && Retry.Keys && Retry.Flashlight);
        CHECK(P.Apply(Action::SurviveEncounter));
        CHECK(P.CanLeave());
        CHECK(P.Apply(Action::Leave));
        CHECK(!P.CanLeave());
        CHECK(!P.Apply(Action::Leave));
        CHECK(P.Normalize());
        CHECK(P.Current == Stage::Complete);
        AssertInvariants(P);
    }

    // Every possible persisted byte/flag combination must restore a playable state.
    for (int StageByte = 0; StageByte < 256; ++StageByte)
    for (int Bits = 0; Bits < 32; ++Bits)
    {
        Progress P;
        P.Current = static_cast<Stage>(StageByte);
        P.WarningHeard = (Bits & 1) != 0;
        P.Flashlight = (Bits & 2) != 0;
        P.Keys = (Bits & 4) != 0;
        P.EncounterSurvived = (Bits & 8) != 0;
        P.Departed = (Bits & 16) != 0;
        CHECK(P.Normalize());
        AssertInvariants(P);
        const Progress Once = P;
        CHECK(P.Normalize());
        CHECK(P.Current == Once.Current && P.WarningHeard == Once.WarningHeard && P.Flashlight == Once.Flashlight && P.Keys == Once.Keys && P.EncounterSurvived == Once.EncounterSurvived && P.Departed == Once.Departed);
        // From any normalized noncomplete restore, the normal actions can finish.
        if (P.Current == Stage::Normal) CHECK(P.Apply(Action::StartMessage));
        if (P.Current == Stage::Message) CHECK(P.Apply(Action::FinishMessage));
        if (!P.Keys) CHECK(P.Apply(Action::TakeKeys));
        if (!P.Flashlight) CHECK(P.Apply(Action::TakeFlashlight));
        if (P.Current == Stage::Preparation) CHECK(P.Apply(Action::RevealPresence));
        if (P.Current == Stage::Presence) CHECK(P.Apply(Action::LosePower));
        if (P.Current == Stage::PowerLoss) CHECK(P.Apply(Action::StartEncounter));
        if (P.Current == Stage::Encounter) CHECK(P.Apply(Action::SurviveEncounter));
        if (P.Current == Stage::ReadyToLeave) CHECK(P.Apply(Action::Leave));
        CHECK(P.Current == Stage::Complete);
    }
    Progress Future;
    Future.Version = 2;
    CHECK(!Future.Normalize());
    CHECK(!Future.Apply(Action::StartMessage));
    CHECK(Future.Current == Stage::Normal && Future.Version == 2);
    std::cout << "PASS: " << Checks << " checks; both pickup orders, exit gates, all 8192 persisted flag/stage combinations, reachable completion, idempotent restore, unknown-schema rejection.\n";
}
#endif
