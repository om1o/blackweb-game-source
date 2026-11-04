#include "BWSpiderEncounter.h"

#include "AIController.h"
#include "Animation/AnimInstance.h"
#include "Animation/AnimSequence.h"
#include "Animation/AnimSingleNodeInstance.h"
#include "BWIntroDirector.h"
#include "BWPlayerCharacter.h"
#include "Components/CapsuleComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/SkeletalMesh.h"
#include "Engine/World.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"
#include "Navigation/PathFollowingComponent.h"
#include "NavigationSystem.h"
#include "Sound/SoundBase.h"
#include "TimerManager.h"

ABWSpiderEncounter::ABWSpiderEncounter()
{
    PrimaryActorTick.bCanEverTick = true;
    PrimaryActorTick.bStartWithTickEnabled = false;
    AIControllerClass = AAIController::StaticClass();
    AutoPossessAI = EAutoPossessAI::PlacedInWorldOrSpawned;
    bUseControllerRotationYaw = false;

    GetCapsuleComponent()->InitCapsuleSize(32.f, 32.f);
    GetCapsuleComponent()->SetCollisionProfileName(TEXT("Pawn"));
    GetMesh()->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    GetMesh()->SetRelativeLocation(FVector(0.f, 0.f, -32.f));
    GetMesh()->VisibilityBasedAnimTickOption = EVisibilityBasedAnimTickOption::OnlyTickPoseWhenRendered;

    UCharacterMovementComponent* Movement = GetCharacterMovement();
    Movement->bOrientRotationToMovement = true;
    Movement->RotationRate = FRotator(0.f, 210.f, 0.f);
    Movement->MaxAcceleration = 650.f;
    Movement->BrakingDecelerationWalking = 1000.f;
    Movement->MaxWalkSpeed = StalkSpeed;
    Movement->MaxStepHeight = 20.f;
    Movement->SetWalkableFloorAngle(46.f);
    Movement->bCanWalkOffLedges = false;
}

void ABWSpiderEncounter::BeginPlay()
{
    Super::BeginPlay();
    PlacedTransform = GetActorTransform();
    DeactivateEncounter();

    if (bAutoBindDirector)
    {
        if (!IsValid(IntroDirector))
        {
            IntroDirector = ABWIntroDirector::FindDirector(this);
        }
        if (IsValid(IntroDirector))
        {
            IntroDirector->StageChanged.AddUniqueDynamic(this, &ABWSpiderEncounter::HandleIntroStageChanged);
            HandleIntroStageChanged(IntroDirector->Stage);
        }
    }
}

void ABWSpiderEncounter::EndPlay(const EEndPlayReason::Type EndPlayReason)
{
    GetWorldTimerManager().ClearTimer(ThinkTimer);
    GetWorldTimerManager().ClearTimer(ResolveTimer);
    if (IsValid(IntroDirector))
    {
        IntroDirector->StageChanged.RemoveDynamic(this, &ABWSpiderEncounter::HandleIntroStageChanged);
    }
    Super::EndPlay(EndPlayReason);
}

void ABWSpiderEncounter::HandleIntroStageChanged(EBWIntroStage Stage)
{
    if (Stage == EBWIntroStage::Encounter)
    {
        // The director rebroadcasts the current stage on checkpoint reload.
        // Reset an active encounter as well as activating a dormant one.
        DeactivateEncounter();
        SetActorTransform(PlacedTransform, false, nullptr, ETeleportType::TeleportPhysics);
        ActivateEncounter(UGameplayStatics::GetPlayerPawn(this, 0), IntroDirector);
        return;
    }

    DeactivateEncounter();
    if (Stage == EBWIntroStage::ReadyToLeave || Stage == EBWIntroStage::Complete)
    {
        EnterState(EBWSpiderState::Resolved);
    }
    if (static_cast<uint8>(Stage) < static_cast<uint8>(EBWIntroStage::Encounter))
    {
        // Checkpoint restoration is the only reposition. Live navigation never teleports.
        SetActorTransform(PlacedTransform, false, nullptr, ETeleportType::TeleportPhysics);
    }
}

