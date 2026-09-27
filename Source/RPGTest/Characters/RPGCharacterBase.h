#pragma once

#include "CoreMinimal.h"
#include "AbilitySystemInterface.h"
#include "GameFramework/Character.h"
#include "GameplayTagContainer.h"
#include "Core/RPGTypes.h"
#include "RPGCharacterBase.generated.h"

class UAnimSequenceBase;
class UMaterialInstanceDynamic;
class UMaterialInterface;
class URPGAbilitySystemComponent;
class URPGAttributeSet;
class URPGGameplayAbility;
class UStaticMesh;
class UStaticMeshComponent;

/** Primitive shape used by data-driven cosmetic parts (see FRPGCosmeticPart). */
UENUM()
enum class ERPGPartShape : uint8
{
	Cube,
	Sphere,
	Cylinder,
	Cone
};

/**
 * One cosmetic piece (hat, weapon, shield...) made from a primitive shape, placed relative to a bone in the idle
 * pose. Classes list them in their constructor with AddCosmeticPart; the base class creates, places and paints them.
 */
USTRUCT()
struct FRPGCosmeticPart
{
	GENERATED_BODY()

	FName Name;
	ERPGPartShape Shape = ERPGPartShape::Cube;
	FName Bone;
	/** Actor-space offset from the bone in the idle pose. */
	FVector Offset = FVector::ZeroVector;
	/** Actor-space rotation (the primitive's Z axis is its length). */
	FRotator Rotation = FRotator::ZeroRotator;
	/** Scale of the 100-unit primitive. */
	FVector Scale = FVector(0.1f);
	FLinearColor Color = FLinearColor::Gray;
	float Roughness = 0.6f;
	float Emissive = 0.f;
};

/**
 * Shared base for every combatant (player characters and enemy bots): the Gameplay Ability System component and
 * attributes, team, class stats, death, status visuals (overlays, shield bubble, stealth, fear) and simple cosmetic
 * attachments.
 *
 * Networking: the server owns all gameplay state (damage, death, statuses). Clients learn about it through the
 * replicated ability system (attributes, status tags), the replicated death state and unreliable multicasts for
 * cosmetic events (hit numbers, action animations, attack telegraphs).
 */
UCLASS(Abstract)
class RPGTEST_API ARPGCharacterBase : public ACharacter, public IAbilitySystemInterface
{
	GENERATED_BODY()

public:
	explicit ARPGCharacterBase(const FObjectInitializer& ObjectInitializer);

	virtual void Tick(float DeltaSeconds) override;
	virtual void OnConstruction(const FTransform& Transform) override;
	virtual void GetLifetimeReplicatedProps(TArray<FLifetimeProperty>& OutLifetimeProps) const override;
	virtual void PossessedBy(AController* NewController) override;
	virtual void OnRep_Controller() override;

	// IAbilitySystemInterface
	virtual UAbilitySystemComponent* GetAbilitySystemComponent() const override;
	URPGAbilitySystemComponent* GetRPGAbilitySystem() const { return AbilitySystem; }
	const URPGAttributeSet* GetAttributeSet() const { return AttributeSet; }

	UFUNCTION(BlueprintPure, Category = "RPG")
	ERPGTeam GetTeam() const { return Team; }

	/** Name shown over the character and in the crosshair: the player's name for player characters, the class name otherwise. */
	FString GetCombatName() const;

	/** Current maximum ground speed: class speed, statuses and death applied. Read by the movement component. */
	float GetMoveSpeed() const;

	UFUNCTION(BlueprintPure, Category = "RPG")
	bool IsHostileTo(const AActor* Other) const;

	UFUNCTION(BlueprintPure, Category = "RPG")
	bool IsAlive() const;

	/** Stunned, frozen or feared: cannot act. */
	UFUNCTION(BlueprintPure, Category = "RPG")
	bool IsIncapacitated() const;

	/** Alive and able to move, cast or attack. */
	UFUNCTION(BlueprintPure, Category = "RPG")
	bool CanAct() const { return IsAlive() && !IsIncapacitated(); }

	bool HasStatus(const FGameplayTag& Status) const;
	bool IsStealthed() const;

	/** Whether Viewer can see (and target) this character: stealth hides it from enemies beyond StealthRevealDistance. */
	bool IsVisibleTo(const AActor* Viewer) const;

	float GetHealth() const;
	float GetMaxHealth() const;
	float GetResource() const;
	float GetMaxResource() const;
	float GetShield() const;
	const FRPGResourceConfig& GetResourceConfig() const { return ResourceConfig; }

