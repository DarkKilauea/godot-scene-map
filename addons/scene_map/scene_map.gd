tool
extends Spatial

const ScenePalette = preload("scene_palette.gd")

var palette: ScenePalette;
var cell_size: Vector3 = Vector3.ONE;
var cell_center_x: bool = true;
var cell_center_y: bool = true;
var cell_center_z: bool = true;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _get_property_list() -> Array:
	return [
		{
			"name": "SceneMap",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY
		},
		{
			"name": "palette",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "ScenePalette"
		},
		{
			"name": "Cell",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_GROUP,
			"hint_string": "cell_"
		},
		{
			"name": "cell_size",
			"type": TYPE_VECTOR3
		},
		{
			"name": "cell_center_x",
			"type": TYPE_BOOL
		},
		{
			"name": "cell_center_y",
			"type": TYPE_BOOL
		},
		{
			"name": "cell_center_z",
			"type": TYPE_BOOL
		},
	];
