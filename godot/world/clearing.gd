@tool
class_name Clearing
extends Resource
## A flattened open area in the generated forest (village square, camp, glade, pond). Coordinates are meters on the
## ground plane (x, z), relative to the WorldGenerator.

signal edited

## Shown on screen when the player walks in.
@export var display_name := "":
	set(value):
		display_name = value
		edited.emit()
@export var center := Vector2.ZERO:
	set(value):
		center = value
		edited.emit()
@export_range(1.0, 200.0) var radius := 20.0:
	set(value):
		radius = value
		edited.emit()
## Raises (hilltop) or lowers (pond) the flattened ground relative to the surrounding terrain.
@export var height_offset := 0.0:
	set(value):
		height_offset = value
		edited.emit()
## Amount of bare trodden dirt in the middle.
@export_range(0.0, 1.0) var dirt_amount := 0.0:
	set(value):
		dirt_amount = value
		edited.emit()
## Fills the clearing with a water surface.
@export var water := false:
	set(value):
		water = value
		edited.emit()
## Water surface height above the clearing floor.
@export var water_depth := 1.2:
	set(value):
		water_depth = value
		edited.emit()
