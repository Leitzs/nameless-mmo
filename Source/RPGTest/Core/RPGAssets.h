#pragma once

#include "CoreMinimal.h"

class UMaterialInstanceDynamic;
class UMaterialInterface;
class UPrimitiveComponent;
class UStaticMesh;

/**
 * Central place for the asset paths the prototype builds its visuals from.
 * Everything is made from engine primitive shapes plus two master materials, so swapping in real art
 * later only means changing these paths (or overriding the mesh/material properties on the actors).
 */
namespace RPGAssets
{
	// Engine primitives: 100 units in size with the pivot at the center.
	inline constexpr const TCHAR* CubeMesh = TEXT("/Engine/BasicShapes/Cube.Cube");
	inline constexpr const TCHAR* SphereMesh = TEXT("/Engine/BasicShapes/Sphere.Sphere");
	inline constexpr const TCHAR* CylinderMesh = TEXT("/Engine/BasicShapes/Cylinder.Cylinder");
	inline constexpr const TCHAR* ConeMesh = TEXT("/Engine/BasicShapes/Cone.Cone");

	/**
	 * Opaque lit material. Color comes from per-instance custom data (instanced meshes) or custom primitive data
	 * (regular meshes), multiplied by vertex color, which lets the procedural terrain use it too.
	 */
	inline constexpr const TCHAR* SurfaceMaterial = TEXT("/Game/RPGTest/Materials/M_RPG_Surface.M_RPG_Surface");

	/** Additive unlit glow material with Color, Intensity and FresnelAmount parameters (spells, overlays). */
	inline constexpr const TCHAR* FXMaterial = TEXT("/Game/RPGTest/Materials/M_RPG_FX.M_RPG_FX");

	// Mannequin content copied from the engine's third person template.
	inline constexpr const TCHAR* MannyMesh = TEXT("/Game/Characters/Mannequins/Meshes/SKM_Manny_Simple.SKM_Manny_Simple");
	inline constexpr const TCHAR* QuinnMesh = TEXT("/Game/Characters/Mannequins/Meshes/SKM_Quinn_Simple.SKM_Quinn_Simple");
	inline constexpr const TCHAR* UnarmedAnimBlueprint = TEXT("/Game/Characters/Mannequins/Anims/Unarmed/ABP_Unarmed");

	/** Surface material custom data layout, shared by C++ and M_RPG_Surface. */
	inline constexpr int32 PrimitiveDataColor = 0;     // 4 floats (RGBA)
	inline constexpr int32 PrimitiveDataRoughness = 4;
	inline constexpr int32 PrimitiveDataEmissive = 5;
	inline constexpr int32 NumInstanceDataFloats = 5;  // R, G, B, Roughness, Emissive

	RPGTEST_API UStaticMesh* LoadMesh(const TCHAR* Path);
	RPGTEST_API UMaterialInterface* LoadMaterial(const TCHAR* Path);

	/** Assigns the surface material to every slot of a component and sets its look through custom primitive data. */
	RPGTEST_API void ApplySurface(UPrimitiveComponent* Component, const FLinearColor& Color, float Roughness = 0.8f, float Emissive = 0.f);

	/** Creates a dynamic instance of the FX material. Returns null if the material asset is missing. */
	RPGTEST_API UMaterialInstanceDynamic* CreateFXMaterial(UObject* Outer, const FLinearColor& Color, float Intensity, float FresnelAmount);

	/** Packs a color into the per-instance custom data layout used by M_RPG_Surface. */
	RPGTEST_API TArray<float, TFixedAllocator<NumInstanceDataFloats>> MakeInstanceData(const FLinearColor& Color, float Roughness = 0.8f, float Emissive = 0.f);
}
