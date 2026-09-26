#pragma once

#include "CoreMinimal.h"
#include "Containers/Ticker.h"
#include "GameFramework/Actor.h"
#include "RPGWorldGenerator.generated.h"

class UBoxComponent;
class UHierarchicalInstancedStaticMeshComponent;
class UInstancedStaticMeshComponent;
class UProceduralMeshComponent;

/** A flattened open area in the forest (village square, camp, glade, pond...). Coordinates are relative to the generator. */
USTRUCT(BlueprintType)
struct FRPGClearing
{
	GENERATED_BODY()

	/** Shown on screen when the player walks in. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Clearing")
	FText DisplayName;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Clearing")
	FVector2D Center = FVector2D::ZeroVector;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Clearing", meta = (ClampMin = "100"))
	float Radius = 2000.f;

	/** Raises (hilltop) or lowers (pond) the flattened ground relative to the surrounding terrain. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Clearing")
	float HeightOffset = 0.f;

	/** Amount of bare trodden dirt in the middle of the clearing. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Clearing", meta = (ClampMin = "0", ClampMax = "1"))
	float DirtAmount = 0.f;

	/** Fills the clearing with a water surface. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Clearing")
	bool bWater = false;

	/** Water surface height above the clearing floor. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Clearing", meta = (EditCondition = "bWater"))
	float WaterDepth = 120.f;
};

/** A dirt road through the forest, as a polyline relative to the generator. */
USTRUCT(BlueprintType)
struct FRPGPath
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Path")
	TArray<FVector2D> Points;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Path", meta = (ClampMin = "50"))
	float Width = 450.f;
};

/**
 * Builds the playable forest: a rolling heightfield terrain ringed by mountains, flattened clearings and dirt roads,
 * and instanced vegetation (firs, oaks, birches, bushes, rocks, grass, flowers, mushrooms, fallen logs) plus ponds.
 *
 * Everything is deterministic from the seed and settings. It regenerates automatically in the editor when a setting
 * changes, and trees are cleared around ARPGMedievalProp actors (re-scattered shortly after a prop moves).
 * The generator should stay unrotated and unscaled; move it to move the whole map.
 */
UCLASS()
class RPGTEST_API ARPGWorldGenerator : public AActor
{
	GENERATED_BODY()

public:
	ARPGWorldGenerator();

	virtual void OnConstruction(const FTransform& Transform) override;
	virtual void BeginDestroy() override;

	/** Rebuilds the terrain and all vegetation. */
	UFUNCTION(CallInEditor, Category = "World Generator")
	void Regenerate();

	/** Terrain surface height (world Z) at a world XY position. */
	UFUNCTION(BlueprintPure, Category = "World Generator")
	float GetTerrainHeight(const FVector2D& WorldXY) const;

	/** Name of the clearing containing the location, or the wilderness name. */
	FText GetZoneNameAt(const FVector& WorldLocation) const;

	/** Re-scatters the vegetation shortly (debounced). Used by props when they move in the editor. */
	void RequestVegetationRefresh();

	static ARPGWorldGenerator* FindInWorld(const UWorld* World);

protected:
	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<USceneComponent> SceneRoot;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UProceduralMeshComponent> Terrain;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UHierarchicalInstancedStaticMeshComponent> TrunkInstances;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UHierarchicalInstancedStaticMeshComponent> ConeFoliageInstances;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UHierarchicalInstancedStaticMeshComponent> SphereFoliageInstances;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UHierarchicalInstancedStaticMeshComponent> RockInstances;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UHierarchicalInstancedStaticMeshComponent> BoulderInstances;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UHierarchicalInstancedStaticMeshComponent> GrassInstances;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UHierarchicalInstancedStaticMeshComponent> SmallDetailInstances;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UHierarchicalInstancedStaticMeshComponent> StemInstances;

	UPROPERTY(VisibleAnywhere, Category = "Components")
	TObjectPtr<UInstancedStaticMeshComponent> WaterInstances;

	/** Invisible walls keeping the player inside the mountain ring: -X, +X, -Y, +Y. */
	UPROPERTY(VisibleAnywhere, Category = "Components")
	TArray<TObjectPtr<UBoxComponent>> BorderWalls;

	UPROPERTY(EditAnywhere, Category = "Terrain")
	int32 Seed = 2024;

	/** Edge length of the square map, in cm. */
	UPROPERTY(EditAnywhere, Category = "Terrain", meta = (ClampMin = "5000"))
	float WorldSize = 40000.f;

