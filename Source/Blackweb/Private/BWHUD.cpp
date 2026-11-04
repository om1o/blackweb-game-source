#include "BWHUD.h"
#include "BWIntroDirector.h"
#include "BWPlayerCharacter.h"
#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "Engine/Font.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"

#define LOCTEXT_NAMESPACE "BlackwebHUD"
void ABWHUD::DrawCenteredText(const FText& Text, float Y, float MaxWidth, float Scale, bool bBackdrop)
{
    if (!Canvas || Text.IsEmpty()) return;
    UFont* Font = GEngine->GetMediumFont();
    TArray<FString> Paragraphs;
    Text.ToString().ParseIntoArray(Paragraphs, TEXT("\n"), false);
    TArray<FString> Lines;
    for (const FString& Paragraph : Paragraphs)
    {
        TArray<FString> Words;
        Paragraph.ParseIntoArrayWS(Words);
        FString Line;
        for (const FString& Word : Words)
        {
            const FString Proposed = Line.IsEmpty() ? Word : Line + TEXT(" ") + Word;
            float Width = 0.0f, Height = 0.0f;
            GetTextSize(Proposed, Width, Height, Font, Scale);
            if (Width > MaxWidth && !Line.IsEmpty()) { Lines.Add(Line); Line = Word; }
            else Line = Proposed;
        }
        Lines.Add(Line);
    }
    const float LineHeight = 26.0f * Scale;
    if (bBackdrop)
    {
        DrawRect(FLinearColor(0.015f, 0.02f, 0.025f, 0.82f), (Canvas->ClipX-MaxWidth)*0.5f-16.0f,
                 Y-10.0f, MaxWidth+32.0f, Lines.Num()*LineHeight+20.0f);
    }
    for (const FString& Line : Lines)
    {
        float Width = 0.0f, Height = 0.0f;
        GetTextSize(Line, Width, Height, Font, Scale);
        DrawText(Line, FLinearColor(0.91f, 0.91f, 0.86f), (Canvas->ClipX-Width)*0.5f, Y, Font, Scale, false);
        Y += LineHeight;
    }
}

void ABWHUD::DrawHUD()
{
    Super::DrawHUD();
    if (!Canvas || !GEngine) return;
    VisibleTime += GetWorld()->GetDeltaSeconds();
    ABWPlayerCharacter* Player = PlayerOwner ? Cast<ABWPlayerCharacter>(PlayerOwner->GetPawn()) : nullptr;
    ABWIntroDirector* Director = Player ? Player->GetIntroDirector() : ABWIntroDirector::FindDirector(this);
    if (!Director) return;
    const float Scale = FMath::Clamp(Canvas->ClipY / 1080.0f, 0.85f, 1.3f);
    const float Margin = 38.0f * Scale;
    if (Director->Stage == EBWIntroStage::Complete)
    {
        DrawRect(FLinearColor(0.005f, 0.008f, 0.01f, 0.94f), 0.0f, 0.0f, Canvas->ClipX, Canvas->ClipY);
        DrawCenteredText(LOCTEXT("ChapterEnd", "ARACHNOPHOBIA: BLACKWEB\nLuke leaves for Greyhaven."), Canvas->ClipY*0.42f, Canvas->ClipX*0.75f, Scale*1.1f, false);
        DrawCenteredText(LOCTEXT("OpeningEnd", "End of the house opening\nR  ·  Play the opening again"), Canvas->ClipY*0.60f, Canvas->ClipX*0.7f, Scale*0.85f, false);
        return;
    }
    const FText Objective = Director->GetObjective();
    if (!Objective.IsEmpty()) DrawText(Objective.ToString(), FLinearColor(0.78f, 0.79f, 0.74f, 0.9f), Margin, Margin, GEngine->GetSmallFont(), Scale*1.1f);
    if (Player) DrawCenteredText(Player->GetFocusPrompt(), Canvas->ClipY*0.65f, Canvas->ClipX*0.65f, Scale, false);
    DrawCenteredText(Director->Notice, Canvas->ClipY*0.75f, Canvas->ClipX*0.66f, Scale*0.9f, false);
    DrawCenteredText(Director->Subtitle, Canvas->ClipY*0.85f, Canvas->ClipX*0.70f, Scale, true);
    if (VisibleTime < 7.0f && Director->Stage == EBWIntroStage::Normal)
        DrawCenteredText(LOCTEXT("FirstControls", "W A S D  ·  Move     Mouse  ·  Look     E  ·  Interact"), Canvas->ClipY*0.92f, Canvas->ClipX*0.85f, Scale*0.85f, false);
}
#undef LOCTEXT_NAMESPACE
