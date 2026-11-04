#pragma once
#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "TimerManager.h"
#include "BWPlayerCharacter.generated.h"

class USpringArmComponent;
class UCameraComponent;
class USpotLightComponent;
class ABWIntroDirector;
class ABWInteractable;

UCLASS(Blueprintable)
class BLACKWEB_API ABWPlayerCharacter : public ACharacter
{
    GENERATED_BODY()
public:
    ABWPlayerCharacter();
    virtual void BeginPlay() override;
    virtual void EndPlay(const EEndPlayReason::Type Reason) override;
    virtual void Tick(float DeltaSeconds) override;
    virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
    virtual float TakeDamage(float DamageAmount, const FDamageEvent& DamageEvent, AController* EventInstigator, AActor* DamageCauser) override;
    UFUNCTION(BlueprintCallable) void ToggleFlashlight();
    UFUNCTION(BlueprintCallable) void ResetAfterCheckpoint(AActor* Anchor);
    UFUNCTION(BlueprintPure) FText GetFocusPrompt() const;
    UFUNCTION(BlueprintPure) ABWIntroDirector* GetIntroDirector() const;
    UFUNCTION(BlueprintPure) bool CanMove() const;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) USpringArmComponent* CameraBoom;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) UCameraComponent* FollowCamera;
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly) USpotLightComponent* Flashlight;
    UPROPERTY(BlueprintReadOnly) bool bFlashlightOn = false;
    UPROPERTY(BlueprintReadOnly, Category="Survival") float Health = 100.0f;
    UPROPERTY(BlueprintReadOnly, Category="Survival") bool bIsRecovering = false;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Survival", meta=(ClampMin="1.0")) float MaximumHealth = 100.0f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Survival", meta=(ClampMin="0.1", ClampMax="1.0")) float HitSpeedMultiplier = 0.55f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Survival", meta=(ClampMin="0.0", ClampMax="3.0")) float HitSlowdownSeconds = 0.65f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Survival", meta=(ClampMin="0.1", ClampMax="5.0")) float DefeatRecoveryDelay = 1.1f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Movement", meta=(ClampMin="50.0")) float WalkSpeed = 190.0f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Movement", meta=(ClampMin="50.0")) float RunSpeed = 300.0f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Interaction", meta=(ClampMin="50.0", ClampMax="300.0")) float InteractionReach = 210.0f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Camera") float MouseSensitivity = 0.7f;
    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Camera") float GamepadTurnRate = 80.0f;

private:
    TWeakObjectPtr<ABWIntroDirector> Intro;
    TWeakObjectPtr<ABWInteractable> Focus;
    FTransform InitialTransform;
    bool bHasInitialTransform = false;
    bool bPreviouslyHadFlashlight = false;
    bool bRunning = false;
    float HitSlowdownRemaining = 0.0f;
    FTimerHandle DefeatRecoveryTimer;
    void MoveForward(float Value);
    void MoveRight(float Value);
    void Turn(float Value);
    void LookUp(float Value);
    void TurnRate(float Value);
    void LookUpRate(float Value);
    void StartRunning();
    void StopRunning();
    void Interact();
    void RetryCheckpoint();
    void ReplayOpening();
    void FinishDefeatRecovery();
    void UpdateFocus();
};
