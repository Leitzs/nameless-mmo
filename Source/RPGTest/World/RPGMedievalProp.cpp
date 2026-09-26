#include "World/RPGMedievalProp.h"

#include "Components/InstancedStaticMeshComponent.h"
#include "Components/PointLightComponent.h"
#include "Core/RPGAssets.h"
#include "Engine/CollisionProfile.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "UObject/ConstructorHelpers.h"
#include "World/RPGWorldGenerator.h"

namespace RPGPropPrivate
{
	enum class EShape : uint8
	{
		Cube,
		Cylinder,
		Cone,
		Sphere,
		Count
	};
	constexpr int32 NumShapes = static_cast<int32>(EShape::Count);

	const FLinearColor DarkWood(0.07f, 0.042f, 0.024f);
	const FLinearColor Wood(0.16f, 0.1f, 0.055f);
	const FLinearColor Stone(0.2f, 0.19f, 0.175f);
	const FLinearColor DarkStone(0.11f, 0.105f, 0.1f);
	const FLinearColor Iron(0.07f, 0.07f, 0.075f);
	const FLinearColor Opening(0.015f, 0.012f, 0.01f);
	const FLinearColor WarmGlass(1.f, 0.6f, 0.25f);
	const FLinearColor FireLight(1.f, 0.5f, 0.18f);
	const FLinearColor PlasterPalette[] = { FLinearColor(0.55f, 0.5f, 0.42f), FLinearColor(0.5f, 0.44f, 0.34f), FLinearColor(0.58f, 0.54f, 0.47f) };
	const FLinearColor RoofPalette[] = { FLinearColor(0.28f, 0.2f, 0.09f), FLinearColor(0.3f, 0.075f, 0.045f), FLinearColor(0.1f, 0.1f, 0.12f) };
	const FLinearColor ClothPalette[] = { FLinearColor(0.4f, 0.05f, 0.04f), FLinearColor(0.06f, 0.12f, 0.4f), FLinearColor(0.08f, 0.22f, 0.06f) };

	/** Collects primitive parts (per shape, colliding or decorative) and an optional light while a prop is assembled. */
	struct FPropBuilder
	{
		explicit FPropBuilder(int32 InVariant, float InLength)
			: Variant(InVariant)
			, Length(InLength)
			, Random(InVariant * 7919 + 13)
		{
		}

		int32 Variant;
		float Length;
		FRandomStream Random;
		TArray<FTransform> Transforms[2][NumShapes];
		TArray<float> CustomData[2][NumShapes];

		bool bHasLight = false;
		bool bFlicker = false;
		FVector LightLocation = FVector::ZeroVector;
		FLinearColor LightColor = FLinearColor::White;
		float LightIntensity = 0.f;
		float LightRadius = 1000.f;

		void Add(EShape Shape, const FVector& Center, const FVector& Size, const FRotator& Rotation, const FLinearColor& Color, float Roughness, float Emissive, bool bSolid)
		{
			const int32 Group = bSolid ? 0 : 1;
			const int32 ShapeIndex = static_cast<int32>(Shape);
			Transforms[Group][ShapeIndex].Emplace(Rotation, Center, Size / 100.f);
			CustomData[Group][ShapeIndex].Append(RPGAssets::MakeInstanceData(Color, Roughness, Emissive));
		}

		void AddBox(const FVector& Center, const FVector& Size, const FLinearColor& Color, const FRotator& Rotation = FRotator::ZeroRotator, float Roughness = 0.85f, float Emissive = 0.f, bool bSolid = true)
		{
			Add(EShape::Cube, Center, Size, Rotation, Color, Roughness, Emissive, bSolid);
		}

		void AddCylinder(const FVector& Center, float Diameter, float Height, const FLinearColor& Color, const FRotator& Rotation = FRotator::ZeroRotator, float Roughness = 0.85f, float Emissive = 0.f, bool bSolid = true)
		{
			Add(EShape::Cylinder, Center, FVector(Diameter, Diameter, Height), Rotation, Color, Roughness, Emissive, bSolid);
		}

		void AddCone(const FVector& Center, float Diameter, float Height, const FLinearColor& Color, const FRotator& Rotation = FRotator::ZeroRotator, float Roughness = 0.85f, float Emissive = 0.f, bool bSolid = true)
		{
			Add(EShape::Cone, Center, FVector(Diameter, Diameter, Height), Rotation, Color, Roughness, Emissive, bSolid);
		}

