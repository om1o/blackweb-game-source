#include "BWInteractable.h"
#include "BWIntroDirector.h"
#include "Components/BoxComponent.h"
#include "Components/StaticMeshComponent.h"

#define LOCTEXT_NAMESPACE "BlackwebInteraction"
ABWInteractable::ABWInteractable()
{
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.TickInterval = 0.15f;
    InteractionBounds = CreateDefaultSubobject<UBoxComponent>(TEXT("InteractionBounds"));
    SetRootComponent(InteractionBounds);
    InteractionBounds->SetBoxExtent(FVector(18.0f));
    InteractionBounds->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    InteractionBounds->SetCollisionObjectType(ECC_WorldDynamic);
    InteractionBounds->SetCollisionResponseToAllChannels(ECR_Ignore);
    InteractionBounds->SetCollisionResponseToChannel(ECC_Visibility, ECR_Block);
    Visual = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Visual"));
    Visual->SetupAttachment(RootComponent);
    Visual->SetCollisionEnabled(ECollisionEnabled::NoCollision);
}

void ABWInteractable::BeginPlay()
{
    Super::BeginPlay();
    Intro = ABWIntroDirector::FindDirector(this);
    Tick(0.0f);
}

void ABWInteractable::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);
    if (!Intro.IsValid()) Intro = ABWIntroDirector::FindDirector(this);
    if (!Intro.IsValid()) return;
    const bool bCollected = (Kind == EBWInteractionKind::Flashlight && Intro->bHasFlashlight) ||
                            (Kind == EBWInteractionKind::Keys && Intro->bHasKeys);
    SetActorHiddenInGame(bHideWhenCollected && bCollected);
    SetActorEnableCollision(!bCollected);
}

FVector ABWInteractable::GetInteractionLocation() const { return InteractionBounds->GetComponentLocation(); }

FText ABWInteractable::GetPrompt() const
{
    if (!Prompt.IsEmpty()) return Prompt;
    switch (Kind)
    {
    case EBWInteractionKind::Phone: return LOCTEXT("Phone", "Listen to Mara's message");
    case EBWInteractionKind::Flashlight: return LOCTEXT("Flashlight", "Take flashlight");
    case EBWInteractionKind::Keys: return LOCTEXT("Keys", "Take car keys");
    case EBWInteractionKind::ExitDoor: return LOCTEXT("Exit", "Leave for Greyhaven");
    }
    return FText::GetEmpty();
}

bool ABWInteractable::Use(ABWIntroDirector* Director)
{
    if (!IsValid(Director)) return false;
    if (!Director->Interact(Kind)) return false;
    if (!InspectText.IsEmpty()) Director->ShowNotice(InspectText);
    OnUsed();
    Tick(0.0f);
    return true;
}
#undef LOCTEXT_NAMESPACE
