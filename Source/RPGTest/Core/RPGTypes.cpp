#include "Core/RPGTypes.h"

#define LOCTEXT_NAMESPACE "RPGTypes"

FRPGResourceConfig FRPGResourceConfig::MakeMana(float InMax, float InRegenPerSecond)
{
	FRPGResourceConfig Config;
	Config.Type = ERPGResourceType::Mana;
	Config.Max = InMax;
	Config.RegenPerSecond = InRegenPerSecond;
	return Config;
}

FRPGResourceConfig FRPGResourceConfig::MakeEnergy(float InMax, float InRegenPerSecond)
{
	FRPGResourceConfig Config;
	Config.Type = ERPGResourceType::Energy;
	Config.Max = InMax;
	Config.RegenPerSecond = InRegenPerSecond;
	return Config;
}

FRPGResourceConfig FRPGResourceConfig::MakeRage(float InMax, float InGainPerDamageDealt, float InGainPerDamageTaken, float InDecayPerSecond)
{
	FRPGResourceConfig Config;
	Config.Type = ERPGResourceType::Rage;
	Config.Max = InMax;
	Config.GainPerDamageDealt = InGainPerDamageDealt;
	Config.GainPerDamageTaken = InGainPerDamageTaken;
	Config.OutOfCombatDecayPerSecond = InDecayPerSecond;
	Config.bStartsFull = false;
	return Config;
}

FText FRPGResourceConfig::GetDisplayName() const
{
	switch (Type)
	{
	case ERPGResourceType::Mana: return LOCTEXT("Mana", "mana");
	case ERPGResourceType::Energy: return LOCTEXT("Energy", "energy");
	case ERPGResourceType::Rage: return LOCTEXT("Rage", "rage");
	default: return FText::GetEmpty();
	}
}

FLinearColor FRPGResourceConfig::GetColor() const
{
	switch (Type)
	{
	case ERPGResourceType::Mana: return FLinearColor(0.12f, 0.35f, 0.95f);
	case ERPGResourceType::Energy: return FLinearColor(0.95f, 0.8f, 0.15f);
	case ERPGResourceType::Rage: return FLinearColor(0.85f, 0.12f, 0.08f);
	default: return FLinearColor::Gray;
	}
}

#undef LOCTEXT_NAMESPACE