		void AddSphere(const FVector& Center, const FVector& Size, const FLinearColor& Color, float Roughness = 0.85f, float Emissive = 0.f, bool bSolid = true)
		{
			Add(EShape::Sphere, Center, Size, FRotator::ZeroRotator, Color, Roughness, Emissive, bSolid);
		}

		/** A round beam (log, pole) from A to B. */
		void AddBeam(const FVector& A, const FVector& B, float Diameter, const FLinearColor& Color, float Roughness = 0.85f, bool bSolid = true)
		{
			const FVector Delta = B - A;
			const float BeamLength = Delta.Size();
			if (BeamLength > 1.f)
			{
				Add(EShape::Cylinder, (A + B) * 0.5f, FVector(Diameter, Diameter, BeamLength), FRotationMatrix::MakeFromZ(Delta / BeamLength).Rotator(), Color, Roughness, 0.f, bSolid);
			}
		}

		/** A flame made of layered glowing cones (no collision). */
		void AddFlame(const FVector& Base, float Size)
		{
			AddCone(Base + FVector(0.f, 0.f, 42.f * Size), 55.f * Size, 85.f * Size, FLinearColor(1.f, 0.4f, 0.07f), FRotator::ZeroRotator, 0.9f, 12.f, false);
			AddCone(Base + FVector(8.f * Size, -6.f * Size, 52.f * Size), 32.f * Size, 100.f * Size, FLinearColor(1.f, 0.72f, 0.25f), FRotator::ZeroRotator, 0.9f, 16.f, false);
			AddCone(Base + FVector(-10.f * Size, 8.f * Size, 32.f * Size), 36.f * Size, 62.f * Size, FLinearColor(1.f, 0.28f, 0.05f), FRotator::ZeroRotator, 0.9f, 10.f, false);
		}

		void SetLight(const FVector& Location, const FLinearColor& Color, float Intensity, float Radius, bool bInFlicker)
		{
			bHasLight = true;
			LightLocation = Location;
			LightColor = Color;
			LightIntensity = Intensity;
			LightRadius = Radius;
			bFlicker = bInFlicker;
		}

		/** A 45 degree gable roof with its ridge along X, sitting on walls whose top is at Base. */
		void AddGableRoof(const FVector& Base, float RoofLength, float Width, float Overhang, const FLinearColor& RoofColor, const FLinearColor& GableColor)
		{
			const float HalfSpan = Width * 0.5f;
			const float Sqrt2 = FMath::Sqrt(2.f);

			// A cube turned 45 degrees: its upper half forms the triangular gable ends, the lower half hides inside the walls.
			const float Side = Width / Sqrt2;
			AddBox(Base, FVector(RoofLength - 4.f, Side, Side), GableColor, FRotator(0.f, 0.f, 45.f));

			constexpr float Thickness = 24.f;
			const float SlopeLength = (HalfSpan + Overhang) * Sqrt2;
			const FVector Ridge = Base + FVector(0.f, 0.f, HalfSpan);
			for (const float SideSign : { -1.f, 1.f })
			{
				const FVector Down = FVector(0.f, SideSign, -1.f).GetSafeNormal();
				const FVector Out = FVector(0.f, SideSign, 1.f).GetSafeNormal();
				AddBox(Ridge + Down * (SlopeLength * 0.5f) + Out * (Thickness * 0.5f), FVector(RoofLength + Overhang * 2.f, SlopeLength, Thickness), RoofColor,
					FRotationMatrix::MakeFromXY(FVector::ForwardVector, Down).Rotator(), 0.9f);
			}
			AddBeam(Ridge + FVector(-(RoofLength * 0.5f + Overhang), 0.f, Thickness), Ridge + FVector(RoofLength * 0.5f + Overhang, 0.f, Thickness), 26.f, DarkWood);
		}

