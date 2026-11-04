#pragma once
#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "BWHUD.generated.h"

UCLASS()
class BLACKWEB_API ABWHUD : public AHUD
{
    GENERATED_BODY()
public:
    virtual void DrawHUD() override;
private:
    float VisibleTime = 0.0f;
    void DrawCenteredText(const FText& Text, float Y, float MaxWidth, float Scale, bool bBackdrop);
};
