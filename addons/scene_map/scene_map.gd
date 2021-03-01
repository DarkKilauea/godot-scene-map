tool
class_name SceneMap, "scene_map.svg"
extends Spatial


const ScenePalette = preload("scene_palette.gd");
const INVALID_CELL_ITEM = -1;


signal palette_changed;
signal cell_size_changed;
signal cell_center_changed;


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
# value: { itemId: int, path: NodePath }
var cell_map: Dictionary = {};

# Whether a layout is currently pending.
var layout_pending: bool = false;


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
		emit_signal("cell_size_changed");
		_request_layout();


func _set_cell_center_x(value: bool) -> void:
	if cell_center_x != value:
		cell_center_x = value;
		emit_signal("cell_center_changed");
		_request_layout();


func _set_cell_center_y(value: bool) -> void:
	if cell_center_y != value:
		cell_center_y = value;
		emit_signal("cell_center_changed");
		_request_layout();


func _set_cell_center_z(value: bool) -> void:
	if cell_center_z != value:
		cell_center_z = value;
		emit_signal("cell_center_changed");
		_request_layout();


# Set a cell in the map to contain the scene in the palette as indicated by item_id.
# @param coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @param item_id ID of the scene to place at this cell.
# @returns True if the item was removed or placed, false if item was already present when placing.
func set_cell_item(coordinate: Vector3, item_id: int) -> bool:
	coordinate = coordinate.floor();
	
	if get_cell_item(coordinate) == item_id:
		return false;
	
	if item_id == INVALID_CELL_ITEM:
		return _remove_instance(coordinate);
	else:
		if cell_map.has(coordinate):
			_remove_instance(coordinate);
		
		return _place_instance(coordinate, item_id);


# Gets the palette ID of the item at the indicated coordinates.
# @param coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @returns ID of the item if a cell is present, -1 if not.
func get_cell_item(coordinate: Vector3) -> int:
	coordinate = coordinate.floor();
	
	if cell_map.has(coordinate):
		var data := cell_map.get(coordinate) as Dictionary;
		return data.itemId;
	
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


func _request_layout() -> void:
	if layout_pending:
		return;
	
	layout_pending = true;
	call_deferred("_layout");


func _layout() -> void:
	for coordinate in cell_map:
		var data := cell_map.get(coordinate) as Dictionary;
		var spatial := get_node(data.path) as Spatial;
		if spatial:
			spatial.translation = get_global_cell_position(coordinate);
	
	layout_pending = false;


func _remove_instance(coordinate: Vector3) -> bool:
	var data := cell_map.get(coordinate) as Dictionary;
	var node := get_node_or_null(data.path);
	if !node:
		push_error("Could not find scene at %s (%s) to remove." % [data.path, coordinate]);
		cell_map.erase(coordinate);
		return false;
	
	self.remove_child(node);
	node.queue_free();
	
	cell_map.erase(coordinate);
	return true;


func _place_instance(coordinate: Vector3, item_id: int) -> bool:
	var scene := palette.get_item_scene(item_id);
	if !scene:
		push_error("Missing scene for item %s at cell %s" % [item_id, coordinate]);
		return false;
	
	var node := scene.instance(PackedScene.GEN_EDIT_STATE_INSTANCE if Engine.editor_hint else PackedScene.GEN_EDIT_STATE_DISABLED);
	var item_name := palette.get_item_name(item_id);
	if item_name:
		node.name = item_name;
	
	var spatial := node as Spatial;
	if spatial:
		spatial.translation = get_global_cell_position(coordinate);
	
	self.add_child(node, true);
	
	# Climb the nodes above us, looking for an owner to attach to.
	var parent: Node = self;
	while parent:
		if parent.owner:
			node.owner = parent.owner;
			break;
		parent = parent.get_parent();
	
	cell_map[coordinate] = {
		"itemId": item_id,
		"path": self.get_path_to(node)
	};
	
	return true;


func _rebuild() -> void:
	var cells := cell_map.keys();
	for cell in cells:
		var data := cell_map.get(cell) as Dictionary;
		var item_id := data.itemId as int;
		
		_remove_instance(cell);
		_place_instance(cell, item_id);


func _on_palette_changed():
	emit_signal("palette_changed", palette);
	_rebuild();