		/** Glowing window with a dark wooden frame, on a wall facing +/-X (bFacingX) or +/-Y. */
		void AddWindow(const FVector& WallPoint, bool bFacingX)
		{
			const FVector Normal = bFacingX ? FVector(FMath::Sign(WallPoint.X), 0.f, 0.f) : FVector(0.f, FMath::Sign(WallPoint.Y), 0.f);
			const FVector FrameSize = bFacingX ? FVector(6.f, 100.f, 90.f) : FVector(100.f, 6.f, 90.f);
			const FVector GlassSize = bFacingX ? FVector(6.f, 80.f, 70.f) : FVector(80.f, 6.f, 70.f);
			AddBox(WallPoint + Normal * 3.f, FrameSize, DarkWood);
			AddBox(WallPoint + Normal * 6.f, GlassSize, WarmGlass, FRotator::ZeroRotator, 0.4f, 2.5f);
		}

		/** Exposed timber framing on a rectangular block of walls. */
		void AddTimberFrame(float Depth, float Width, float Bottom, float Top)
		{
			const float Mid = FMath::Lerp(Bottom, Top, 0.5f);
			for (const float SX : { -1.f, 1.f })
			{
				for (const float SY : { -1.f, 1.f })
				{
					AddBox(FVector(SX * (Depth * 0.5f + 1.f), SY * (Width * 0.5f + 1.f), (Bottom + Top) * 0.5f), FVector(22.f, 22.f, Top - Bottom), DarkWood);
				}
			}

			const float BraceLength = (Mid - Bottom) / FMath::Cos(FMath::DegreesToRadians(35.f));
			for (const float SideSign : { -1.f, 1.f })
			{
				for (const float Z : { Mid, Top - 8.f })
				{
					AddBox(FVector(0.f, SideSign * (Width * 0.5f + 3.f), Z), FVector(Depth, 8.f, 16.f), DarkWood);
					AddBox(FVector(SideSign * (Depth * 0.5f + 3.f), 0.f, Z), FVector(8.f, Width, 16.f), DarkWood);
				}
				for (const float BX : { -0.3f, 0.3f })
				{
					AddBox(FVector(BX * Depth, SideSign * (Width * 0.5f + 4.f), (Bottom + Mid) * 0.5f), FVector(12.f, 8.f, BraceLength), DarkWood, FRotator(BX > 0.f ? 35.f : -35.f, 0.f, 0.f));
				}
			}
		}
	};

	// -----------------------------------------------------------------------------------------------------------------
	// Prop recipes. Origin is the ground point under the prop's center; +X is the front.

	void BuildCottage(FPropBuilder& B)
	{
		const bool bLong = B.Variant % 2 == 1;
		const float Depth = bLong ? 950.f : 700.f;
		const float Width = 520.f;
		const float Height = 330.f;
		const FLinearColor Plaster = PlasterPalette[B.Variant % 3];
		const FLinearColor Roof = RoofPalette[(B.Variant / 2) % 3];

		B.AddBox(FVector(0.f, 0.f, -40.f), FVector(Depth + 40.f, Width + 40.f, 160.f), Stone);
		B.AddBox(FVector(0.f, 0.f, (40.f + Height) * 0.5f), FVector(Depth, Width, Height - 40.f), Plaster);
		B.AddTimberFrame(Depth, Width, 40.f, Height);
		B.AddGableRoof(FVector(0.f, 0.f, Height), Depth, Width, 60.f, Roof, Plaster);
		B.AddBox(FVector(-Depth * 0.28f, Width * 0.2f, Height + Width * 0.25f + 45.f), FVector(70.f, 70.f, Width * 0.5f + 130.f), Stone);

		const float DoorY = -Width * 0.15f;
		B.AddBox(FVector(Depth * 0.5f + 5.f, DoorY, 145.f), FVector(10.f, 110.f, 210.f), DarkWood);
		B.AddBox(FVector(Depth * 0.5f + 35.f, DoorY, 30.f), FVector(50.f, 140.f, 20.f), Stone);
		B.AddWindow(FVector(Depth * 0.5f, Width * 0.22f, Height * 0.62f), true);
		for (const float Side : { -1.f, 1.f })
		{
			B.AddWindow(FVector(-Depth * 0.2f, Side * Width * 0.5f, Height * 0.62f), false);
			if (bLong)
			{
				B.AddWindow(FVector(Depth * 0.25f, Side * Width * 0.5f, Height * 0.62f), false);
			}
		}

		// Door lantern.
		const FVector Lantern(Depth * 0.5f + 16.f, DoorY - 85.f, 250.f);
		B.AddBox(Lantern, FVector(18.f, 18.f, 26.f), WarmGlass, FRotator::ZeroRotator, 0.4f, 8.f, false);
		B.AddCone(Lantern + FVector(0.f, 0.f, 20.f), 24.f, 14.f, Iron, FRotator::ZeroRotator, 0.5f, 0.f, false);
		B.SetLight(Lantern + FVector(20.f, 0.f, -5.f), FireLight, 120.f, 900.f, false);
	}

