#include "World/RPGWorldGenerator.h"

#include "Async/ParallelFor.h"
#include "Components/BoxComponent.h"
#include "Components/HierarchicalInstancedStaticMeshComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/CollisionProfile.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "ProceduralMeshComponent.h"
#include "RPGTest.h"
#include "UObject/ConstructorHelpers.h"
#include "World/RPGMedievalProp.h"

#define LOCTEXT_NAMESPACE "RPGWorldGenerator"

namespace RPGWorldGenPrivate
{
	constexpr int32 NumNoiseOffsets = 6;

	/** Vertex colors are stored at 4x and scaled back by the terrain's primitive color, for more precision in dark tones. */
	constexpr float VertexColorBoost = 4.f;

	/** Instances waiting to be committed to one instanced mesh component. */
	struct FInstanceBatch
	{
		TArray<FTransform> Transforms;
		TArray<float> CustomData;

		void Add(const FVector& Location, const FRotator& Rotation, const FVector& Scale, const FLinearColor& Color, float Roughness = 0.85f, float Emissive = 0.f)
		{
			Transforms.Emplace(Rotation, Location, Scale);
			CustomData.Append(RPGAssets::MakeInstanceData(Color, Roughness, Emissive));
		}
	};

	void CommitBatch(UInstancedStaticMeshComponent* Component, const FInstanceBatch& Batch, UMaterialInterface* Material, bool bUpdateNavigation)
	{
		Component->ClearInstances();
		Component->SetNumCustomDataFloats(RPGAssets::NumInstanceDataFloats);
		if (Material)
		{
			Component->SetMaterial(0, Material);
		}
		if (Batch.Transforms.Num() == 0)
		{
			return;
		}

		Component->PreAllocateInstancesMemory(Batch.Transforms.Num());
		Component->AddInstances(Batch.Transforms, false, false, bUpdateNavigation);
		for (int32 Index = 0; Index < Batch.Transforms.Num(); ++Index)
		{
			Component->SetCustomData(Index, MakeArrayView(Batch.CustomData.GetData() + Index * RPGAssets::NumInstanceDataFloats, RPGAssets::NumInstanceDataFloats), false);
		}
		Component->MarkRenderStateDirty();
	}

	FLinearColor Vary(const FLinearColor& Color, FRandomStream& Random, float Amount)
	{
		const float Brightness = 1.f + Random.FRandRange(-Amount, Amount);
		return FLinearColor(Color.R * Brightness * (1.f + Random.FRandRange(-Amount, Amount) * 0.5f), Color.G * Brightness, Color.B * Brightness * (1.f + Random.FRandRange(-Amount, Amount) * 0.5f));
	}

	float DistanceToSegment2D(const FVector2D& Point, const FVector2D& A, const FVector2D& B)
	{
		return FMath::PointDistToSegment(FVector(Point, 0.f), FVector(A, 0.f), FVector(B, 0.f));
	}

	UHierarchicalInstancedStaticMeshComponent* CreateInstances(AActor* Owner, USceneComponent* Parent, const TCHAR* Name, UStaticMesh* Mesh, bool bCollision, bool bCastShadow)
	{
		UHierarchicalInstancedStaticMeshComponent* Component = Owner->CreateDefaultSubobject<UHierarchicalInstancedStaticMeshComponent>(Name);
		Component->SetupAttachment(Parent);
		Component->SetStaticMesh(Mesh);
		Component->SetMobility(EComponentMobility::Static);
		Component->SetCastShadow(bCastShadow);
		if (bCollision)
		{
			Component->SetCollisionProfileName(UCollisionProfile::BlockAll_ProfileName);
		}
		else
		{
			Component->SetCollisionEnabled(ECollisionEnabled::NoCollision);
			Component->SetCanEverAffectNavigation(false);
		}
		return Component;
	}
}

