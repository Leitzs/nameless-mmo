#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "Core/RPGTypes.h"
#include "RPGCharacterBase.generated.h"

class UAnimSequenceBase;
class UMaterialInstanceDynamic;
class UMaterialInterface;
class URPGAttributeComponent;
class URPGStatusEffectComponent;
class UStaticMeshComponent;

/**
 * Shared base for every combatant (player mage and enemy bots): attributes, status effects, team,
 * damage handling, death, status visuals (overlay glows, shield bubble) and simple cosmetic attachments.
 */
UCLASS(Abstract)
class RPGTEST_API ARPGCharacterBase : public ACharacter
{
	GENERATED_BODY()

public:
	ARPGCharacterBase();

	virtual void Tick(float DeltaSeconds) override;
	virtual void OnConstruction(const FTransform& Transform) override;
	virtual float TakeDamage(float DamageAmount, struct FDamageEvent const& DamageEvent, AController* EventInstigator, AActor* DamageCauser) override;

	UFUNCTION(BlueprintPure, Category = "RPG")
	ERPGTeam GetTeam() const { return Team; }

	UFUNCTION(BlueprintPure, Category = "RPG")
	bool IsHostileTo(const AActor* Other) const;

	UFUNCTION(BlueprintPure, Category = "RPG")
	bool IsAlive() const;

	/** Frozen or stunned. */
	UFUNCTION(BlueprintPure, Category = "RPG")
	bool IsIncapacitated() const;

	/** Alive and able to move, cast or attack. */
	UFUNCTION(BlueprintPure, Category = "RPG")
	bool CanAct() const { return IsAlive() && !IsIncapacitated(); }

	const FText& GetCharacterName() const { return CharacterName; }
	URPGAttributeComponent* GetAttributes() const { return Attributes; }
	URPGStatusEffectComponent* GetStatusEffects() const { return StatusEffects; }

	/** Point other characters aim at (upper chest). */
	FVector GetTargetPoint() const;

	/** Where spells and projectiles leave the character. */
	virtual FVector GetSpellOrigin() const;

	/**
	 * Resolves what the character is aiming at within MaxRange.
	 * OutTarget is a soft-locked hostile character, or null when aiming at the world.
	 */
	virtual void ComputeAim(float MaxRange, FVector& OutAimLocation, ARPGCharacterBase*& OutTarget) const;

	/** Plays an animation on the anim blueprint's DefaultSlot. Returns its duration in seconds, 0 if it did not play. */
	float PlayActionAnimation(UAnimSequenceBase* Animation, float PlayRate = 1.f);
	void StopActionAnimation(float BlendOutTime = 0.2f);

	/** Turns towards a location, either immediately or smoothly over the next frames. */
	void FaceLocation(const FVector& Location, bool bInstant);

	/** Makes the character glow red for Duration seconds (attack wind-up warning). */
	void SetTelegraphGlow(float Duration) { TelegraphRemaining = Duration; }

	/** Pushes the character away. Ignored while dead. */
	void ApplyKnockback(const FVector& Direction, float Strength, float UpStrength);

protected:
	virtual void BeginPlay() override;

	/** Called once when health reaches zero. */
	virtual void HandleDeath(AActor* Killer);

	/** Called after health or shield absorbed damage. */
	virtual void OnDamageTaken(float HealthDamage, float AbsorbedDamage, AActor* InstigatorActor) {}

	/** Movement speed before status effects are applied. */
	virtual float GetDesiredMoveSpeed() const { return BaseMoveSpeed; }

	/** Creates a collision-less static mesh attached to a bone. Constructor only. */
	UStaticMeshComponent* CreateCosmeticPart(FName Name, UStaticMesh* PartMesh, FName Bone);

	/**
	 * Places a cosmetic part relative to a bone so that, in the current pose, it sits at Offset from the bone
	 * (in actor space) with the given actor-space rotation. Called from AlignCosmetics while the mesh is idle.
	 */
	void AlignCosmeticPart(UStaticMeshComponent* Part, FName Bone, const FVector& Offset, const FRotator& Rotation, const FVector& Scale) const;

	/** Positions cosmetic parts. Runs shortly after BeginPlay, once the idle pose has been evaluated. */
	virtual void AlignCosmetics() {}

	/** Applies materials and colors to cosmetic parts. Runs in the editor and in game. */
	virtual void ApplyCosmeticMaterials();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<URPGAttributeComponent> Attributes;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<URPGStatusEffectComponent> StatusEffects;

	/** Translucent sphere shown while a damage shield is active. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> ShieldBubble;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "RPG")
	ERPGTeam Team = ERPGTeam::Neutral;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "RPG")
	FText CharacterName;

	/** Value for the mannequin material's "Paint Tint" parameter. Alpha 0 keeps the original material. */
	UPROPERTY(EditAnywhere, Category = "RPG|Look")
	FLinearColor BodyTint = FLinearColor(1.f, 1.f, 1.f, 0.f);

	UPROPERTY(EditAnywhere, Category = "RPG|Movement", meta = (ClampMin = "0"))
	float BaseMoveSpeed = 500.f;

	/** One is picked at random on death; the final frame is held. */
	UPROPERTY(EditDefaultsOnly, Category = "RPG|Animation")
	TArray<TObjectPtr<UAnimSequenceBase>> DeathAnimations;

	/** Seconds the body stays after death. 0 keeps it until something else removes it. */
	UPROPERTY(EditDefaultsOnly, Category = "RPG")
	float CorpseLifeSpan = 0.f;

	/** Component tag marking parts created by CreateCosmeticPart. */
	static const FName CosmeticTag;

private:
	UFUNCTION()
	void HandleAttributesDamaged(URPGAttributeComponent* InAttributes, float HealthDamage, float AbsorbedDamage, AActor* InstigatorActor);

	UFUNCTION()
	void HandleAttributesDeath(AActor* Killer);

	UFUNCTION()
	void HandleStatusChanged();

	void SetCosmeticsVisible(bool bVisible);
	void RunCosmeticAlignment();
	void ApplyBodyTint();
	void CreateStatusMaterials();
	void UpdateStatusVisuals(float DeltaSeconds);
	void UpdateMovementSpeed();
	void UpdateFacing(float DeltaSeconds);

	bool bDeathHandled = false;
	bool bHasDesiredFacing = false;
	FRotator DesiredFacing = FRotator::ZeroRotator;
	float HitFlashRemaining = 0.f;
	float TelegraphRemaining = 0.f;
	FTimerHandle CosmeticAlignTimer;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> FrozenOverlay;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> BurningOverlay;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> ShieldOverlay;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> HitOverlay;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> TelegraphOverlay;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> ShieldBubbleMaterial;
};
