@tool
class_name MapInfo
extends Resource
## A level offered by the map selector and the main menu.

@export var id: StringName
@export var display_name := ""
## One line shown under the name in the selector.
@export var description := ""
@export_file("*.tscn") var scene_path := ""
