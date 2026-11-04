#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "BWTypes.h"
#include "TimerManager.h"
#include "BWSpiderEncounter.generated.h"

class ABWIntroDirector;
class UAnimSequence;
class USoundBase;

UENUM(BlueprintType)
enum class EBWSpiderState : uint8
{
    Dormant,
    Anticipation,
    Stalking,
    Windup,
    Lunging,
    Retreating,
    Cooldown,
    Resolved
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FBWSpiderStateChanged, EBWSpiderState, State);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FBWSpiderThreatenedPlayer, AActor*, Player);

/** A short, avoidable floor encounter. Navigation and capsule collision own all live movement. */
UCLASS(Blueprintable)
class BLACKWEB_API ABWSpiderEncounter : public ACharacter
{
    GENERATED_BODY()

public:
    ABWSpiderEncounter();
    virtual void Tick(float DeltaSeconds) override;

    UFUNCTION(BlueprintCallable, Category="Blackweb|Spider")
    void ActivateEncounter(AActor* Player, ABWIntroDirector* Director);

    UFUNCTION(BlueprintCallable, Category="Blackweb|Spider")
    void DeactivateEncounter();

    /** Call from a player-only safe/exit trigger. Immediately cancels attacks, then resolves after a short beat. */
    UFUNCTION(BlueprintCallable, Category="Blackweb|Spider")
    void ResolveAtExit();

    UPROPERTY(BlueprintReadOnly, Category="Blackweb|Spider")
    EBWSpiderState EncounterState = EBWSpiderState::Dormant;

    UPROPERTY(BlueprintAssignable, Category="Blackweb|Spider")
    FBWSpiderStateChanged OnEncounterStateChanged;

    /** Contact cue, once per lunge, after range and collision validation. */
    UPROPERTY(BlueprintAssignable, Category="Blackweb|Spider")
    FBWSpiderThreatenedPlayer OnThreatenedPlayer;

    UPROPERTY(EditInstanceOnly, BlueprintReadWrite, Category="Blackweb|Spider|Integration")
    TObjectPtr<ABWIntroDirector> IntroDirector;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Integration")
    bool bAutoBindDirector = true;

    /** Optional player-safe marker. Place inside the escape route, beyond the encounter, not at player spawn. */
    UPROPERTY(EditInstanceOnly, BlueprintReadWrite, Category="Blackweb|Spider|Integration")
    TObjectPtr<AActor> SafeExitAnchor;

    /** Optional retreat marker on the same navigable floor. Without one, retreat away from the player. */
    UPROPERTY(EditInstanceOnly, BlueprintReadWrite, Category="Blackweb|Spider|Integration")
    TObjectPtr<AActor> RetreatAnchor;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Integration", meta=(ClampMin="50.0"))
    float SafeExitRadius = 160.f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Integration", meta=(ClampMin="0.0"))
    float SafeExitHoldSeconds = 1.25f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Integration", meta=(ClampMin="0.0"))
    float ExitResolutionDelay = 1.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Timing", meta=(ClampMin="0.5"))
    float AnticipationSeconds = 1.5f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Timing", meta=(ClampMin="0.4"))
    float WindupSeconds = 0.85f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Timing", meta=(ClampMin="0.2", ClampMax="1.5"))
    float LungeSeconds = 0.7f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Timing", meta=(ClampMin="1.0"))
    float CooldownSeconds = 2.6f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Movement", meta=(ClampMin="10.0"))
    float StalkSpeed = 165.f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Movement", meta=(ClampMin="10.0"))
    float LungeSpeed = 560.f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Movement", meta=(ClampMin="100.0"))
    float WindupDistance = 330.f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Movement", meta=(ClampMin="20.0"))
    float ThreatDistance = 115.f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Encounter", meta=(ClampMin="0.0"))
    float ContactDamage = 35.f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Animation")
    TObjectPtr<UAnimSequence> IdleAnimation;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Animation")
    TObjectPtr<UAnimSequence> WalkAnimation;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Animation")
    TObjectPtr<UAnimSequence> RunAnimation;

    /** In-place animation reference speeds, in cm/s. Set after verifying recovered clip stride lengths. */
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Animation", meta=(ClampMin="1.0"))
    float WalkReferenceSpeed = 165.f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Animation", meta=(ClampMin="1.0"))
    float RunReferenceSpeed = 420.f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Audio")
    TObjectPtr<USoundBase> WindupSound;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Blackweb|Spider|Audio")
    TObjectPtr<USoundBase> LungeSound;

protected:
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type EndPlayReason) override;

private:
    UFUNCTION()
    void HandleIntroStageChanged(EBWIntroStage Stage);

    void Think();
    void EnterState(EBWSpiderState NewState);
    void StartLunge();
    void StartRetreat();
    void FinishResolution();
    void StopLocomotion();
    void UpdateAnimation();
    bool RequestPathTo(const FVector& Destination, float AcceptanceRadius);
    bool HasClearAttackLane(float MaximumDistance) const;
    FVector TargetFloorLocation() const;

    TWeakObjectPtr<AActor> TargetPlayer;
    TWeakObjectPtr<UAnimSequence> PlayingAnimation;
    FTimerHandle ThinkTimer;
    FTimerHandle ResolveTimer;
    FTransform PlacedTransform;
    FVector CommittedLungeDestination = FVector::ZeroVector;
    double StateStartedAt = 0.0;
    double NextPathRequestAt = 0.0;
    double SafeSince = -1.0;
    int32 ConsecutivePathFailures = 0;
    bool bThreatRaisedThisLunge = false;
    bool bResolutionPending = false;
};
