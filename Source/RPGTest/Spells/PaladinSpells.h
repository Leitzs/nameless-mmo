#pragma once

#include "CoreMinimal.h"
#include "Spells/RPGAbilityArchetypes.h"
#include "PaladinSpells.generated.h"

/** [LMB] Sword Swing: two-hit sword combo. The shield passively blocks part of frontal damage (Trait.FrontalBlock). */
UCLASS()
class RPGTEST_API USpell_SwordSwing : public URPGAbility_MeleeStrike
{
	GENERATED_BODY()

public:
	USpell_SwordSwing();
};

/** [1] Crusader Strike: a holy strike that restores some mana. */
UCLASS()
class RPGTEST_API USpell_CrusaderStrike : public URPGAbility_MeleeStrike
{
	GENERATED_BODY()

public:
	USpell_CrusaderStrike();
};

/** [2] Hammer of Justice: a thrown hammer that stuns the first enemy it hits. */
UCLASS()
class RPGTEST_API USpell_HammerOfJustice : public URPGAbility_Projectile
{
	GENERATED_BODY()

public:
	USpell_HammerOfJustice();
};

/** [3] Flash of Light: heals yourself after a short cast; stuns interrupt it and Mortal Strike weakens it. */
UCLASS()
class RPGTEST_API USpell_FlashOfLight : public URPGAbility_SelfBuff
{
	GENERATED_BODY()

public:
	USpell_FlashOfLight();
};

/** [4] Cleanse: breaks every stun, freeze, fear, root and slow on you and grants brief immunity. Usable while incapacitated. */
UCLASS()
class RPGTEST_API USpell_Cleanse : public URPGAbility_SelfBuff
{
	GENERATED_BODY()

public:
	USpell_Cleanse();
};

/** [5] Divine Shield: immune to damage for a few seconds, but your attacks are weakened. Also purges damage over time. */
UCLASS()
class RPGTEST_API USpell_DivineShield : public URPGAbility_SelfBuff
{
	GENERATED_BODY()

public:
	USpell_DivineShield();
};