	const FText& GetCharacterName() const { return CharacterName; }

	/** Point other characters aim at (upper chest). */
	FVector GetTargetPoint() const;

	/** Where spells and projectiles leave the character. */
	virtual FVector GetSpellOrigin() const;

	/**
	 * Resolves what the character is aiming at within MaxRange.
	 * OutTarget is a soft-locked hostile character, or null when aiming at the world.
	 */
	virtual void ComputeAim(float MaxRange, FVector& OutAimLocation, ARPGCharacterBase*& OutTarget) const;

	/** Plays an animation on the anim blueprint's DefaultSlot on this machine only. Returns its duration in seconds, 0 if it did not play. */
	float PlayActionAnimation(UAnimSequenceBase* Animation, float PlayRate = 1.f);
	void StopActionAnimation(float BlendOutTime = 0.2f);

	/**
	 * Plays an action animation everywhere: locally when this machine controls the character (no wait for the server),
	 * and on every other machine through a multicast when called on the server.
	 */
	void PlayActionAnimationForAll(UAnimSequenceBase* Animation, float PlayRate = 1.f);
	void StopActionAnimationForAll(float BlendOutTime = 0.2f);

	/** Turns towards a location, either immediately or smoothly over the next frames. */
	void FaceLocation(const FVector& Location, bool bInstant);

	/** Makes the character glow red for Duration seconds (attack wind-up warning). Replicated when called on the server. */
	void SetTelegraphGlow(float Duration);

	/** Pushes the character away. Ignored while dead. */
	void ApplyKnockback(const FVector& Direction, float Strength, float UpStrength);

	/** Server: floating text over the character on every machine ("IMMUNE", "BEHIND!"). */
	void ShowCombatText(const FText& Text, const FLinearColor& Color);

	// Called by URPGAbilitySystemComponent.
	/** Server: health or shield absorbed damage. */
	void NotifyDamageTaken(float HealthDamage, float AbsorbedDamage, AActor* InstigatorActor, const FGameplayTag& DamageType);
	/** Server: health was restored. */
	void NotifyHealed(float Amount);
	/** Server: health reached zero. */
	void NotifyKilled(AActor* Killer);
	/** Any machine: stun/freeze/fear started or ended. */
	void OnIncapacitatedChanged(bool bIncapacitated);

	/** Enemies closer than this see a stealthed character (as a shimmer). */
	static constexpr float StealthRevealDistance = 350.f;

protected:
	virtual void BeginPlay() override;

	/** Called once when health reaches zero, on the server and on every client. Killer is only known on the server. */
	virtual void HandleDeath(AActor* Killer);

	/** Called on the server after health or shield absorbed damage. */
	virtual void OnDamageTaken(float HealthDamage, float AbsorbedDamage, AActor* InstigatorActor) {}

	/** Movement speed before statuses are applied. */
	virtual float GetDesiredMoveSpeed() const { return BaseMoveSpeed; }

	/** Constructor helper: class stats. */
	void SetClassStats(float InMaxHealth, float InHealthRegen, const FRPGResourceConfig& InResource);

	/** Creates a collision-less static mesh attached to a bone. Constructor only. */
	UStaticMeshComponent* CreateCosmeticPart(FName Name, UStaticMesh* PartMesh, FName Bone);

	/** Constructor only: adds a data-driven cosmetic part (created, aligned and painted by this class). */
	UStaticMeshComponent* AddCosmeticPart(const FRPGCosmeticPart& Part);

	/**
	 * Constructor only: a bladed weapon (grip, guard, blade) held in Bone and pointing along the actor-space Direction.
	 * Swords, daggers and axes of any size.
	 */
	void AddBladeParts(const FString& Prefix, FName Bone, const FVector& Direction, float BladeLength, float BladeWidth, const FLinearColor& BladeColor, const FLinearColor& HiltColor);

	/**
	 * Places a cosmetic part relative to a bone so that, in the current pose, it sits at Offset from the bone
	 * (in actor space) with the given actor-space rotation. Called from AlignCosmetics while the mesh is idle.
	 */
	void AlignCosmeticPart(UStaticMeshComponent* Part, FName Bone, const FVector& Offset, const FRotator& Rotation, const FVector& Scale) const;

	/** Positions cosmetic parts. Runs shortly after BeginPlay, once the idle pose has been evaluated. */
	virtual void AlignCosmetics();

