#include "BWPlayerCharacter.h"
#include "BWInteractable.h"
#include "BWIntroDirector.h"
#include "Camera/CameraComponent.h"
#include "Camera/PlayerCameraManager.h"
#include "Components/CapsuleComponent.h"
#include "Components/InputComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/SpotLightComponent.h"
#include "Engine/World.h"
#include "Engine/DamageEvents.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "GameFramework/PlayerController.h"
#include "GameFramework/SpringArmComponent.h"

#define LOCTEXT_NAMESPACE "BlackwebPlayer"
ABWPlayerCharacter::ABWPlayerCharacter()
{
    PrimaryActorTick.bCanEverTick = true;
    GetCapsuleComponent()->InitCapsuleSize(32.0f, 88.0f);
    GetMesh()->SetRelativeLocation(FVector(0.0f, 0.0f, -88.0f));
    GetMesh()->SetRelativeRotation(FRotator(0.0f, -90.0f, 0.0f));
    GetMesh()->SetCollisionEnabled(ECollisionEnabled::NoCollision);
    bUseControllerRotationPitch = false;
    bUseControllerRotationYaw = false;
    bUseControllerRotationRoll = false;
    GetCharacterMovement()->bOrientRotationToMovement = true;
    GetCharacterMovement()->RotationRate = FRotator(0.0f, 420.0f, 0.0f);
    GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;
    GetCharacterMovement()->MaxAcceleration = 700.0f;
    GetCharacterMovement()->BrakingDecelerationWalking = 900.0f;
    GetCharacterMovement()->MaxStepHeight = 35.0f;

    CameraBoom = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraBoom"));
    CameraBoom->SetupAttachment(RootComponent);
    CameraBoom->TargetArmLength = 245.0f;
    CameraBoom->TargetOffset = FVector(0.0f, 0.0f, 52.0f);
    CameraBoom->SocketOffset = FVector(0.0f, 42.0f, 0.0f);
    CameraBoom->bUsePawnControlRotation = true;
    CameraBoom->bDoCollisionTest = true;
    CameraBoom->ProbeSize = 12.0f;
    CameraBoom->ProbeChannel = ECC_Camera;
    CameraBoom->bEnableCameraLag = true;
    CameraBoom->CameraLagSpeed = 12.0f;
    CameraBoom->CameraLagMaxDistance = 25.0f;
    CameraBoom->bUseCameraLagSubstepping = true;
    FollowCamera = CreateDefaultSubobject<UCameraComponent>(TEXT("FollowCamera"));
    FollowCamera->SetupAttachment(CameraBoom, USpringArmComponent::SocketName);
    FollowCamera->bUsePawnControlRotation = false;
    FollowCamera->SetFieldOfView(78.0f);
    Flashlight = CreateDefaultSubobject<USpotLightComponent>(TEXT("Flashlight"));
    Flashlight->SetupAttachment(FollowCamera);
    Flashlight->SetRelativeLocation(FVector(20.0f, 10.0f, -12.0f));
    Flashlight->IntensityUnits = ELightUnits::Lumens;
    Flashlight->SetIntensity(2200.0f);
    Flashlight->SetAttenuationRadius(1600.0f);
    Flashlight->SetInnerConeAngle(16.0f);
    Flashlight->SetOuterConeAngle(27.0f);
    Flashlight->SetLightColor(FLinearColor(1.0f, 0.92f, 0.82f));
    Flashlight->SetCastShadows(true);
    Flashlight->SetVisibility(false);
}

void ABWPlayerCharacter::BeginPlay()
{
    Super::BeginPlay();
    InitialTransform = GetActorTransform();
    bHasInitialTransform = true;
    Health = FMath::Max(1.0f, MaximumHealth);
    Intro = ABWIntroDirector::FindDirector(this);
    if (APlayerController* PC = Cast<APlayerController>(Controller))
    {
        if (PC->PlayerCameraManager)
        {
            PC->PlayerCameraManager->ViewPitchMin = -65.0f;
            PC->PlayerCameraManager->ViewPitchMax = 60.0f;
        }
    }
}

void ABWPlayerCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);
    if (!Intro.IsValid()) Intro = ABWIntroDirector::FindDirector(this);
    const bool bOwnsLight = Intro.IsValid() && Intro->bHasFlashlight;
    if (bOwnsLight && !bPreviouslyHadFlashlight) bFlashlightOn = true;
    if (!bOwnsLight) bFlashlightOn = false;
    bPreviouslyHadFlashlight = bOwnsLight;
    Flashlight->SetVisibility(bFlashlightOn && bOwnsLight);
    HitSlowdownRemaining = FMath::Max(0.0f, HitSlowdownRemaining - DeltaSeconds);
    const float HitScale = HitSlowdownRemaining > 0.0f ? FMath::Clamp(HitSpeedMultiplier, 0.1f, 1.0f) : 1.0f;
    GetCharacterMovement()->MaxWalkSpeed = (bRunning ? RunSpeed : WalkSpeed) * HitScale;
    if (!CanMove()) GetCharacterMovement()->StopMovementImmediately();
    UpdateFocus();
}