	void BuildCampfire(FPropBuilder& B)
	{
		for (int32 Index = 0; Index < 8; ++Index)
		{
			const float Angle = Index * UE_PI / 4.f;
			B.AddSphere(FVector(FMath::Cos(Angle) * 70.f, FMath::Sin(Angle) * 70.f, 8.f), FVector(28.f, 24.f, 20.f), DarkStone, 0.9f);
		}
		for (int32 Index = 0; Index < 3; ++Index)
		{
			const float Angle = Index * 2.f * UE_PI / 3.f;
			B.AddBeam(FVector(FMath::Cos(Angle) * 55.f, FMath::Sin(Angle) * 55.f, 5.f), FVector(FMath::Cos(Angle) * 8.f, FMath::Sin(Angle) * 8.f, 55.f), 16.f, FLinearColor(0.04f, 0.03f, 0.025f), 0.95f, false);
		}
		B.AddCylinder(FVector(0.f, 0.f, 6.f), 70.f, 6.f, FLinearColor(1.f, 0.3f, 0.05f), FRotator::ZeroRotator, 0.9f, 3.f, false);
		B.AddFlame(FVector(0.f, 0.f, 3.f), 1.f);
		B.SetLight(FVector(0.f, 0.f, 90.f), FireLight, 800.f, 1600.f, true);

		// Log seats around the fire.
		for (int32 Index = 0; Index < 3; ++Index)
		{
			const float Angle = Index * 2.f * UE_PI / 3.f + 0.5f;
			const FVector Center(FMath::Cos(Angle) * 220.f, FMath::Sin(Angle) * 220.f, 19.f);
			const FVector Tangent(-FMath::Sin(Angle), FMath::Cos(Angle), 0.f);
			B.AddBeam(Center - Tangent * 80.f, Center + Tangent * 80.f, 38.f, Wood);
		}
	}

	void BuildWatchtower(FPropBuilder& B)
	{
		const FLinearColor Roof = RoofPalette[1 + B.Variant % 2];
		B.AddCylinder(FVector(0.f, 0.f, 280.f), 380.f, 660.f, Stone);
		B.AddCylinder(FVector(0.f, 0.f, 20.f), 410.f, 60.f, DarkStone);
		B.AddBox(FVector(188.f, 0.f, 110.f), FVector(24.f, 110.f, 200.f), DarkWood);
		for (int32 Index = 0; Index < 4; ++Index)
		{
			const float Angle = FMath::DegreesToRadians(45.f + Index * 90.f);
			B.AddBox(FVector(FMath::Cos(Angle) * 188.f, FMath::Sin(Angle) * 188.f, 400.f), FVector(12.f, 16.f, 60.f), Opening, FRotator(0.f, FMath::RadiansToDegrees(Angle), 0.f));
		}

		// Platform with railing, roof posts and a conical roof.
		B.AddBox(FVector(0.f, 0.f, 625.f), FVector(520.f, 520.f, 30.f), Wood);
		for (const float Side : { -1.f, 1.f })
		{
			B.AddBox(FVector(0.f, Side * 252.f, 730.f), FVector(520.f, 8.f, 10.f), DarkWood);
			B.AddBox(FVector(Side * 252.f, 0.f, 730.f), FVector(8.f, 520.f, 10.f), DarkWood);
		}
		for (const float SX : { -1.f, 1.f })
		{
			for (const float SY : { -1.f, 1.f })
			{
				B.AddBox(FVector(SX * 230.f, SY * 230.f, 760.f), FVector(18.f, 18.f, 270.f), DarkWood);
			}
		}
		B.AddCone(FVector(0.f, 0.f, 895.f + 170.f), 680.f, 340.f, Roof);
		B.AddBeam(FVector(0.f, 0.f, 1235.f), FVector(0.f, 0.f, 1400.f), 6.f, Iron);
		B.AddBox(FVector(0.f, 45.f, 1360.f), FVector(4.f, 80.f, 50.f), ClothPalette[B.Variant % 3], FRotator::ZeroRotator, 0.9f, 0.f, false);

		// Brazier on the platform.
		B.AddCylinder(FVector(170.f, 170.f, 660.f), 60.f, 40.f, Iron, FRotator::ZeroRotator, 0.5f);
		B.AddFlame(FVector(170.f, 170.f, 675.f), 0.6f);
		B.SetLight(FVector(170.f, 170.f, 740.f), FireLight, 400.f, 1800.f, true);
	}