	/** Terrain vertex spacing, in cm. */
	UPROPERTY(EditAnywhere, Category = "Terrain", meta = (ClampMin = "50"))
	float GridSpacing = 200.f;

	UPROPERTY(EditAnywhere, Category = "Terrain")
	float HillHeight = 650.f;

	/** Typical distance between hills, in cm. */
	UPROPERTY(EditAnywhere, Category = "Terrain", meta = (ClampMin = "100"))
	float HillSize = 9000.f;

	UPROPERTY(EditAnywhere, Category = "Terrain")
	float DetailHeight = 110.f;

	UPROPERTY(EditAnywhere, Category = "Terrain", meta = (ClampMin = "100"))
	float DetailSize = 2200.f;

	/** Width of the mountain ring around the map edge. */
	UPROPERTY(EditAnywhere, Category = "Terrain", meta = (ClampMin = "0"))
	float BorderWidth = 3500.f;

	UPROPERTY(EditAnywhere, Category = "Terrain")
	float BorderHeight = 3200.f;

	/** Zone name shown outside every clearing. */
	UPROPERTY(EditAnywhere, Category = "Layout")
	FText WildernessName;

	UPROPERTY(EditAnywhere, Category = "Layout")
	TArray<FRPGClearing> Clearings;

	UPROPERTY(EditAnywhere, Category = "Layout")
	TArray<FRPGPath> Paths;

	/** Grid cell size for tree placement; smaller means a denser forest. */
	UPROPERTY(EditAnywhere, Category = "Vegetation", meta = (ClampMin = "200"))
	float TreeSpacing = 650.f;

	UPROPERTY(EditAnywhere, Category = "Vegetation", meta = (ClampMin = "0", ClampMax = "1"))
	float ForestCoverage = 0.85f;

	UPROPERTY(EditAnywhere, Category = "Vegetation", meta = (ClampMin = "0"))
	int32 BushCount = 1800;

	UPROPERTY(EditAnywhere, Category = "Vegetation", meta = (ClampMin = "0"))
	int32 RockCount = 500;

	UPROPERTY(EditAnywhere, Category = "Vegetation", meta = (ClampMin = "0"))
	int32 GrassTuftCount = 7000;

	UPROPERTY(EditAnywhere, Category = "Vegetation", meta = (ClampMin = "0"))
	int32 FlowerPatchCount = 450;

	UPROPERTY(EditAnywhere, Category = "Vegetation", meta = (ClampMin = "0"))
	int32 MushroomPatchCount = 160;

	UPROPERTY(EditAnywhere, Category = "Vegetation", meta = (ClampMin = "0"))
	int32 FallenLogCount = 80;

	/** Grass, flowers and mushrooms disappear beyond this distance. */
	UPROPERTY(EditAnywhere, Category = "Vegetation", meta = (ClampMin = "500"))
	float SmallDetailCullDistance = 6000.f;

	/** Regenerate automatically in the editor when settings change. */
	UPROPERTY(EditAnywhere, Category = "World Generator")
	bool bAutoRegenerate = true;

private:
	void GenerateTerrain();
	void GenerateVegetation();
	void UpdateBorderWalls();
	void UpdateLayoutCache() const;

	/** Terrain height from noise and the mountain ring, before clearings are flattened. Local coordinates. */
	float SampleBaseHeight(float X, float Y) const;
	/** Final terrain height in local coordinates. */
	float SampleHeight(float X, float Y) const;
	/** Signed distance to the nearest road edge (negative on the road). */
	float GetPathEdgeDistance(float X, float Y) const;
	/** 0..1 tree density from noise, mountains and clearing edges. */
	float GetForestDensity(float X, float Y) const;
	/** 0..1 amount of bare dirt from roads and clearing centers. */
	float GetDirtAmount(float X, float Y) const;
	/** Water surface height if the point is inside a pond. */
	bool GetWaterLevel(float X, float Y, float& OutLevel) const;
	FLinearColor GetGroundColor(float X, float Y, float Height, const FVector& Normal) const;
	void GatherPropFootprints(TArray<FVector>& OutFootprints) const;

	uint32 ComputeTerrainHash() const;
	uint32 ComputeVegetationHash() const;

	UPROPERTY()
	uint32 GeneratedTerrainHash = 0;

	UPROPERTY()
	uint32 GeneratedVegetationHash = 0;

	mutable TArray<float> ClearingHeights;
	mutable TArray<FVector2D> NoiseOffsets;
	mutable uint32 CachedLayoutHash = 0;

	FTSTicker::FDelegateHandle PendingRefreshHandle;
};