void ABWSpiderEncounter::ActivateEncounter(AActor* Player, ABWIntroDirector* Director)
{
    if (!IsValid(Player) || (EncounterState != EBWSpiderState::Dormant && EncounterState != EBWSpiderState::Resolved))
    {
        return;
    }

    TargetPlayer = Player;
    if (IsValid(Director))
    {
        IntroDirector = Director;
    }
    GetWorldTimerManager().ClearTimer(ResolveTimer);
    SafeSince = -1.0;
    NextPathRequestAt = 0.0;
    ConsecutivePathFailures = 0;
    bResolutionPending = false;
    bThreatRaisedThisLunge = false;
    SetActorHiddenInGame(false);
    SetActorEnableCollision(true);
    SetActorTickEnabled(true);
    GetMesh()->SetComponentTickEnabled(true);
    GetCharacterMovement()->SetComponentTickEnabled(true);
    GetCharacterMovement()->SetMovementMode(MOVE_Walking);
    if (!GetController())
    {
        SpawnDefaultController();
    }
    EnterState(EBWSpiderState::Anticipation);
    GetWorldTimerManager().SetTimer(ThinkTimer, this, &ABWSpiderEncounter::Think, 0.12f, true);
}

void ABWSpiderEncounter::DeactivateEncounter()
{
    GetWorldTimerManager().ClearTimer(ThinkTimer);
    GetWorldTimerManager().ClearTimer(ResolveTimer);
    StopLocomotion();
    TargetPlayer.Reset();
    bResolutionPending = false;
    SafeSince = -1.0;
    SetActorHiddenInGame(true);
    SetActorEnableCollision(false);
    SetActorTickEnabled(false);
    GetCharacterMovement()->DisableMovement();
    GetCharacterMovement()->SetComponentTickEnabled(false);
    GetMesh()->SetComponentTickEnabled(false);
    EnterState(EBWSpiderState::Dormant);
}

void ABWSpiderEncounter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);
    if (TargetPlayer.IsValid() && (EncounterState == EBWSpiderState::Anticipation || EncounterState == EBWSpiderState::Windup))
    {
        const float DesiredYaw = (TargetPlayer->GetActorLocation() - GetActorLocation()).Rotation().Yaw;
        SetActorRotation(FRotator(0.f, FMath::FixedTurn(GetActorRotation().Yaw, DesiredYaw, 210.f * DeltaSeconds), 0.f));
    }
    UpdateAnimation();
}

void ABWSpiderEncounter::Think()
{
    if (bResolutionPending)
    {
        return;
    }
    if (!TargetPlayer.IsValid())
    {
        DeactivateEncounter();
        return;
    }

    if (const ABWPlayerCharacter* Player = Cast<ABWPlayerCharacter>(TargetPlayer.Get()))
    {
        if (Player->bIsRecovering)
        {
            StopLocomotion();
            SafeSince = -1.0;
            return;
        }
    }

    const double Now = GetWorld()->GetTimeSeconds();
    if (IsValid(SafeExitAnchor) && FVector::Dist(TargetPlayer->GetActorLocation(), SafeExitAnchor->GetActorLocation()) <= SafeExitRadius)
    {
        SafeSince = SafeSince < 0.0 ? Now : SafeSince;
        if (Now - SafeSince >= SafeExitHoldSeconds)
        {
            ResolveAtExit();
            return;
        }
    }
    else
    {
        SafeSince = -1.0;
    }

    const double Elapsed = Now - StateStartedAt;
    switch (EncounterState)
    {
    case EBWSpiderState::Anticipation:
        if (Elapsed >= AnticipationSeconds)
        {
            EnterState(EBWSpiderState::Stalking);
        }
        break;
    case EBWSpiderState::Stalking:
        if (HasClearAttackLane(WindupDistance))
        {
            EnterState(EBWSpiderState::Windup);
        }
        else if (Now >= NextPathRequestAt)
        {
            NextPathRequestAt = Now + 0.7;
            if (!RequestPathTo(TargetFloorLocation(), 85.f) && ++ConsecutivePathFailures >= 3)
            {
                // A blocked route produces a pause and another attempt, never direct movement through geometry.
                EnterState(EBWSpiderState::Cooldown);
            }
        }
        break;
    case EBWSpiderState::Windup:
        if (Elapsed >= WindupSeconds)
        {
            StartLunge();
        }
        break;
    case EBWSpiderState::Lunging:
        if (!bThreatRaisedThisLunge && HasClearAttackLane(ThreatDistance))
        {
            bThreatRaisedThisLunge = true;
            UGameplayStatics::ApplyDamage(TargetPlayer.Get(), ContactDamage, GetController(), this, nullptr);
            OnThreatenedPlayer.Broadcast(TargetPlayer.Get());
            StartRetreat();
        }
        else if (Elapsed >= LungeSeconds)
        {
            StartRetreat();
        }
        break;
    case EBWSpiderState::Retreating:
        if (Elapsed >= 1.35)
        {
            EnterState(EBWSpiderState::Cooldown);
        }
        break;
    case EBWSpiderState::Cooldown:
        if (Elapsed >= CooldownSeconds)
        {
            ConsecutivePathFailures = 0;
            EnterState(EBWSpiderState::Stalking);
        }
        break;
    default:
        break;
    }
}

