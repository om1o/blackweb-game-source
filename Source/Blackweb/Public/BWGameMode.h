#pragma once
#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "BWGameMode.generated.h"

class USkeletalMesh;
class UAnimInstance;

UCLASS(Blueprintable)
class BLACKWEB_API ABWGameMode : public AGameModeBase
{
    GENERATED_BODY()
public:
    ABWGameMode();
    virtual void BeginPlay() override;
    virtual APawn* SpawnDefaultPawnAtTransform_Implementation(AController* NewPlayer, const FTransform& SpawnTransform) override;
    UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="Player") USkeletalMesh* PlayerMesh = nullptr;
    UPROPERTY(EditDefaultsOnly, BlueprintReadWrite, Category="Player") TSubclassOf<UAnimInstance> PlayerAnimationClass;
};
