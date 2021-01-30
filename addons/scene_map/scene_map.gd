tool
extends Spatial


const ScenePalette = preload("scene_palette.gd");
const INVALID_CELL_ITEM = -1;


signal palette_changed;


# Palette containing scenes that should be instanced in this grid.
var palette: ScenePalette setget _set_palette;

# Size of each cell in the grid.  Should match the size of the scenes in the attached palette.
var cell_size: Vector3 = Vector3(2, 2, 2) setget _set_cell_size;

# If true, scenes are centered within the cell on the X axis.  Otherwise, they will start at X = 0 within the cell.
var cell_center_x: bool = true setget _set_cell_center_x;

# If true, scenes are centered within the cell on the Y axis.  Otherwise, they will start at Y = 0 within the cell.
var cell_center_y: bool = true setget _set_cell_center_y;

# If true, scenes are centered within the cell on the Z axis.  Otherwise, they will start at Z = 0 within the cell.
var cell_center_z: bool = true setget _set_cell_center_z;

# Contains a sparse collection of filled cells with the Id of the scene in the palette.
# key: Vector3
# value: int
var cell_map: Dictionary = {};

# Map of the instances of each scene with the cell location they occur at.
var instance_map: Dictionary = {};

# List of cells that need to be rebuilt.
var dirty_cell_list: Array = [];

# Whether a rebuild is currently pending.
var rebuild_pending: bool = false;


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


func _set_cell_size(value: Vector3) -> void:
	value = value.floor();
	
	if cell_size != value:
		cell_size = value;
		_request_rebuild();


func _set_cell_center_x(value: bool) -> void:
	if cell_center_x != value:
		cell_center_x = value;
		_request_rebuild();


func _set_cell_center_y(value: bool) -> void:
	if cell_center_y != value:
		cell_center_y = value;
		_request_rebuild();


func _set_cell_center_z(value: bool) -> void:
	if cell_center_z != value:
		cell_center_z = value;
		_request_rebuild();


# Set a cell in the map to contain the scene in the palette as indicated by item_id.
# @param coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @param item_id ID of the scene to place at this cell.
func set_cell_item(coordinate: Vector3, item_id: int) -> void:
	coordinate = coordinate.floor();
	
	if get_cell_item(coordinate) == item_id:
		return;
	
	if item_id == INVALID_CELL_ITEM:
		cell_map.erase(coordinate);
	else:
		cell_map[coordinate] = item_id;
	
	_mark_dirty(coordinate);


# Gets the palette ID of the item at the indicated coordinates.
# @param coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @returns ID of the item if a cell is present, -1 if not.
func get_cell_item(coordinate: Vector3) -> int:
	coordinate = coordinate.floor();
	
	if cell_map.has(coordinate):
		return cell_map.get(coordinate);
	
	return INVALID_CELL_ITEM;


func get_global_cell_position(coordinate: Vector3) -> Vector3:
	var cell_location := coordinate;
	
	if cell_center_x:
		cell_location.x += 0.5;
	if cell_center_y:
		cell_location.y += 0.5;
	if cell_center_z:
		cell_location.z += 0.5;
	
	cell_location *= cell_size;
	return cell_location;


func _request_rebuild() -> void:
	if rebuild_pending:
		return;
	
	rebuild_pending = true;
	call_deferred("_rebuild");


func _rebuild() -> void:
	for coord in instance_map:
		_remove_instance(coord);
	
	for coord in cell_map:
		_place_instance(coord);
	
	dirty_cell_list = [];
	rebuild_pending = false;


func _mark_dirty(coordinate: Vector3) -> void:
	var was_empty := dirty_cell_list.empty();
	
	if !dirty_cell_list.has(coordinate):
		dirty_cell_list.append(coordinate);
	
	if was_empty:
		call_deferred("_update_dirty_cells");


func _update_dirty_cells() -> void:
	for cell in dirty_cell_list:
		if instance_map.has(cell):
			_remove_instance(cell);
		
		if cell_map.has(cell):
			_place_instance(cell);
	
	dirty_cell_list = [];


func _remove_instance(coordinate: Vector3) -> void:
	if instance_map.has(coordinate):
		var node := instance_map[coordinate] as Node;
		instance_map.erase(coordinate);
		node.queue_free();


func _place_instance(coordinate: Vector3) -> void:
	if instance_map.has(coordinate):
		push_error("Tried to place instance in a cell that was occupied: %s" % coordinate);
		return;
	
	var item_id := cell_map[coordinate] as int;
	var scene := palette.get_item_scene(item_id);
	if !scene:
		push_error("Missing scene for item %s at cell %s" % [item_id, coordinate]);
		return;
	
	var node := scene.instance();
	node.name = palette.get_item_name(item_id);
	self.add_child(node, true);
	
	instance_map[coordinate] = node;
	
	var spatial := node as Spatial;
	if spatial:
		spatial.translation = get_global_cell_position(coordinate);


func _on_palette_changed():
	emit_signal("palette_changed", palette);
	_request_rebuild();
