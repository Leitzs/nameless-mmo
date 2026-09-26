#include "Core/RPGAssets.h"

#include "Components/PrimitiveComponent.h"
#include "Engine/StaticMesh.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "Materials/MaterialInterface.h"
#include "RPGTest.h"

namespace RPGAssets
{
	UStaticMesh* LoadMesh(const TCHAR* Path)
	{
		UStaticMesh* Mesh = LoadObject<UStaticMesh>(nullptr, Path);
		UE_CLOG(!Mesh, LogRPG, Warning, TEXT("Missing static mesh '%s'"), Path);
		return Mesh;
	}

	UMaterialInterface* LoadMaterial(const TCHAR* Path)
	{
		UMaterialInterface* Material = LoadObject<UMaterialInterface>(nullptr, Path);
		UE_CLOG(!Material, LogRPG, Warning, TEXT("Missing material '%s'"), Path);
		return Material;
	}

	void ApplySurface(UPrimitiveComponent* Component, const FLinearColor& Color, float Roughness, float Emissive)
	{
		if (!Component)
		{
			return;
		}

		if (UMaterialInterface* Surface = LoadMaterial(SurfaceMaterial))
		{
			for (int32 Slot = 0; Slot < FMath::Max(1, Component->GetNumMaterials()); ++Slot)
			{
				Component->SetMaterial(Slot, Surface);
			}
		}

		Component->SetCustomPrimitiveDataVector4(PrimitiveDataColor, FVector4(Color.R, Color.G, Color.B, 1.f));
		Component->SetCustomPrimitiveDataFloat(PrimitiveDataRoughness, Roughness);
		Component->SetCustomPrimitiveDataFloat(PrimitiveDataEmissive, Emissive);
	}

	UMaterialInstanceDynamic* CreateFXMaterial(UObject* Outer, const FLinearColor& Color, float Intensity, float FresnelAmount)
	{
		UMaterialInterface* Parent = LoadMaterial(FXMaterial);
		if (!Parent)
		{
			return nullptr;
		}

		UMaterialInstanceDynamic* MID = UMaterialInstanceDynamic::Create(Parent, Outer);
		MID->SetVectorParameterValue(TEXT("Color"), Color);
		MID->SetScalarParameterValue(TEXT("Intensity"), Intensity);
		MID->SetScalarParameterValue(TEXT("FresnelAmount"), FresnelAmount);
		return MID;
	}

	TArray<float, TFixedAllocator<NumInstanceDataFloats>> MakeInstanceData(const FLinearColor& Color, float Roughness, float Emissive)
	{
		TArray<float, TFixedAllocator<NumInstanceDataFloats>> Data;
		Data.Add(Color.R);
		Data.Add(Color.G);
		Data.Add(Color.B);
		Data.Add(Roughness);
		Data.Add(Emissive);
		return Data;
	}
}
