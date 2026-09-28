@tool
class_name ForestPath
extends Resource
## A dirt road through the generated forest, as a polyline of ground points (x, z) relative to the WorldGenerator.

signal edited

@export var points := PackedVector2Array():
	set(value):
		points = value
		edited.emit()
@export_range(0.5, 20.0) var width := 4.5:
	set(value):
		width = value
		edited.emit()
