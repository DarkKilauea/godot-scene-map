tool
extends Spatial


const ScenePalette = preload("scene_palette.gd");
const INVALID_CELL_ITEM = -1;


signal palette_changed;


# Palette containing scenes that should be instanced in this grid.
var palette: ScenePalette setget _set_palette;

# Size of each cell in the grid.  Should match the size of the scenes in the attached palette.
var cell_size: Vector3 = Vector3(2, 2, 2);

# If true, scenes are centered within the cell on the X axis.  Otherwise, they will start at X = 0 within the cell.
var cell_center_x: bool = true;

# If true, scenes are centered within the cell on the Y axis.  Otherwise, they will start at Y = 0 within the cell.
var cell_center_y: bool = true;

# If true, scenes are centered within the cell on the Z axis.  Otherwise, they will start at Z = 0 within the cell.
var cell_center_z: bool = true;

# Contains a sparse collection of filled cells with the Id of the scene in the palette.
# key: Vector3
# value: int
var cell_map: Dictionary = {};

# Map of the instances of each scene with the cell location they occur at.
var instance_map: Dictionary = {};


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_rebuild();


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
		{
			"name": "cell_map",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE
		}
	];


func _set_palette(value: ScenePalette) -> void:
	if palette != value:
		if palette:
			palette.disconnect("changed", self, "_on_palette_changed");
		
		palette = value;
		
		if palette:
			palette.connect("changed", self, "_on_palette_changed");
		
		_on_palette_changed();


# Set a cell in the map to contain the scene in the palette as indicated by item_id.
# @param coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @param item_id ID of the scene to place at this cell.
func set_cell_item(coordinate: Vector3, item_id: int) -> void:
	pass;


# Gets the palette ID of the item at the indicated coordinates.
# @param coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @returns ID of the item if a cell is present, -1 if not.
func get_cell_item(coordinate: Vector3) -> int:
	coordinate = coordinate.floor();
	
	if cell_map.has(coordinate):
		return cell_map.get(coordinate);
	
	return INVALID_CELL_ITEM;


func _rebuild() -> void:
	pass;


func _on_palette_changed():
	emit_signal("palette_changed", palette);