	void BuildFence(FPropBuilder& B)
	{
		const int32 Posts = FMath::Max(2, FMath::RoundToInt(B.Length / 200.f) + 1);
		const float Spacing = B.Length / (Posts - 1);
		for (int32 Index = 0; Index < Posts; ++Index)
		{
			B.AddBox(FVector(-B.Length * 0.5f + Index * Spacing, 0.f, 55.f), FVector(14.f, 14.f, 130.f), Wood, FRotator(0.f, B.Random.FRandRange(-4.f, 4.f), 0.f));
		}
		B.AddBox(FVector(0.f, 0.f, 60.f), FVector(B.Length, 7.f, 12.f), Wood);
		B.AddBox(FVector(0.f, 0.f, 100.f), FVector(B.Length, 7.f, 12.f), Wood);
	}

	float GetDefaultClearingRadius(ERPGPropType Type, int32 Variant, float Length)
	{
		switch (Type)
		{
		case ERPGPropType::Cottage: return Variant % 2 == 1 ? 780.f : 620.f;
		case ERPGPropType::Campfire: return 380.f;
		case ERPGPropType::Watchtower: return 520.f;
		case ERPGPropType::Fence: return Length * 0.5f;
		default: return 200.f;
		}
	}
}

ARPGMedievalProp::ARPGMedievalProp()
{
	using namespace RPGPropPrivate;

	PrimaryActorTick.bCanEverTick = true;
	PrimaryActorTick.bStartWithTickEnabled = false;

	SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("SceneRoot"));
	RootComponent = SceneRoot;

	static ConstructorHelpers::FObjectFinder<UStaticMesh> CubeMesh(RPGAssets::CubeMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> CylinderMesh(RPGAssets::CylinderMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> ConeMesh(RPGAssets::ConeMesh);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> SphereMesh(RPGAssets::SphereMesh);
	UStaticMesh* const Meshes[NumShapes] = { CubeMesh.Object, CylinderMesh.Object, ConeMesh.Object, SphereMesh.Object };
	const TCHAR* const ShapeNames[NumShapes] = { TEXT("Cubes"), TEXT("Cylinders"), TEXT("Cones"), TEXT("Spheres") };

	for (int32 Group = 0; Group < 2; ++Group)
	{
		const bool bSolid = Group == 0;
		for (int32 Shape = 0; Shape < NumShapes; ++Shape)
		{
			UInstancedStaticMeshComponent* Parts = CreateDefaultSubobject<UInstancedStaticMeshComponent>(*FString::Printf(TEXT("%s%s"), bSolid ? TEXT("Solid") : TEXT("Decor"), ShapeNames[Shape]));
			Parts->SetupAttachment(SceneRoot);
			Parts->SetStaticMesh(Meshes[Shape]);
			if (bSolid)
			{
				Parts->SetCollisionProfileName(UCollisionProfile::BlockAll_ProfileName);
				SolidParts.Add(Parts);
			}
			else
			{
				Parts->SetCollisionEnabled(ECollisionEnabled::NoCollision);
				Parts->SetCanEverAffectNavigation(false);
				DecorParts.Add(Parts);
			}
		}
	}

	Light = CreateDefaultSubobject<UPointLightComponent>(TEXT("Light"));
	Light->SetupAttachment(SceneRoot);
	Light->SetMobility(EComponentMobility::Movable);
	Light->SetIntensityUnits(ELightUnits::Candelas);
	Light->SetCastShadows(false);
	Light->SetVisibility(false);
}

float ARPGMedievalProp::GetClearingRadius() const
{
	return ClearingRadiusOverride >= 0.f ? ClearingRadiusOverride : RPGPropPrivate::GetDefaultClearingRadius(PropType, Variant, Length);
}

void ARPGMedievalProp::OnConstruction(const FTransform& Transform)
{
	Super::OnConstruction(Transform);

	if (bSnapToTerrain)
	{
		SnapToTerrain();
	}
	Rebuild();

	UWorld* World = GetWorld();
	if (World && !World->IsGameWorld())
	{
		if (ARPGWorldGenerator* Generator = ARPGWorldGenerator::FindInWorld(World))
		{
			Generator->RequestVegetationRefresh();
		}
	}
}

void ARPGMedievalProp::BeginPlay()
{
	Super::BeginPlay();

	FlickerOffset = FMath::FRandRange(0.f, 100.f);
	SetActorTickEnabled(bFlicker);
}

void ARPGMedievalProp::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (bFlicker && Light)
	{
		const float Time = GetWorld()->GetTimeSeconds() * 7.f + FlickerOffset;
		const float Noise = 0.6f * FMath::PerlinNoise1D(Time) + 0.4f * FMath::PerlinNoise1D(Time * 2.3f + 17.f);
		Light->SetIntensity(LightBaseIntensity * (0.85f + 0.3f * Noise));
	}
}

