#include "BWGameMode.h"
#include "BWPlayerCharacter.h"
#include "BWIntroDirector.h"
#include "BWHUD.h"
#include "Animation/AnimInstance.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/World.h"

ABWGameMode::ABWGameMode()
{
    DefaultPawnClass = ABWPlayerCharacter::StaticClass();
    HUDClass = ABWHUD::StaticClass();
}

void ABWGameMode::BeginPlay()
{
    Super::BeginPlay();
    if (!ABWIntroDirector::FindDirector(this)) GetWorld()->SpawnActor<ABWIntroDirector>();
}

APawn* ABWGameMode::SpawnDefaultPawnAtTransform_Implementation(AController* NewPlayer, const FTransform& SpawnTransform)
{
    APawn* Pawn = Super::SpawnDefaultPawnAtTransform_Implementation(NewPlayer, SpawnTransform);
    if (ABWPlayerCharacter* Player = Cast<ABWPlayerCharacter>(Pawn))
    {
        if (PlayerMesh) Player->GetMesh()->SetSkeletalMesh(PlayerMesh);
        if (PlayerAnimationClass) Player->GetMesh()->SetAnimInstanceClass(PlayerAnimationClass);
    }
    return Pawn;
}