void ABWPlayerCharacter::SetupPlayerInputComponent(UInputComponent* Input)
{
    Super::SetupPlayerInputComponent(Input);
    Input->BindAxis("MoveForward", this, &ABWPlayerCharacter::MoveForward);
    Input->BindAxis("MoveRight", this, &ABWPlayerCharacter::MoveRight);
    Input->BindAxis("Turn", this, &ABWPlayerCharacter::Turn);
    Input->BindAxis("LookUp", this, &ABWPlayerCharacter::LookUp);
    Input->BindAxis("TurnRate", this, &ABWPlayerCharacter::TurnRate);
    Input->BindAxis("LookUpRate", this, &ABWPlayerCharacter::LookUpRate);
    Input->BindAction("Interact", IE_Pressed, this, &ABWPlayerCharacter::Interact);
    Input->BindAction("Flashlight", IE_Pressed, this, &ABWPlayerCharacter::ToggleFlashlight);
    Input->BindAction("Sprint", IE_Pressed, this, &ABWPlayerCharacter::StartRunning);
    Input->BindAction("Sprint", IE_Released, this, &ABWPlayerCharacter::StopRunning);
    Input->BindAction("RetryCheckpoint", IE_Pressed, this, &ABWPlayerCharacter::RetryCheckpoint);
    Input->BindAction("ReplayOpening", IE_Pressed, this, &ABWPlayerCharacter::ReplayOpening);
}

ABWIntroDirector* ABWPlayerCharacter::GetIntroDirector() const { return Intro.Get(); }
bool ABWPlayerCharacter::CanMove() const { return !bIsRecovering && (!Intro.IsValid() || Intro->Stage != EBWIntroStage::Complete); }
void ABWPlayerCharacter::MoveForward(float Value)
{
    if (Controller && CanMove()) AddMovementInput(FRotationMatrix(FRotator(0.0f, Controller->GetControlRotation().Yaw, 0.0f)).GetUnitAxis(EAxis::X), Value);
}
void ABWPlayerCharacter::MoveRight(float Value)
{
    if (Controller && CanMove()) AddMovementInput(FRotationMatrix(FRotator(0.0f, Controller->GetControlRotation().Yaw, 0.0f)).GetUnitAxis(EAxis::Y), Value);
}
void ABWPlayerCharacter::Turn(float Value) { if (CanMove()) AddControllerYawInput(Value * MouseSensitivity); }
void ABWPlayerCharacter::LookUp(float Value) { if (CanMove()) AddControllerPitchInput(Value * MouseSensitivity); }
void ABWPlayerCharacter::TurnRate(float Value) { if (CanMove()) AddControllerYawInput(Value * GamepadTurnRate * GetWorld()->GetDeltaSeconds()); }
void ABWPlayerCharacter::LookUpRate(float Value) { if (CanMove()) AddControllerPitchInput(Value * GamepadTurnRate * GetWorld()->GetDeltaSeconds()); }
void ABWPlayerCharacter::StartRunning() { if (CanMove()) bRunning = true; }
void ABWPlayerCharacter::StopRunning() { bRunning = false; }

void ABWPlayerCharacter::UpdateFocus()
{
    Focus.Reset();
    if (!IsLocallyControlled() || !CanMove()) return;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlackwebFocus), false, this);
    FHitResult CameraHit;
    const FVector CameraStart = FollowCamera->GetComponentLocation();
    const FVector CameraEnd = CameraStart + FollowCamera->GetForwardVector() * (CameraBoom->TargetArmLength + InteractionReach + 80.0f);
    if (!GetWorld()->LineTraceSingleByChannel(CameraHit, CameraStart, CameraEnd, ECC_Visibility, Params)) return;
    ABWInteractable* Candidate = Cast<ABWInteractable>(CameraHit.GetActor());
    if (!Candidate || Candidate->IsHidden()) return;
    const FVector ReachTarget = Candidate->GetInteractionLocation();
    const FVector ReachStart = GetActorLocation() + FVector(0.0f, 0.0f, 35.0f);
    if (FVector::DistSquared(ReachStart, ReachTarget) > FMath::Square(InteractionReach)) return;
    // Camera visibility alone is insufficient: the protagonist must also have line of sight.
    FHitResult ReachHit;
    if (GetWorld()->LineTraceSingleByChannel(ReachHit, ReachStart, ReachTarget, ECC_Visibility, Params) && ReachHit.GetActor() != Candidate) return;
    Focus = Candidate;
}