void ARPGMedievalProp::SnapToTerrain()
{
	const ARPGWorldGenerator* Generator = ARPGWorldGenerator::FindInWorld(GetWorld());
	if (!Generator)
	{
		return;
	}

	const FVector Location = GetActorLocation();
	const float GroundZ = Generator->GetTerrainHeight(FVector2D(Location));
	if (!FMath::IsNearlyEqual(Location.Z, GroundZ, 0.5f))
	{
		SetActorLocation(FVector(Location.X, Location.Y, GroundZ));
	}
}

void ARPGMedievalProp::Rebuild()
{
	using namespace RPGPropPrivate;

	FPropBuilder Builder(Variant, Length);
	switch (PropType)
	{
	case ERPGPropType::Cottage: BuildCottage(Builder); break;
	case ERPGPropType::Campfire: BuildCampfire(Builder); break;
	case ERPGPropType::Watchtower: BuildWatchtower(Builder); break;
	case ERPGPropType::Fence: BuildFence(Builder); break;
	}

	UMaterialInterface* Surface = RPGAssets::LoadMaterial(RPGAssets::SurfaceMaterial);
	for (int32 Group = 0; Group < 2; ++Group)
	{
		const TArray<TObjectPtr<UInstancedStaticMeshComponent>>& Components = Group == 0 ? SolidParts : DecorParts;
		for (int32 Shape = 0; Shape < NumShapes && Shape < Components.Num(); ++Shape)
		{
			UInstancedStaticMeshComponent* Parts = Components[Shape];
			const TArray<FTransform>& Transforms = Builder.Transforms[Group][Shape];
			const TArray<float>& CustomData = Builder.CustomData[Group][Shape];

			Parts->ClearInstances();
			Parts->SetNumCustomDataFloats(RPGAssets::NumInstanceDataFloats);
			if (Surface)
			{
				Parts->SetMaterial(0, Surface);
			}
			if (Transforms.Num() == 0)
			{
				continue;
			}

			Parts->AddInstances(Transforms, false, false);
			for (int32 Index = 0; Index < Transforms.Num(); ++Index)
			{
				Parts->SetCustomData(Index, MakeArrayView(CustomData.GetData() + Index * RPGAssets::NumInstanceDataFloats, RPGAssets::NumInstanceDataFloats), false);
			}
			Parts->MarkRenderStateDirty();
		}
	}

	bFlicker = Builder.bHasLight && Builder.bFlicker;
	LightBaseIntensity = Builder.LightIntensity;
	Light->SetVisibility(Builder.bHasLight);
	if (Builder.bHasLight)
	{
		Light->SetRelativeLocation(Builder.LightLocation);
		Light->SetLightColor(Builder.LightColor);
		Light->SetIntensity(Builder.LightIntensity);
		Light->SetAttenuationRadius(Builder.LightRadius);
	}
}