void ABWSpiderEncounter::EnterState(EBWSpiderState NewState)
{
    if (EncounterState == NewState)
    {
        return;
    }
    EncounterState = NewState;
    StateStartedAt = GetWorld() ? GetWorld()->GetTimeSeconds() : 0.0;
    UCharacterMovementComponent* Movement = GetCharacterMovement();
    const bool bMoving = NewState == EBWSpiderState::Stalking || NewState == EBWSpiderState::Lunging || NewState == EBWSpiderState::Retreating;
    Movement->bOrientRotationToMovement = bMoving;
    Movement->MaxWalkSpeed = NewState == EBWSpiderState::Lunging ? LungeSpeed : StalkSpeed;
    Movement->MaxAcceleration = NewState == EBWSpiderState::Lunging ? 1500.f : 650.f;
    if (!bMoving)
    {
        StopLocomotion();
    }
    if (NewState == EBWSpiderState::Windup && WindupSound)
    {
        UGameplayStatics::PlaySoundAtLocation(this, WindupSound, GetActorLocation(), 0.7f);
    }
    if (NewState == EBWSpiderState::Lunging && LungeSound)
    {
        UGameplayStatics::PlaySoundAtLocation(this, LungeSound, GetActorLocation(), 0.8f);
    }
    OnEncounterStateChanged.Broadcast(NewState);
}

void ABWSpiderEncounter::StartLunge()
{
    // Re-check after the telegraph: stepping behind a wall or out of range defeats the attack.
    if (!HasClearAttackLane(WindupDistance))
    {
        StartRetreat();
        return;
    }
    CommittedLungeDestination = TargetFloorLocation();
    bThreatRaisedThisLunge = false;
    EnterState(EBWSpiderState::Lunging);
    // Commit to the target's old position. No homing correction during a lunge.
    if (!RequestPathTo(CommittedLungeDestination, 35.f))
    {
        StartRetreat();
    }
}

void ABWSpiderEncounter::StartRetreat()
{
    if (!TargetPlayer.IsValid())
    {
        DeactivateEncounter();
        return;
    }
    EnterState(EBWSpiderState::Retreating);
    const FVector Away = (GetActorLocation() - TargetPlayer->GetActorLocation()).GetSafeNormal2D();
    const FVector Destination = IsValid(RetreatAnchor) ? RetreatAnchor->GetActorLocation() : GetActorLocation() + Away * 260.f;
    if (!RequestPathTo(Destination, 40.f))
    {
        EnterState(EBWSpiderState::Cooldown);
    }
}

bool ABWSpiderEncounter::RequestPathTo(const FVector& Destination, float AcceptanceRadius)
{
    AAIController* AI = Cast<AAIController>(GetController());
    UNavigationSystemV1* Navigation = FNavigationSystem::GetCurrent<UNavigationSystemV1>(GetWorld());
    if (!AI || !Navigation || !GetCharacterMovement()->IsMovingOnGround())
    {
        StopLocomotion();
        return false;
    }

    FNavLocation Goal;
    if (!Navigation->ProjectPointToNavigation(Destination, Goal, FVector(80.f, 80.f, 120.f), &GetNavAgentPropertiesRef()))
    {
        StopLocomotion();
        return false;
    }

    const EPathFollowingRequestResult::Type Result = AI->MoveToLocation(Goal.Location, AcceptanceRadius, true, true, false, false, nullptr, false);
    if (Result == EPathFollowingRequestResult::Failed)
    {
        StopLocomotion();
        return false;
    }
    ConsecutivePathFailures = 0;
    return true;
}

FVector ABWSpiderEncounter::TargetFloorLocation() const
{
    if (const ACharacter* Character = Cast<ACharacter>(TargetPlayer.Get()))
    {
        return Character->GetActorLocation() - FVector(0.f, 0.f, Character->GetCapsuleComponent()->GetScaledCapsuleHalfHeight());
    }
    return TargetPlayer.IsValid() ? TargetPlayer->GetActorLocation() : GetActorLocation();
}