FText ABWPlayerCharacter::GetFocusPrompt() const
{
    if (!Focus.IsValid() || !Intro.IsValid()) return FText::GetEmpty();
    if (Intro->CanInteract(Focus->Kind)) return FText::Format(LOCTEXT("UsePrompt", "E  ·  {0}"), Focus->GetPrompt());
    return Intro->GetInteractionHint(Focus->Kind);
}

void ABWPlayerCharacter::Interact()
{
    UpdateFocus();
    if (Focus.IsValid() && Intro.IsValid()) Focus->Use(Intro.Get());
}

void ABWPlayerCharacter::ToggleFlashlight()
{
    if (Intro.IsValid() && Intro->bHasFlashlight && CanMove()) bFlashlightOn = !bFlashlightOn;
}

void ABWPlayerCharacter::RetryCheckpoint()
{
    if (bIsRecovering) return;
    if (Intro.IsValid())
    {
        if (Intro->ReloadCheckpoint()) Intro->ShowNotice(LOCTEXT("Retry", "Checkpoint restored."));
        else
        {
            Intro->RetryCurrentMilestone();
            if (!Intro->bSaveWritesBlocked) Intro->ShowNotice(LOCTEXT("NoCheckpoint", "No saved checkpoint is available. Returned to the starting position."));
        }
    }
}

void ABWPlayerCharacter::ResetAfterCheckpoint(AActor* Anchor)
{
    GetWorldTimerManager().ClearTimer(DefeatRecoveryTimer);
    Health = FMath::Max(1.0f, MaximumHealth);
    bIsRecovering = false;
    HitSlowdownRemaining = 0.0f;
    GetCharacterMovement()->StopMovementImmediately();
    bRunning = false;
    const FTransform Transform = IsValid(Anchor) ? Anchor->GetActorTransform() : (bHasInitialTransform ? InitialTransform : GetActorTransform());
    TeleportTo(Transform.GetLocation(), Transform.Rotator(), false, false);
    if (Controller) Controller->SetControlRotation(Transform.Rotator());
    bPreviouslyHadFlashlight = false;
    Focus.Reset();
}

void ABWPlayerCharacter::ReplayOpening()
{
    if (Intro.IsValid() && Intro->Stage == EBWIntroStage::Complete) Intro->RestartOpening();
}

float ABWPlayerCharacter::TakeDamage(float DamageAmount, const FDamageEvent& DamageEvent, AController* EventInstigator, AActor* DamageCauser)
{
    if (!CanMove() || !FMath::IsFinite(DamageAmount) || DamageAmount <= 0.0f) return 0.0f;
    const float Applied = FMath::Clamp(Super::TakeDamage(DamageAmount, DamageEvent, EventInstigator, DamageCauser), 0.0f, Health);
    if (Applied <= 0.0f) return 0.0f;
    Health = FMath::Max(0.0f, Health - Applied);
    HitSlowdownRemaining = FMath::Clamp(HitSlowdownSeconds, 0.0f, 3.0f);
    if (Health > 0.0f)
    {
        if (Intro.IsValid()) Intro->ShowNotice(LOCTEXT("Hurt", "Hurt. Keep your distance."), 2.0f);
    }
    else
    {
        bIsRecovering = true;
        bRunning = false;
        Focus.Reset();
        GetCharacterMovement()->StopMovementImmediately();
        if (Intro.IsValid()) Intro->ShowNotice(LOCTEXT("Defeated", "Luke is down. Returning to the checkpoint..."), FMath::Max(1.0f, DefeatRecoveryDelay));
        GetWorldTimerManager().SetTimer(DefeatRecoveryTimer, this, &ABWPlayerCharacter::FinishDefeatRecovery,
            FMath::Clamp(DefeatRecoveryDelay, 0.1f, 5.0f), false);
    }
    return Applied;
}

void ABWPlayerCharacter::FinishDefeatRecovery()
{
    if (!bIsRecovering) return;
    if (Intro.IsValid())
    {
        // A failed disk read must not strand a defeated player or overwrite an unknown save.
        if (!Intro->ReloadCheckpoint()) Intro->RetryCurrentMilestone();
        Intro->ShowNotice(LOCTEXT("Recovered", "Checkpoint restored. Give it room before moving past."), 3.0f);
    }
    else ResetAfterCheckpoint(nullptr);
}

void ABWPlayerCharacter::EndPlay(const EEndPlayReason::Type Reason)
{
    GetWorldTimerManager().ClearTimer(DefeatRecoveryTimer);
    Super::EndPlay(Reason);
}
#undef LOCTEXT_NAMESPACE