ARPGWorldGenerator::ARPGWorldGenerator()
{
	using namespace RPGWorldGenPrivate;

	PrimaryActorTick.bCanEverTick = false;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	SceneRoot->SetMobility(EComponentMobility::Static);
	RootComponent = SceneRoot;

	Terrain = CreateDefaultSubobject<UProceduralMeshComponent>(TEXT("Terrain"));
	Terrain->SetupAttachment(SceneRoot);
	Terrain->SetMobility(EComponentMobility::Static);
	Terrain->bUseAsyncCooking = false;
	Terrain->bUseComplexAsSimpleCollision = true;
	Terrain->SetCollisionProfileName(UCollisionProfile::BlockAll_ProfileName);

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMesh(RPGAssets::CubeMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(RPGAssets::SphereMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> CylinderMesh(RPGAssets::CylinderMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> ConeMesh(RPGAssets::ConeMesh);

	TrunkInstances = CreateInstances(this, SceneRoot, TEXT("TrunkInstances"), CylinderMesh.Object, true, true);
	ConeFoliageInstances = CreateInstances(this, SceneRoot, TEXT("ConeFoliageInstances"), ConeMesh.Object, false, true);
	SphereFoliageInstances = CreateInstances(this, SceneRoot, TEXT("SphereFoliageInstances"), SphereMesh.Object, false, true);
	RockInstances = CreateInstances(this, SceneRoot, TEXT("RockInstances"), SphereMesh.Object, true, true);
	BoulderInstances = CreateInstances(this, SceneRoot, TEXT("BoulderInstances"), CubeMesh.Object, true, true);
	GrassInstances = CreateInstances(this, SceneRoot, TEXT("GrassInstances"), ConeMesh.Object, false, false);
	SmallDetailInstances = CreateInstances(this, SceneRoot, TEXT("SmallDetailInstances"), SphereMesh.Object, false, false);
	StemInstances = CreateInstances(this, SceneRoot, TEXT("StemInstances"), CylinderMesh.Object, false, false);

	WaterInstances = CreateDefaultSubobject<UInstancedStaticMeshComponent>(TEXT("WaterInstances"));
	WaterInstances->SetupAttachment(SceneRoot);
	WaterInstances->SetStaticMesh(CylinderMesh.Object);
	WaterInstances->SetMobility(EComponentMobility::Static);
	WaterInstances->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	WaterInstances->SetCanEverAffectNavigation(false);
	WaterInstances->SetCastShadow(false);

	for (int32 Index = 0; Index < 4; ++Index)
	{
		UBoxComponent* Wall = CreateDefaultSubobject<UBoxComponent>(*FString::Printf(TEXT("BorderWall%d"), Index));
		Wall->SetupAttachment(SceneRoot);
		Wall->SetMobility(EComponentMobility::Static);
		Wall->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
		Wall->SetCollisionObjectType(ECC_WorldStatic);
		Wall->SetCollisionResponseToAllChannels(ECR_Ignore);
		Wall->SetCollisionResponseToChannel(ECC_Pawn, ECR_Block);
		Wall->SetCanEverAffectNavigation(false);
		Wall->SetHiddenInGame(true);
		BorderWalls.Add(Wall);
	}

	// Default layout: a village at the heart of the forest, roads to a training ground, a ruined watchtower on a hill,
	// a bandit camp, a pond, a woodcutter's glade and a ring of standing stones.
	WildernessName = LOCTEXT("Wilderness", "Whisperwood Forest");

	auto AddClearing = [this](const FText& Name, FVector2D Center, float Radius, float HeightOffset, float Dirt, bool bWater = false, float WaterDepth = 0.f)
	{
		FRPGClearing& Clearing = Clearings.AddDefaulted_GetRef();
		Clearing.DisplayName = Name;
		Clearing.Center = Center;
		Clearing.Radius = Radius;
		Clearing.HeightOffset = HeightOffset;
		Clearing.DirtAmount = Dirt;
		Clearing.bWater = bWater;
		Clearing.WaterDepth = WaterDepth;
	};
	AddClearing(LOCTEXT("Village", "Oakhaven Village"), FVector2D(-3000.f, -2500.f), 3400.f, 0.f, 0.55f);
	AddClearing(LOCTEXT("Training", "Training Grounds"), FVector2D(2400.f, -600.f), 2000.f, 0.f, 0.35f);
	AddClearing(LOCTEXT("Ruins", "Old Watchtower Ruins"), FVector2D(9500.f, 7500.f), 2800.f, 450.f, 0.15f);
	AddClearing(LOCTEXT("Camp", "Bandit Camp"), FVector2D(7000.f, -9000.f), 2200.f, 0.f, 0.4f);
	AddClearing(LOCTEXT("Pond", "Mirror Pond"), FVector2D(-9000.f, 7000.f), 2600.f, -320.f, 0.f, true, 200.f);
	AddClearing(LOCTEXT("Stones", "Circle of Elders"), FVector2D(-10500.f, -10000.f), 1600.f, 0.f, 0.1f);
	AddClearing(LOCTEXT("Glade", "Woodcutter's Glade"), FVector2D(1500.f, 9000.f), 1500.f, 0.f, 0.25f);

	auto AddPath = [this](std::initializer_list<FVector2D> Points, float Width)
	{
		FRPGPath& Path = Paths.AddDefaulted_GetRef();
		Path.Points = Points;
		Path.Width = Width;
	};
	AddPath({ FVector2D(-1500.f, -17500.f), FVector2D(-2500.f, -9000.f), FVector2D(-3000.f, -2500.f), FVector2D(-500.f, -1500.f), FVector2D(2400.f, -600.f), FVector2D(4800.f, 2600.f), FVector2D(7200.f, 5600.f), FVector2D(9500.f, 7500.f) }, 450.f);
	AddPath({ FVector2D(-3000.f, -2500.f), FVector2D(-5200.f, 1200.f), FVector2D(-7400.f, 4800.f), FVector2D(-9000.f, 7000.f) }, 400.f);
	AddPath({ FVector2D(2400.f, -600.f), FVector2D(4000.f, -4200.f), FVector2D(5800.f, -7200.f), FVector2D(7000.f, -9000.f) }, 400.f);
	AddPath({ FVector2D(-3000.f, -2500.f), FVector2D(-6500.f, -6500.f), FVector2D(-10500.f, -10000.f) }, 320.f);
	AddPath({ FVector2D(4800.f, 2600.f), FVector2D(3000.f, 6000.f), FVector2D(1500.f, 9000.f) }, 320.f);
}

void ARPGWorldGenerator::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);

	if (!bAutoRegenerate)
	{
		return;
	}

	const uint32 TerrainHash = ComputeTerrainHash();
	if (TerrainHash != GeneratedTerrainHash || Terrain->GetNumSections() == 0)
	{
		GenerateTerrain();
		GeneratedTerrainHash = TerrainHash;
	}

	const uint32 VegetationHash = ComputeVegetationHash();
	if (VegetationHash != GeneratedVegetationHash)
	{
		GenerateVegetation();
		GeneratedVegetationHash = VegetationHash;
	}
}

void ARPGWorldGenerator::BeginDestroy()
{
	if (PendingRefreshHandle.IsValid())
	{
		FTSTicker::RemoveTicker(PendingRefreshHandle);
		PendingRefreshHandle.Reset();
	}
	Super::BeginDestroy();
}

void ARPGWorldGenerator::Regenerate()
{
	GenerateTerrain();
	GeneratedTerrainHash = ComputeTerrainHash();
	GenerateVegetation();
	GeneratedVegetationHash = ComputeVegetationHash();
	MarkPackageDirty();
}

void ARPGWorldGenerator::RequestVegetationRefresh()
{
	const UWorld* World = GetWorld();
	if (!World || World->IsGameWorld())
	{
		return;
	}

	if (PendingRefreshHandle.IsValid())
	{
		FTSTicker::RemoveTicker(PendingRefreshHandle);
	}

	PendingRefreshHandle = FTSTicker::GetCoreTicker().AddTicker(FTickerDelegate::CreateWeakLambda(this, [this](float)
	{
		PendingRefreshHandle.Reset();
		const uint32 VegetationHash = ComputeVegetationHash();
		if (VegetationHash != GeneratedVegetationHash)
		{
			GenerateVegetation();
			GeneratedVegetationHash = VegetationHash;
			MarkPackageDirty();
		}
		return false;
	}), 0.4f);
}

ARPGWorldGenerator* ARPGWorldGenerator::FindInWorld(const UWorld* World)
{
	if (!World)
	{
		return nullptr;
	}

	for (TActorIterator<ARPGWorldGenerator> It(World); It; ++It)
	{
		return *It;
	}
	return nullptr;
}

float ARPGWorldGenerator::GetTerrainHeight(const FVector2D& WorldXY) const
{
	UpdateLayoutCache();
	const FVector Origin = GetActorLocation();
	return Origin.Z + SampleHeight(WorldXY.X - Origin.X, WorldXY.Y - Origin.Y);
}

FText ARPGWorldGenerator::GetZoneNameAt(const FVector& WorldLocation) const
{
	const FVector2D Local = FVector2D(WorldLocation - GetActorLocation());
	for (const FRPGClearing& Clearing : Clearings)
	{
		if (FVector2D::Distance(Local, Clearing.Center) < Clearing.Radius * 0.8f)
		{
			return Clearing.DisplayName;
		}
	}
	return WildernessName;
}

// ---------------------------------------------------------------------------------------------------------------------
// Terrain sampling

void ARPGWorldGenerator::UpdateLayoutCache() const
{
	uint32 Hash = HashCombineFast(GetTypeHash(Seed), GetTypeHash(WorldSize));
	for (const float Value : { HillHeight, HillSize, DetailHeight, DetailSize, BorderWidth, BorderHeight })
	{
		Hash = HashCombineFast(Hash, GetTypeHash(Value));
	}
	for (const FRPGClearing& Clearing : Clearings)
	{
		Hash = HashCombineFast(Hash, HashCombineFast(GetTypeHash(Clearing.Center), GetTypeHash(Clearing.HeightOffset)));
	}

	if (Hash == CachedLayoutHash && NoiseOffsets.Num() == RPGWorldGenPrivate::NumNoiseOffsets && ClearingHeights.Num() == Clearings.Num())
	{
		return;
	}

	CachedLayoutHash = Hash;

	FRandomStream Random(Seed);
	NoiseOffsets.SetNum(RPGWorldGenPrivate::NumNoiseOffsets);
	for (FVector2D& Offset : NoiseOffsets)
	{
		Offset = FVector2D(Random.FRandRange(-200.f, 200.f), Random.FRandRange(-200.f, 200.f));
	}

	ClearingHeights.SetNum(Clearings.Num());
	for (int32 Index = 0; Index < Clearings.Num(); ++Index)
	{
		const FRPGClearing& Clearing = Clearings[Index];
		ClearingHeights[Index] = SampleBaseHeight(Clearing.Center.X, Clearing.Center.Y) + Clearing.HeightOffset;
	}
}

float ARPGWorldGenerator::SampleBaseHeight(float X, float Y) const
{
	const FVector2D Point(X, Y);
	float Height = HillHeight * FMath::PerlinNoise2D(Point / HillSize + NoiseOffsets[0]);
	Height += HillHeight * 0.45f * FMath::PerlinNoise2D(Point / (HillSize * 0.43f) + NoiseOffsets[1]);
	Height += DetailHeight * FMath::PerlinNoise2D(Point / DetailSize + NoiseOffsets[2]);

	// Mountain ring around the map.
	const float EdgeDistance = WorldSize * 0.5f - FMath::Max(FMath::Abs(X), FMath::Abs(Y));
	if (BorderWidth > 0.f && EdgeDistance < BorderWidth)
	{
		const float T = FMath::Clamp(1.f - EdgeDistance / BorderWidth, 0.f, 1.f);
		const float Ridge = 0.75f + 0.25f * FMath::PerlinNoise2D(Point / 3000.f + NoiseOffsets[3]);
		Height += BorderHeight * T * T * Ridge;
	}

	return Height;
}

float ARPGWorldGenerator::SampleHeight(float X, float Y) const
{
	float Height = SampleBaseHeight(X, Y);
	const FVector2D Point(X, Y);
	for (int32 Index = 0; Index < Clearings.Num(); ++Index)
	{
		const FRPGClearing& Clearing = Clearings[Index];
		const float Distance = FVector2D::Distance(Point, Clearing.Center);
		if (Distance < Clearing.Radius)
		{
			const float Weight = 1.f - FMath::SmoothStep(Clearing.Radius * 0.55f, Clearing.Radius, Distance);
			Height = FMath::Lerp(Height, ClearingHeights[Index], Weight);
		}
	}
	return Height;
}

float ARPGWorldGenerator::GetPathEdgeDistance(float X, float Y) const
{
	const FVector2D Point(X, Y);
	float Best = TNumericLimits<float>::Max();
	for (const FRPGPath& Path : Paths)
	{
		for (int32 Index = 0; Index + 1 < Path.Points.Num(); ++Index)
		{
			const float Distance = RPGWorldGenPrivate::DistanceToSegment2D(Point, Path.Points[Index], Path.Points[Index + 1]) - Path.Width * 0.5f;
			Best = FMath::Min(Best, Distance);
		}
	}
	return Best;
}

float ARPGWorldGenerator::GetDirtAmount(float X, float Y) const
{
	const FVector2D Point(X, Y);
	float Dirt = 0.f;

	for (const FRPGPath& Path : Paths)
	{
		const float HalfWidth = Path.Width * 0.5f;
		for (int32 Index = 0; Index + 1 < Path.Points.Num(); ++Index)
		{
			const float Distance = RPGWorldGenPrivate::DistanceToSegment2D(Point, Path.Points[Index], Path.Points[Index + 1]);
			Dirt = FMath::Max(Dirt, 1.f - FMath::SmoothStep(HalfWidth * 0.55f, HalfWidth, Distance));
		}
	}

	for (const FRPGClearing& Clearing : Clearings)
	{
		if (Clearing.DirtAmount > 0.f)
		{
			const float Distance = FVector2D::Distance(Point, Clearing.Center);
			Dirt = FMath::Max(Dirt, Clearing.DirtAmount * (1.f - FMath::SmoothStep(Clearing.Radius * 0.2f, Clearing.Radius * 0.55f, Distance)));
		}
	}

	return Dirt;
}

float ARPGWorldGenerator::GetForestDensity(float X, float Y) const
{
	const FVector2D Point(X, Y);
	const float Noise = 0.5f + 0.5f * FMath::PerlinNoise2D(Point / 6000.f + NoiseOffsets[4]);
	float Density = FMath::Lerp(0.3f, 1.f, FMath::SmoothStep(0.25f, 0.7f, Noise)) * ForestCoverage;

	// Denser towards the mountains.
	const float EdgeDistance = WorldSize * 0.5f - FMath::Max(FMath::Abs(X), FMath::Abs(Y));
	Density = FMath::Max(Density, 1.f - FMath::SmoothStep(BorderWidth * 0.6f, BorderWidth * 1.6f, EdgeDistance));

	// Thinner around clearings so they fade into the forest.
	for (const FRPGClearing& Clearing : Clearings)
	{
		const float Distance = FVector2D::Distance(Point, Clearing.Center);
		if (Distance < Clearing.Radius * 1.5f)
		{
			Density *= FMath::Lerp(0.2f, 1.f, FMath::SmoothStep(Clearing.Radius * 0.9f, Clearing.Radius * 1.5f, Distance));
		}
	}

	return FMath::Clamp(Density, 0.f, 1.f);
}

bool ARPGWorldGenerator::GetWaterLevel(float X, float Y, float& OutLevel) const
{
	for (int32 Index = 0; Index < Clearings.Num(); ++Index)
	{
		const FRPGClearing& Clearing = Clearings[Index];
		if (Clearing.bWater && FVector2D::Distance(FVector2D(X, Y), Clearing.Center) < Clearing.Radius * 0.9f)
		{
			OutLevel = ClearingHeights[Index] + Clearing.WaterDepth;
			return true;
		}
	}
	return false;
}

FLinearColor ARPGWorldGenerator::GetGroundColor(float X, float Y, float Height, const FVector& Normal) const
{
	const FVector2D Point(X, Y);
	const float Large = FMath::PerlinNoise2D(Point / 2600.f + NoiseOffsets[3]);
	const float Small = FMath::PerlinNoise2D(Point / 650.f + NoiseOffsets[5]);

	// Meadow grass with lighter and drier patches.
	FLinearColor Color = FMath::Lerp(FLinearColor(0.038f, 0.07f, 0.017f), FLinearColor(0.08f, 0.11f, 0.024f), FMath::Clamp(0.5f + Large * 0.9f, 0.f, 1.f));
	Color = FMath::Lerp(Color, FLinearColor(0.105f, 0.095f, 0.04f), FMath::Clamp(Small * 0.8f, 0.f, 0.4f));

	// Brown needle-covered floor under dense forest.
	Color = FMath::Lerp(Color, FLinearColor(0.048f, 0.04f, 0.024f), FMath::Clamp((GetForestDensity(X, Y) - 0.5f) * 1.6f, 0.f, 0.7f));

	// Trodden dirt on roads and in clearings.
	const float Dirt = GetDirtAmount(X, Y) * FMath::Clamp(0.85f + Small * 0.3f, 0.f, 1.f);
	Color = FMath::Lerp(Color, FLinearColor(0.125f, 0.088f, 0.052f), Dirt);

	// Bare rock on steep slopes.
	Color = FMath::Lerp(Color, FLinearColor(0.13f, 0.125f, 0.115f), FMath::SmoothStep(0.2f, 0.38f, 1.f - static_cast<float>(Normal.Z)));

	// Mud around and under water.
	float WaterLevel = 0.f;
	if (GetWaterLevel(X, Y, WaterLevel) && Height < WaterLevel + 30.f)
	{
		Color = FMath::Lerp(Color, FLinearColor(0.045f, 0.04f, 0.028f), FMath::Clamp((WaterLevel + 30.f - Height) / 60.f, 0.f, 1.f));
	}

	return Color;
}

// ---------------------------------------------------------------------------------------------------------------------
// Generation

void ARPGWorldGenerator::GenerateTerrain()
{
	using namespace RPGWorldGenPrivate;

	UpdateLayoutCache();

	const int32 Quads = FMath::Clamp(FMath::RoundToInt(WorldSize / GridSpacing), 8, 512);
	const int32 VertsPerSide = Quads + 1;
	const float Step = WorldSize / Quads;
	const float Half = WorldSize * 0.5f;

	TArray<float> Heights;
	Heights.SetNumUninitialized(VertsPerSide * VertsPerSide);
	ParallelFor(VertsPerSide, [&](int32 Row)
	{
		for (int32 Column = 0; Column < VertsPerSide; ++Column)
		{
			Heights[Row * VertsPerSide + Column] = SampleHeight(-Half + Column * Step, -Half + Row * Step);
		}
	});

	const int32 NumVertices = VertsPerSide * VertsPerSide;
	TArray<FVector> Vertices;
	TArray<FVector> Normals;
	TArray<FVector2D> UVs;
	TArray<FLinearColor> Colors;
	TArray<FProcMeshTangent> Tangents;
	Vertices.SetNumUninitialized(NumVertices);
	Normals.SetNumUninitialized(NumVertices);
	UVs.SetNumUninitialized(NumVertices);
	Colors.SetNumUninitialized(NumVertices);
	Tangents.SetNumUninitialized(NumVertices);

	ParallelFor(VertsPerSide, [&](int32 Row)
	{
		const int32 RowDown = FMath::Max(Row - 1, 0);
		const int32 RowUp = FMath::Min(Row + 1, VertsPerSide - 1);
		for (int32 Column = 0; Column < VertsPerSide; ++Column)
		{
			const int32 ColumnLeft = FMath::Max(Column - 1, 0);
			const int32 ColumnRight = FMath::Min(Column + 1, VertsPerSide - 1);
			const int32 Index = Row * VertsPerSide + Column;
			const float X = -Half + Column * Step;
			const float Y = -Half + Row * Step;
			const float Height = Heights[Index];

			const float SlopeX = (Heights[Row * VertsPerSide + ColumnRight] - Heights[Row * VertsPerSide + ColumnLeft]) / ((ColumnRight - ColumnLeft) * Step);
			const float SlopeY = (Heights[RowUp * VertsPerSide + Column] - Heights[RowDown * VertsPerSide + Column]) / ((RowUp - RowDown) * Step);
			const FVector Normal = FVector(-SlopeX, -SlopeY, 1.f).GetSafeNormal();

			Vertices[Index] = FVector(X, Y, Height);
			Normals[Index] = Normal;
			UVs[Index] = FVector2D(X, Y) / 1000.f;
			Tangents[Index] = FProcMeshTangent(FVector(1.f, 0.f, SlopeX).GetSafeNormal(), false);

			FLinearColor Color = GetGroundColor(X, Y, Height, Normal) * VertexColorBoost;
			Color.A = 1.f;
			Colors[Index] = Color.GetClamped();
		}
	});

	TArray<int32> Triangles;
	Triangles.Reserve(Quads * Quads * 6);
	for (int32 Row = 0; Row < Quads; ++Row)
	{
		for (int32 Column = 0; Column < Quads; ++Column)
		{
			// Same winding as UKismetProceduralMeshLibrary::CreateGridMeshWelded (faces up).
			const int32 Index = Row * VertsPerSide + Column;
			Triangles.Add(Index);
			Triangles.Add(Index + VertsPerSide);
			Triangles.Add(Index + 1);
			Triangles.Add(Index + 1);
			Triangles.Add(Index + VertsPerSide);
			Triangles.Add(Index + VertsPerSide + 1);
		}
	}

	Terrain->ClearAllMeshSections();
	Terrain->CreateMeshSection_LinearColor(0, Vertices, Triangles, Normals, UVs, Colors, Tangents, true, false);
	if (UMaterialInterface* Surface = RPGAssets::LoadMaterial(RPGAssets::SurfaceMaterial))
	{
		Terrain->SetMaterial(0, Surface);
	}
	const float ColorScale = 1.f / VertexColorBoost;
	Terrain->SetCustomPrimitiveDataVector4(RPGAssets::PrimitiveDataColor, FVector4(ColorScale, ColorScale, ColorScale, 1.f));
	Terrain->SetCustomPrimitiveDataFloat(RPGAssets::PrimitiveDataRoughness, 0.95f);
	Terrain->SetCustomPrimitiveDataFloat(RPGAssets::PrimitiveDataEmissive, 0.f);

	UpdateBorderWalls();
}

void ARPGWorldGenerator::UpdateBorderWalls()
{
	const float Half = WorldSize * 0.5f;
	const float WallOffset = Half - BorderWidth * 0.45f;
	const float WallHeight = BorderHeight + HillHeight * 2.f + 2000.f;

	for (int32 Index = 0; Index < BorderWalls.Num(); ++Index)
	{
		UBoxComponent* Wall = BorderWalls[Index];
		const bool bAlongY = Index < 2;
		const float Sign = (Index % 2 == 0) ? -1.f : 1.f;
		Wall->SetBoxExtent(bAlongY ? FVector(100.f, Half, WallHeight) : FVector(Half, 100.f, WallHeight));
		Wall->SetRelativeLocation(bAlongY ? FVector(Sign * WallOffset, 0.f, 0.f) : FVector(0.f, Sign * WallOffset, 0.f));
	}
}

void ARPGWorldGenerator::GatherPropFootprints(TArray<FVector>& OutFootprints) const
{
	const UWorld* World = GetWorld();
	if (!World)
	{
		return;
	}

	const FVector Origin = GetActorLocation();
	for (TActorIterator<ARPGMedievalProp> It(World); It; ++It)
	{
		const FVector Local = It->GetActorLocation() - Origin;
		OutFootprints.Add(FVector(Local.X, Local.Y, It->GetClearingRadius()));
	}
}

void ARPGWorldGenerator::GenerateVegetation()
{
	using namespace RPGWorldGenPrivate;

	UpdateLayoutCache();

	FRandomStream Random(Seed * 31 + 7);
	TArray<FVector> PropFootprints;
	GatherPropFootprints(PropFootprints);

	const float Half = WorldSize * 0.5f;

	FInstanceBatch Trunks, Cones, Canopies, Rocks, Boulders, Grass, SmallDetails, Stems, Water;

	auto IsInClearing = [this](float X, float Y, float RadiusFraction, float Margin)
	{
		for (const FRPGClearing& Clearing : Clearings)
		{
			if (FVector2D::Distance(FVector2D(X, Y), Clearing.Center) < Clearing.Radius * RadiusFraction + Margin)
			{
				return true;
			}
		}
		return false;
	};
	auto IsNearProp = [&PropFootprints](float X, float Y, float Margin)
	{
		for (const FVector& Footprint : PropFootprints)
		{
			if (FVector2D::Distance(FVector2D(X, Y), FVector2D(Footprint.X, Footprint.Y)) < Footprint.Z + Margin)
			{
				return true;
			}
		}
		return false;
	};
	auto IsInWater = [this](float X, float Y)
	{
		float Level = 0.f;
		return GetWaterLevel(X, Y, Level);
	};
	auto IsInsideMap = [Half](float X, float Y, float Margin)
	{
		return FMath::Abs(X) < Half - Margin && FMath::Abs(Y) < Half - Margin;
	};
	auto RandomPoint = [&Random, Half]()
	{
		return FVector2D(Random.FRandRange(-Half, Half), Random.FRandRange(-Half, Half));
	};
	auto Ground = [this](float X, float Y)
	{
		return FVector(X, Y, SampleHeight(X, Y));
	};

	const FLinearColor BarkColor(0.075f, 0.045f, 0.026f);

	auto AddFir = [&](const FVector& Base, float Scale)
	{
		const float TrunkHeight = 420.f * Scale;
		const float TrunkDiameter = 48.f * Scale;
		Trunks.Add(Base + FVector(0.f, 0.f, TrunkHeight * 0.5f - 40.f), FRotator(Random.FRandRange(-2.f, 2.f), Random.FRandRange(0.f, 360.f), 0.f),
			FVector(TrunkDiameter / 100.f, TrunkDiameter / 100.f, (TrunkHeight + 80.f) / 100.f), Vary(BarkColor, Random, 0.15f), 0.9f);

		const FLinearColor Needles = Vary(Random.FRand() < 0.5f ? FLinearColor(0.018f, 0.058f, 0.024f) : FLinearColor(0.028f, 0.075f, 0.03f), Random, 0.15f);
		float TierBase = TrunkHeight * 0.3f;
		for (int32 Tier = 0; Tier < 4; ++Tier)
		{
			const float TierHeight = (480.f - Tier * 85.f) * Scale;
			const float TierDiameter = (540.f - Tier * 116.f) * Scale;
			Cones.Add(Base + FVector(0.f, 0.f, TierBase + TierHeight * 0.5f), FRotator(0.f, Random.FRandRange(0.f, 360.f), 0.f),
				FVector(TierDiameter / 100.f, TierDiameter / 100.f, TierHeight / 100.f), Needles * (1.f + Tier * 0.08f), 0.9f);
			TierBase += TierHeight * 0.52f;
		}
	};

	auto AddOak = [&](const FVector& Base, float Scale)
	{
		const float TrunkHeight = 330.f * Scale;
		const float TrunkDiameter = 64.f * Scale;
		Trunks.Add(Base + FVector(0.f, 0.f, TrunkHeight * 0.5f - 40.f), FRotator(Random.FRandRange(-3.f, 3.f), Random.FRandRange(0.f, 360.f), Random.FRandRange(-3.f, 3.f)),
			FVector(TrunkDiameter / 100.f, TrunkDiameter / 100.f, (TrunkHeight + 80.f) / 100.f), Vary(BarkColor, Random, 0.15f), 0.9f);

		static const FLinearColor LeafPalette[] =
		{
			FLinearColor(0.05f, 0.12f, 0.025f),
			FLinearColor(0.07f, 0.14f, 0.03f),
			FLinearColor(0.09f, 0.15f, 0.035f),
			FLinearColor(0.06f, 0.1f, 0.022f),
		};
		FLinearColor Leaves = LeafPalette[Random.RandHelper(UE_ARRAY_COUNT(LeafPalette))];
		if (Random.FRand() < 0.07f)
		{
			Leaves = Random.FRand() < 0.5f ? FLinearColor(0.3f, 0.12f, 0.02f) : FLinearColor(0.32f, 0.2f, 0.03f);
		}

		const FVector CanopyCenter = Base + FVector(0.f, 0.f, TrunkHeight + 120.f * Scale);
		Canopies.Add(CanopyCenter, FRotator(0.f, Random.FRandRange(0.f, 360.f), 0.f), FVector(5.2f, 5.2f, 4.2f) * Scale * Random.FRandRange(0.9f, 1.1f), Vary(Leaves, Random, 0.1f), 0.85f);
		for (int32 Index = 0; Index < 4; ++Index)
		{
			const float Angle = (Index / 4.f + Random.FRandRange(-0.08f, 0.08f)) * 2.f * UE_PI;
			const FVector Offset(FMath::Cos(Angle) * 170.f * Scale, FMath::Sin(Angle) * 170.f * Scale, Random.FRandRange(-40.f, 130.f) * Scale);
			Canopies.Add(CanopyCenter + Offset, FRotator(0.f, Random.FRandRange(0.f, 360.f), 0.f), FVector(Random.FRandRange(3.f, 3.8f) * Scale), Vary(Leaves, Random, 0.15f), 0.85f);
		}
	};

	auto AddBirch = [&](const FVector& Base, float Scale)
	{
		const float TrunkHeight = 620.f * Scale;
		const float TrunkDiameter = 26.f * Scale;
		Trunks.Add(Base + FVector(0.f, 0.f, TrunkHeight * 0.5f - 40.f), FRotator(Random.FRandRange(-4.f, 4.f), Random.FRandRange(0.f, 360.f), Random.FRandRange(-4.f, 4.f)),
			FVector(TrunkDiameter / 100.f, TrunkDiameter / 100.f, (TrunkHeight + 80.f) / 100.f), Vary(FLinearColor(0.6f, 0.58f, 0.54f), Random, 0.08f), 0.7f);

		const FLinearColor Leaves = Vary(FLinearColor(0.13f, 0.19f, 0.04f), Random, 0.15f);
		for (int32 Index = 0; Index < 3; ++Index)
		{
			const FVector Offset(Random.FRandRange(-60.f, 60.f) * Scale, Random.FRandRange(-60.f, 60.f) * Scale, TrunkHeight * (0.62f + Index * 0.17f));
			Canopies.Add(Base + Offset, FRotator(0.f, Random.FRandRange(0.f, 360.f), 0.f), FVector(2.5f, 2.5f, 3.4f) * Scale * Random.FRandRange(0.85f, 1.1f), Leaves, 0.85f);
		}
	};

	auto AddDeadTree = [&](const FVector& Base, float Scale)
	{
		const float TrunkHeight = 480.f * Scale;
		const FLinearColor Wood = Vary(FLinearColor(0.09f, 0.08f, 0.07f), Random, 0.1f);
		Trunks.Add(Base + FVector(0.f, 0.f, TrunkHeight * 0.5f - 40.f), FRotator(Random.FRandRange(-5.f, 5.f), Random.FRandRange(0.f, 360.f), Random.FRandRange(-5.f, 5.f)),
			FVector(0.4f * Scale, 0.4f * Scale, (TrunkHeight + 80.f) / 100.f), Wood, 0.95f);
		for (int32 Index = 0; Index < 3; ++Index)
		{
			const float Yaw = Random.FRandRange(0.f, 360.f);
			const FVector Direction = FRotator(Random.FRandRange(25.f, 55.f), Yaw, 0.f).Vector();
			const float Length = Random.FRandRange(140.f, 220.f) * Scale;
			const FVector Start = Base + FVector(0.f, 0.f, TrunkHeight * Random.FRandRange(0.55f, 0.9f));
			Trunks.Add(Start + Direction * Length * 0.5f, FRotationMatrix::MakeFromZ(Direction).Rotator(), FVector(0.12f * Scale, 0.12f * Scale, Length / 100.f), Wood, 0.95f);
		}
	};

	// Trees on a jittered grid, thinned by the forest density.
	const int32 Cells = FMath::FloorToInt(WorldSize / TreeSpacing);
	for (int32 CellY = 0; CellY < Cells; ++CellY)
	{
		for (int32 CellX = 0; CellX < Cells; ++CellX)
		{
			const float X = -Half + (CellX + Random.FRandRange(0.1f, 0.9f)) * TreeSpacing;
			const float Y = -Half + (CellY + Random.FRandRange(0.1f, 0.9f)) * TreeSpacing;
			const float Roll = Random.FRand();
			const float Scale = Random.FRandRange(0.8f, 1.35f);
			const float TypeRoll = Random.FRand();

			if (Roll > GetForestDensity(X, Y) || !IsInsideMap(X, Y, 300.f) || IsInClearing(X, Y, 0.92f, 150.f) || GetPathEdgeDistance(X, Y) < 250.f || IsNearProp(X, Y, 250.f) || IsInWater(X, Y))
			{
				continue;
			}

			const FVector Base = Ground(X, Y);
			// Firs dominate on higher ground and in some regions, broadleaf trees elsewhere.
			const float ConiferBias = FMath::Clamp(0.5f + 0.5f * FMath::PerlinNoise2D(FVector2D(X, Y) / 12000.f + NoiseOffsets[1]) + (Base.Z - 600.f) / 1500.f, 0.f, 1.f);
			if (TypeRoll < 0.03f)
			{
				AddDeadTree(Base, Scale);
			}
			else if (TypeRoll < 0.3f + 0.45f * ConiferBias)
			{
				AddFir(Base, Scale);
			}
			else if (TypeRoll < 0.88f)
			{
				AddOak(Base, Scale);
			}
			else
			{
				AddBirch(Base, Scale);
			}
		}
	}

	// Bushes, mostly along forest edges.
	for (int32 Attempt = 0; Attempt < BushCount; ++Attempt)
	{
		const FVector2D Point = RandomPoint();
		const float Density = GetForestDensity(Point.X, Point.Y);
		if (Random.FRand() > 0.35f + 0.65f * Density || !IsInsideMap(Point.X, Point.Y, 300.f) || IsInClearing(Point.X, Point.Y, 0.6f, 0.f)
			|| GetPathEdgeDistance(Point.X, Point.Y) < 80.f || IsNearProp(Point.X, Point.Y, 100.f) || IsInWater(Point.X, Point.Y))
		{
			continue;
		}

		const FVector Base = Ground(Point.X, Point.Y);
		const float Scale = Random.FRandRange(0.7f, 1.3f);
		const FLinearColor Leaves = Vary(Random.FRand() < 0.5f ? FLinearColor(0.04f, 0.09f, 0.02f) : FLinearColor(0.06f, 0.11f, 0.025f), Random, 0.15f);
		const int32 Lumps = Random.RandRange(2, 3);
		for (int32 Index = 0; Index < Lumps; ++Index)
		{
			const FVector Offset(Random.FRandRange(-60.f, 60.f) * Scale, Random.FRandRange(-60.f, 60.f) * Scale, 35.f * Scale);
			Canopies.Add(Base + Offset, FRotator(0.f, Random.FRandRange(0.f, 360.f), 0.f), FVector(1.6f, 1.6f, 1.1f) * Scale * Random.FRandRange(0.8f, 1.2f), Leaves, 0.85f);
		}
	}

	// Rocks and boulders, with extra ones on the mountain slopes.
	for (int32 Attempt = 0; Attempt < RockCount; ++Attempt)
	{
		FVector2D Point = RandomPoint();
		if (Attempt % 3 == 0)
		{
			// Bias a third of the rocks towards the border.
			const float Edge = Half - BorderWidth * Random.FRandRange(0.3f, 1.1f);
			Point = Random.FRand() < 0.5f ? FVector2D(Random.FRandRange(-Half, Half), Edge * (Random.FRand() < 0.5f ? -1.f : 1.f))
				: FVector2D(Edge * (Random.FRand() < 0.5f ? -1.f : 1.f), Random.FRandRange(-Half, Half));
		}
		if (!IsInsideMap(Point.X, Point.Y, 200.f) || IsInClearing(Point.X, Point.Y, 0.5f, 0.f) || GetPathEdgeDistance(Point.X, Point.Y) < 100.f
			|| IsNearProp(Point.X, Point.Y, 100.f) || IsInWater(Point.X, Point.Y))
		{
			continue;
		}

		const FVector Base = Ground(Point.X, Point.Y);
		const FLinearColor Stone = FMath::Lerp(FLinearColor(0.15f, 0.145f, 0.135f), FLinearColor(0.09f, 0.11f, 0.06f), Random.FRandRange(0.f, 0.4f));
		if (Random.FRand() < 0.7f)
		{
			const FVector Scale(Random.FRandRange(0.8f, 2.6f), Random.FRandRange(0.7f, 2.2f), Random.FRandRange(0.5f, 1.5f));
			Rocks.Add(Base + FVector(0.f, 0.f, Scale.Z * 50.f * 0.4f), FRotator(Random.FRandRange(-12.f, 12.f), Random.FRandRange(0.f, 360.f), Random.FRandRange(-12.f, 12.f)), Scale, Vary(Stone, Random, 0.12f), 0.9f);
		}
		else
		{
			const float Size = Random.FRandRange(0.8f, 2.f);
			const FVector Scale(Size * Random.FRandRange(0.8f, 1.3f), Size * Random.FRandRange(0.8f, 1.3f), Size * Random.FRandRange(0.6f, 1.f));
			Boulders.Add(Base + FVector(0.f, 0.f, Scale.Z * 50.f * 0.3f), FRotator(Random.FRandRange(-25.f, 25.f), Random.FRandRange(0.f, 360.f), Random.FRandRange(-25.f, 25.f)), Scale, Vary(Stone, Random, 0.12f), 0.9f);
		}
	}

	// Grass tufts: common in meadows and clearings, rarer under dense forest.
	for (int32 Attempt = 0; Attempt < GrassTuftCount; ++Attempt)
	{
		const FVector2D Point = RandomPoint();
		if (Random.FRand() < GetForestDensity(Point.X, Point.Y) * 0.75f || !IsInsideMap(Point.X, Point.Y, 400.f) || GetDirtAmount(Point.X, Point.Y) > 0.45f
			|| IsNearProp(Point.X, Point.Y, 30.f) || IsInWater(Point.X, Point.Y))
		{
			continue;
		}

		const FVector Base = Ground(Point.X, Point.Y);
		const FLinearColor Blade = Vary(Random.FRand() < 0.5f ? FLinearColor(0.07f, 0.13f, 0.028f) : FLinearColor(0.1f, 0.14f, 0.035f), Random, 0.15f);
		const int32 Blades = Random.RandRange(3, 5);
		for (int32 Index = 0; Index < Blades; ++Index)
		{
			const float Height = Random.FRandRange(25.f, 50.f);
			const FVector Offset(Random.FRandRange(-22.f, 22.f), Random.FRandRange(-22.f, 22.f), Height * 0.5f - 4.f);
			Grass.Add(Base + Offset, FRotator(Random.FRandRange(-15.f, 15.f), Random.FRandRange(0.f, 360.f), Random.FRandRange(-15.f, 15.f)),
				FVector(Random.FRandRange(0.06f, 0.1f), Random.FRandRange(0.06f, 0.1f), Height / 100.f), Blade, 0.9f);
		}
	}

	// Wildflower patches in open areas.
	static const FLinearColor FlowerPalette[] =
	{
		FLinearColor(0.8f, 0.62f, 0.05f),
		FLinearColor(0.8f, 0.8f, 0.75f),
		FLinearColor(0.35f, 0.1f, 0.6f),
		FLinearColor(0.7f, 0.06f, 0.05f),
		FLinearColor(0.12f, 0.22f, 0.75f),
	};
	for (int32 Attempt = 0; Attempt < FlowerPatchCount; ++Attempt)
	{
		const FVector2D Center = RandomPoint();
		if (GetForestDensity(Center.X, Center.Y) > 0.55f || !IsInsideMap(Center.X, Center.Y, 500.f) || GetDirtAmount(Center.X, Center.Y) > 0.3f
			|| IsNearProp(Center.X, Center.Y, 60.f) || IsInWater(Center.X, Center.Y))
		{
			continue;
		}

		const FLinearColor Petals = FlowerPalette[Random.RandHelper(UE_ARRAY_COUNT(FlowerPalette))];
		const int32 Flowers = Random.RandRange(4, 9);
		for (int32 Index = 0; Index < Flowers; ++Index)
		{
			const FVector Base = Ground(Center.X + Random.FRandRange(-90.f, 90.f), Center.Y + Random.FRandRange(-90.f, 90.f));
			const float Height = Random.FRandRange(18.f, 32.f);
			Stems.Add(Base + FVector(0.f, 0.f, Height * 0.5f), FRotator(Random.FRandRange(-8.f, 8.f), 0.f, Random.FRandRange(-8.f, 8.f)), FVector(0.012f, 0.012f, Height / 100.f), FLinearColor(0.05f, 0.1f, 0.02f), 0.9f);
			SmallDetails.Add(Base + FVector(0.f, 0.f, Height), FRotator::ZeroRotator, FVector(Random.FRandRange(0.07f, 0.1f)), Vary(Petals, Random, 0.12f), 0.7f);
		}
	}

	// Mushrooms in the forest; a few glowing ones for a touch of magic.
	for (int32 Attempt = 0; Attempt < MushroomPatchCount; ++Attempt)
	{
		const FVector2D Center = RandomPoint();
		if (GetForestDensity(Center.X, Center.Y) < 0.5f || !IsInsideMap(Center.X, Center.Y, 500.f) || IsInClearing(Center.X, Center.Y, 0.9f, 0.f)
			|| GetPathEdgeDistance(Center.X, Center.Y) < 50.f || IsInWater(Center.X, Center.Y))
		{
			continue;
		}

		const bool bGlowing = Random.FRand() < 0.18f;
		const FLinearColor Cap = bGlowing ? FLinearColor(0.1f, 0.6f, 0.9f) : (Random.FRand() < 0.6f ? FLinearColor(0.5f, 0.04f, 0.03f) : FLinearColor(0.25f, 0.14f, 0.07f));
		const int32 Count = Random.RandRange(2, 5);
		for (int32 Index = 0; Index < Count; ++Index)
		{
			const FVector Base = Ground(Center.X + Random.FRandRange(-50.f, 50.f), Center.Y + Random.FRandRange(-50.f, 50.f));
			const float Size = Random.FRandRange(0.7f, 1.3f);
			Stems.Add(Base + FVector(0.f, 0.f, 6.f * Size), FRotator::ZeroRotator, FVector(0.05f, 0.05f, 0.14f) * Size, FLinearColor(0.6f, 0.58f, 0.5f), 0.8f);
			SmallDetails.Add(Base + FVector(0.f, 0.f, 13.f * Size), FRotator::ZeroRotator, FVector(0.17f, 0.17f, 0.08f) * Size, Cap, 0.6f, bGlowing ? 4.f : 0.f);
		}
	}

	// Fallen logs and stumps.
	for (int32 Attempt = 0; Attempt < FallenLogCount; ++Attempt)
	{
		const FVector2D Point = RandomPoint();
		if (GetForestDensity(Point.X, Point.Y) < 0.45f || !IsInsideMap(Point.X, Point.Y, 800.f) || IsInClearing(Point.X, Point.Y, 0.9f, 200.f)
			|| GetPathEdgeDistance(Point.X, Point.Y) < 200.f || IsNearProp(Point.X, Point.Y, 200.f) || IsInWater(Point.X, Point.Y))
		{
			continue;
		}

		const FVector Base = Ground(Point.X, Point.Y);
		const FLinearColor Wood = Vary(FLinearColor(0.08f, 0.05f, 0.03f), Random, 0.15f);
		if (Random.FRand() < 0.6f)
		{
			const float Diameter = Random.FRandRange(45.f, 75.f);
			Trunks.Add(Base + FVector(0.f, 0.f, Diameter * 0.35f), FRotator(90.f, Random.FRandRange(0.f, 360.f), 0.f), FVector(Diameter / 100.f, Diameter / 100.f, Random.FRandRange(3.f, 6.f)), Wood, 0.9f);
		}
		else
		{
			const float Diameter = Random.FRandRange(55.f, 80.f);
			Trunks.Add(Base + FVector(0.f, 0.f, 15.f), FRotator::ZeroRotator, FVector(Diameter / 100.f, Diameter / 100.f, 0.6f), Wood, 0.9f);
		}
	}

	// Water surfaces.
	for (int32 Index = 0; Index < Clearings.Num(); ++Index)
	{
		const FRPGClearing& Clearing = Clearings[Index];
		if (Clearing.bWater)
		{
			const float Diameter = Clearing.Radius * 1.72f;
			Water.Add(FVector(Clearing.Center, ClearingHeights[Index] + Clearing.WaterDepth - 1.f), FRotator::ZeroRotator, FVector(Diameter / 100.f, Diameter / 100.f, 0.02f), FLinearColor(0.01f, 0.03f, 0.04f), 0.04f);
		}
	}

	UMaterialInterface* Surface = RPGAssets::LoadMaterial(RPGAssets::SurfaceMaterial);
	CommitBatch(TrunkInstances, Trunks, Surface, true);
	CommitBatch(ConeFoliageInstances, Cones, Surface, false);
	CommitBatch(SphereFoliageInstances, Canopies, Surface, false);
	CommitBatch(RockInstances, Rocks, Surface, true);
	CommitBatch(BoulderInstances, Boulders, Surface, true);
	CommitBatch(GrassInstances, Grass, Surface, false);
	CommitBatch(SmallDetailInstances, SmallDetails, Surface, false);
	CommitBatch(StemInstances, Stems, Surface, false);
	CommitBatch(WaterInstances, Water, Surface, false);

	const int32 CullDistance = FMath::RoundToInt(SmallDetailCullDistance);
	for (UHierarchicalInstancedStaticMeshComponent* Component : { GrassInstances.Get(), SmallDetailInstances.Get(), StemInstances.Get() })
	{
		Component->SetCullDistances(CullDistance / 2, CullDistance);
	}

	UE_LOG(LogRPG, Log, TEXT("RPGWorldGenerator: %d trunks, %d cones, %d canopies, %d rocks, %d boulders, %d grass, %d details, %d stems"),
		Trunks.Transforms.Num(), Cones.Transforms.Num(), Canopies.Transforms.Num(), Rocks.Transforms.Num(), Boulders.Transforms.Num(),
		Grass.Transforms.Num(), SmallDetails.Transforms.Num(), Stems.Transforms.Num());
}

// ---------------------------------------------------------------------------------------------------------------------
// Change detection

uint32 ARPGWorldGenerator::ComputeTerrainHash() const
{
	uint32 Hash = HashCombineFast(GetTypeHash(Seed), GetTypeHash(GridSpacing));
	for (const float Value : { WorldSize, HillHeight, HillSize, DetailHeight, DetailSize, BorderWidth, BorderHeight })
	{
		Hash = HashCombineFast(Hash, GetTypeHash(Value));
	}
	for (const FRPGClearing& Clearing : Clearings)
	{
		Hash = HashCombineFast(Hash, GetTypeHash(Clearing.Center));
		for (const float Value : { Clearing.Radius, Clearing.HeightOffset, Clearing.DirtAmount, Clearing.WaterDepth })
		{
			Hash = HashCombineFast(Hash, GetTypeHash(Value));
		}
		Hash = HashCombineFast(Hash, GetTypeHash(Clearing.bWater));
	}
	for (const FRPGPath& Path : Paths)
	{
		Hash = HashCombineFast(Hash, GetTypeHash(Path.Width));
		for (const FVector2D& Point : Path.Points)
		{
			Hash = HashCombineFast(Hash, GetTypeHash(Point));
		}
	}
	return Hash;
}

uint32 ARPGWorldGenerator::ComputeVegetationHash() const
{
	uint32 Hash = ComputeTerrainHash();
	for (const float Value : { TreeSpacing, ForestCoverage, SmallDetailCullDistance })
	{
		Hash = HashCombineFast(Hash, GetTypeHash(Value));
	}
	for (const int32 Value : { BushCount, RockCount, GrassTuftCount, FlowerPatchCount, MushroomPatchCount, FallenLogCount })
	{
		Hash = HashCombineFast(Hash, GetTypeHash(Value));
	}

	TArray<FVector> PropFootprints;
	GatherPropFootprints(PropFootprints);
	for (const FVector& Footprint : PropFootprints)
	{
		// Round so sub-centimeter jitter does not trigger a rebuild.
		Hash = HashCombineFast(Hash, GetTypeHash(FIntVector(FMath::RoundToInt(Footprint.X / 10.f), FMath::RoundToInt(Footprint.Y / 10.f), FMath::RoundToInt(Footprint.Z))));
	}
	return Hash;
}

#undef LOCTEXT_NAMESPACE