bool ABWSpiderEncounter::HasClearAttackLane(float MaximumDistance) const
{
    if (!TargetPlayer.IsValid() || !GetWorld() || !GetCharacterMovement()->IsMovingOnGround())
    {
        return false;
    }
    const FVector Start = GetActorLocation();
    const FVector TargetFloor = TargetFloorLocation();
    const float HalfHeight = GetCapsuleComponent()->GetScaledCapsuleHalfHeight();
    const FVector End = TargetFloor + FVector(0.f, 0.f, HalfHeight);
    if (FVector::Dist2D(Start, End) > MaximumDistance || FMath::Abs(Start.Z - End.Z) > 45.f)
    {
        return false;
    }

    FCollisionQueryParams Params(SCENE_QUERY_STAT(BWSpiderAttack), false, this);
    Params.AddIgnoredActor(TargetPlayer.Get());
    FHitResult Hit;
    if (GetWorld()->LineTraceSingleByChannel(Hit, Start, End, ECC_Visibility, Params))
    {
        return false;
    }

    // A body-width sweep catches door jambs/obstacles missed by the centre ray. Shrink slightly to avoid floor contact.
    const float Radius = FMath::Max(5.f, GetCapsuleComponent()->GetScaledCapsuleRadius() - 3.f);
    const FCollisionShape Shape = FCollisionShape::MakeCapsule(Radius, FMath::Max(Radius, HalfHeight - 3.f));
    return !GetWorld()->SweepSingleByChannel(Hit, Start, End, FQuat::Identity, ECC_Pawn, Shape, Params);
}

void ABWSpiderEncounter::StopLocomotion()
{
    if (AAIController* AI = Cast<AAIController>(GetController()))
    {
        AI->StopMovement();
        AI->ClearFocus(EAIFocusPriority::Gameplay);
    }
    GetCharacterMovement()->StopMovementImmediately();
}

void ABWSpiderEncounter::ResolveAtExit()
{
    if (EncounterState == EBWSpiderState::Dormant || EncounterState == EBWSpiderState::Resolved || bResolutionPending)
    {
        return;
    }
    bResolutionPending = true;
    GetWorldTimerManager().ClearTimer(ThinkTimer);
    EnterState(EBWSpiderState::Cooldown);
    if (ExitResolutionDelay <= 0.f)
    {
        FinishResolution();
    }
    else
    {
        GetWorldTimerManager().SetTimer(ResolveTimer, this, &ABWSpiderEncounter::FinishResolution, ExitResolutionDelay, false);
    }
}

void ABWSpiderEncounter::FinishResolution()
{
    ABWIntroDirector* Director = IntroDirector;
    DeactivateEncounter();
    EnterState(EBWSpiderState::Resolved);
    if (IsValid(Director) && Director->Stage == EBWIntroStage::Encounter)
    {
        Director->ResolveEncounter();
    }
}

void ABWSpiderEncounter::UpdateAnimation()
{
    USkeletalMeshComponent* Mesh = GetMesh();
    if (!Mesh->GetSkeletalMeshAsset())
    {
        return;
    }

    const float Speed = GetVelocity().Size2D();
    const bool bRun = Speed > StalkSpeed * 1.25f && RunAnimation;
    UAnimSequence* Clip = Speed < 5.f ? IdleAnimation.Get() : (bRun ? RunAnimation.Get() : WalkAnimation.Get());
    if (!Clip)
    {
        Clip = IdleAnimation;
    }
    // Never apply a recovered clip to an unrelated skeleton.
    if (!Clip || Clip->GetSkeleton() != Mesh->GetSkeletalMeshAsset()->GetSkeleton())
    {
        if (UAnimSingleNodeInstance* Instance = Mesh->GetSingleNodeInstance())
        {
            Instance->SetPlaying(false);
        }
        return;
    }
    if (PlayingAnimation.Get() != Clip)
    {
        Mesh->PlayAnimation(Clip, true);
        PlayingAnimation = Clip;
        if (UAnimInstance* Instance = Mesh->GetAnimInstance())
        {
            Instance->SetRootMotionMode(ERootMotionMode::IgnoreRootMotion);
        }
    }
    if (UAnimSingleNodeInstance* Instance = Mesh->GetSingleNodeInstance())
    {
        Instance->SetPlaying(true);
        const float ReferenceSpeed = bRun ? RunReferenceSpeed : WalkReferenceSpeed;
        Instance->SetPlayRate(Speed < 5.f ? 1.f : FMath::Clamp(Speed / FMath::Max(ReferenceSpeed, 1.f), 0.35f, 1.65f));
    }
}