	/** Applies materials and colors to cosmetic parts. Runs in the editor and in game. */
	virtual void ApplyCosmeticMaterials();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<URPGAbilitySystemComponent> AbilitySystem;

	UPROPERTY()
	TObjectPtr<URPGAttributeSet> AttributeSet;

	/** Translucent sphere shown while a damage shield is active. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Components")
	TObjectPtr<UStaticMeshComponent> ShieldBubble;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "RPG")
	ERPGTeam Team = ERPGTeam::Neutral;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "RPG")
	FText CharacterName;

	UPROPERTY(EditAnywhere, Category = "RPG|Stats", meta = (ClampMin = "1"))
	float MaxHealth = 300.f;

	/** Health regained per second while out of combat. */
	UPROPERTY(EditAnywhere, Category = "RPG|Stats", meta = (ClampMin = "0"))
	float HealthRegen = 3.f;

	UPROPERTY(EditAnywhere, Category = "RPG|Stats")
	FRPGResourceConfig ResourceConfig;

	/** Abilities by hotbar slot: 0 is the basic attack (left mouse), 1-5 the number keys. Granted by the server. */
	UPROPERTY(EditDefaultsOnly, Category = "RPG|Abilities")
	TArray<TSubclassOf<URPGGameplayAbility>> AbilityClasses;

	/** Permanent traits of the class (e.g. Trait.FrontalBlock), added as loose tags on every machine. */
	UPROPERTY(EditDefaultsOnly, Category = "RPG|Abilities", meta = (Categories = "Trait"))
	FGameplayTagContainer PassiveTags;

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
	void OnRep_DeathPose();

	/** Floating damage numbers and hit flash on every machine. */
	UFUNCTION(NetMulticast, Unreliable)
	void MulticastDamageFeedback(float HealthDamage, float AbsorbedDamage, FGameplayTag DamageType);

	UFUNCTION(NetMulticast, Unreliable)
	void MulticastHealFeedback(float Amount);

	UFUNCTION(NetMulticast, Unreliable)
	void MulticastCombatText(const FText& Text, FLinearColor Color);

	UFUNCTION(NetMulticast, Unreliable)
	void MulticastPlayActionAnimation(UAnimSequenceBase* Animation, float PlayRate);

	UFUNCTION(NetMulticast, Unreliable)
	void MulticastStopActionAnimation(float BlendOutTime);

	UFUNCTION(NetMulticast, Unreliable)
	void MulticastTelegraphGlow(float Duration);

	/** Sets up the ability system's actor info, class stats, traits and (server) abilities. */
	void InitAbilitySystem();

	/** Runs the death presentation once (collision, animation, visuals) on whichever machine this is. */
	void ApplyDeath(AActor* Killer);

	void SetCosmeticsVisible(bool bVisible);
	void RunCosmeticAlignment();
	void ApplyBodyTint();
	void CreateStatusMaterials();
	void UpdateStatusVisuals(float DeltaSeconds);
	void UpdateStealthVisibility();
	void UpdateFacing(float DeltaSeconds);
	void UpdateFearMovement(float DeltaSeconds);

	/** 0 while alive; after death, 1 + the index of the death animation that plays. Replicated so clients play the same one. */
	UPROPERTY(ReplicatedUsing = OnRep_DeathPose)
	uint8 DeathPose = 0;

	/** Parts declared with AddCosmeticPart, aligned and painted automatically. */
	TArray<FRPGCosmeticPart> CosmeticPartSpecs;

	UPROPERTY(Transient)
	TArray<TObjectPtr<UStaticMeshComponent>> CosmeticPartComponents;

	bool bDeathHandled = false;
	bool bAbilitySystemInitialized = false;
	bool bHasDesiredFacing = false;
	bool bHiddenByStealth = false;
	bool bFeared = false;
	FRotator DesiredFacing = FRotator::ZeroRotator;
	FVector FearDirection = FVector::ForwardVector;
	float FearTurnTimer = 0.f;
	float HitFlashRemaining = 0.f;
	float TelegraphRemaining = 0.f;
	FTimerHandle CosmeticAlignTimer;

	/** One overlay material per status that has one (RPGStatusEffects), created on BeginPlay. */
	UPROPERTY(Transient)
	TMap<FGameplayTag, TObjectPtr<UMaterialInstanceDynamic>> StatusOverlays;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> HitOverlay;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> TelegraphOverlay;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> StealthOverlay;

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> ShieldBubbleMaterial;
};
