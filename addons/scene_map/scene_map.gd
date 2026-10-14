@tool
@icon("scene_map.svg")
class_name SceneMap
extends Node3D


#const ScenePalette = preload("scene_palette.gd")
const INVALID_CELL_ITEM = -1


signal palette_changed()
signal cell_size_changed()
signal cell_center_changed()
signal changed()
signal layer_removed(layer:int)


# Palette containing scenes that should be instanced in this grid.
var palette : ScenePalette :
	set(value):
		if palette != value:
			if palette and changed.is_connected(_on_palette_changed):
				changed.disconnect(_on_palette_changed)
			
			palette = value
			
			if palette and not changed.is_connected(_on_palette_changed):
				changed.connect(_on_palette_changed)
			
			_on_palette_changed()
		return
	get: 
		return palette

func _on_palette_changed():
	palette_changed.emit(palette)
	_rebuild()

var layers : Array[Layer] = [Layer.new()]

# Whether a layout is currently pending.
var layout_pending: bool = false

# Used for undoing/redoing edits to the layer. Prevents losing everything if you mis-click remove layer.
var undoredo := UndoRedo.new()

func _set(property: StringName, value : Variant) -> bool:
	if property.begins_with("layers/"):
		var parts := property.split("/")
		if parts.size() != 3:
			push_error("Not enough parts (need 3) for property: %s" % property)
			return false
		
		var layer_id := int(parts[1])
		var prop := parts[2]
		
		if not layers.size() > layer_id:
			for i in range(layers.size(), layer_id+1):
				## Create new layers until we get to the item_id we were trying to access
				create_layer()
		
		match prop:
			"size":
				var val : Vector3 = value.floor()
				if layers[layer_id].cell_size != value:
					layers[layer_id].cell_size = value
					cell_size_changed.emit()
					_request_layout()
				return true
			"center_x":
				layers[layer_id].center_x = value
				cell_center_changed.emit()
				_request_layout()
				return true
			"center_y":
				layers[layer_id].center_y = value
				cell_center_changed.emit()
				_request_layout()
				return true
			"center_z":
				layers[layer_id].center_z = value
				cell_center_changed.emit()
				_request_layout()
				return true
			_:
				return false
	
	return false


func _get(property: StringName):
	if property.begins_with("layers/"):
		var parts := property.split("/")
		if parts.size() != 3:
			push_error("Not enough parts (need 3) for property: %s" % property)
			return null
		
		var layer_id := int(parts[1])
		var prop := parts[2]
		if not layers.size() > layer_id:
			return null
		
		match prop:
			"size":
				return layers[layer_id].cell_size
			"center_x":
				return layers[layer_id].center_x
			"center_y":
				return layers[layer_id].center_y
			"center_z":
				return layers[layer_id].center_z
			_:
				return null
	else:
		return null


func _get_property_list() -> Array[Dictionary]:
	var properties : Array[Dictionary] = [
		{
			"name": "palette",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "ScenePalette"
		}
	]
	
	for layer_id in layers.size():
		var prefix = "layers/%d/" % layer_id
		properties.append({
			"name": prefix + "size",
			"type": TYPE_VECTOR3,
		})
		properties.append({
			"name": prefix + "center_x",
			"type": TYPE_BOOL
		})
		properties.append({
			"name": prefix + "center_y",
			"type": TYPE_BOOL
		})
		properties.append({
			"name": prefix + "center_z",
			"type": TYPE_BOOL
		})
		properties.append({
			"name": prefix + "cell_map",
			"type": TYPE_DICTIONARY,
			"usage": PROPERTY_USAGE_STORAGE
		})
		
		if layer_id > 0:
			properties.append({
				"name": prefix + "remove_layer",
				"type": TYPE_NIL,
				"usage": PROPERTY_USAGE_EDITOR
			})
	
	properties.append({
		"name": "layers/%d/add_layer" % layers.size(),
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_EDITOR
	})
	
	if undoredo.has_undo():
		properties.append({
			"name": "undo",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_EDITOR
		})
	return properties


# Set a cell in the map to contain the scene in the palette as indicated by item_id.
# @param p_coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @param p_item_id ID of the scene to place at this cell.
# @param p_orientation Quaternion specifying how the item is oriented.
# @returns True if the item was removed or placed, false if item was already present when placing.
func set_cell_item(p_coordinate: Vector3, p_item_id: int, layer:int, p_orientation: Quaternion = Quaternion.IDENTITY) -> bool:
	if layer >= layers.size():
		push_error("Tried to set cell on a layer (%d) that doesn't exist." % layer)
		return false
	
	var coordinate = p_coordinate.floor()
	
	if get_cell_item_id(coordinate, layer) == p_item_id && get_cell_item_orientation(coordinate, layer).is_equal_approx(p_orientation):
		return false
	
	if p_item_id == INVALID_CELL_ITEM:
		return _remove_instance(coordinate, layer)
	else:
		if layers[layer].cell_map.has(coordinate):
			_remove_instance(coordinate, layer)
		
		return _place_instance(coordinate, p_item_id, p_orientation, layer)


# Gets the palette ID of the item at the indicated coordinates.
# @param p_coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @returns ID of the item if a cell is present, -1 if not.
func get_cell_item_id(p_coordinate: Vector3, layer:int) -> int:
	var coordinate = p_coordinate.floor()
	
	if layers[layer].cell_map.has(coordinate):
		var data := layers[layer].cell_map.get(coordinate) as Dictionary
		return data.itemId
	
	return INVALID_CELL_ITEM


# Gets the saved orientation of the item at the indicated coordinates.
# @param p_coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @returns Quaternion specifying how the item is oriented.
func get_cell_item_orientation(p_coordinate: Vector3, layer:int) -> Quaternion:
	var coordinate = p_coordinate.floor()
	
	if layers[layer].cell_map.has(coordinate):
		var data := layers[layer].cell_map.get(coordinate) as Dictionary
		return data.orientation
	
	return Quaternion.IDENTITY


# Gets the position of the cell in relation to this SceneMap.
# @param p_coordinate Vector3 specifying the x, y, and z coordinates of the cell.
# @returns Position of the cell in the coordinate space of the SceneMap.
func get_cell_position(p_coordinate: Vector3, layer:int) -> Vector3:
	var cell_location := p_coordinate
	
	if layers[layer].center_x:
		cell_location.x += 0.5
	if layers[layer].center_y:
		cell_location.y += 0.5
	if layers[layer].center_z:
		cell_location.z += 0.5
	
	cell_location *= layers[layer].cell_size
	return cell_location


func _request_layout() -> void:
	if layout_pending:
		return
	
	layout_pending = true
	call_deferred("_layout")


func _layout() -> void:
	for layer in layers.size():
		for coordinate in layers[layer].cell_map:
			var data := layers[layer].cell_map.get(coordinate) as Dictionary
			var spatial := get_node(data.path) as Node3D
			if spatial:
				spatial.position = get_cell_position(coordinate, layer)
	
	layout_pending = false


func _remove_instance(coordinate: Vector3, layer:int) -> bool:
	var data := layers[layer].cell_map.get(coordinate) as Dictionary
	var node := get_node_or_null(data.path)
	if !node:
		push_error("Could not find scene at %s (%s) to remove." % [data.path, coordinate])
		layers[layer].cell_map.erase(coordinate)
		return false
	
	self.remove_child(node)
	node.queue_free()
	
	layers[layer].cell_map.erase(coordinate)
	return true


func _place_instance(coordinate: Vector3, item_id: int, orientation: Quaternion, layer:int) -> bool:
	var scene : PackedScene = palette.get_item_scene(item_id)
	if !scene:
		push_error("Missing scene for item %s at cell %s" % [item_id, coordinate])
		return false
	
	var node : Node = scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE if Engine.is_editor_hint() else PackedScene.GEN_EDIT_STATE_DISABLED)
	var item_name := palette.get_item_name(item_id)
	if item_name:
		node.name = item_name
	
	var spatial := node as Node3D
	if spatial:
		spatial.transform = Transform3D(Basis(orientation), get_cell_position(coordinate, layer))
	
	self.add_child(node, true)
	
	# Climb the nodes above us, looking for an owner to attach to.
	var parent: Node = self
	while parent:
		if parent.owner:
			node.owner = parent.owner
			break
		parent = parent.get_parent()
	
	layers[layer].cell_map[coordinate] = {
		"itemId": item_id,
		"path": self.get_path_to(node),
		"orientation": orientation
	}
	
	return true


func _rebuild() -> void:
	for layer in layers.size():
		var cells := layers[layer].cell_map.keys()
		for cell in cells:
			var data := layers[layer].cell_map.get(cell) as Dictionary
			var item_id := data.itemId as int
			var orientation := data.orientation as Quaternion
			
			_remove_instance(cell, layer)
			_place_instance(cell, item_id, orientation, layer)


class Layer:
	# Contains a sparse collection of filled cells with the Id of the scene in the palette.
	# key: Vector3
	# value: { itemId: int, path: NodePath, orientation: Quat }
	var cell_map : Dictionary
	var cell_size : Vector3 = Vector3(2.0, 2.0, 2.0)
	# If true, scenes are centered within the cell on the X axis.  Otherwise, they will start at X = 0 within the cell.
	var center_x : bool = true
	# If true, scenes are centered within the cell on the Y axis.  Otherwise, they will start at Y = 0 within the cell.
	var center_y : bool = true
	# If true, scenes are centered within the cell on the Z axis.  Otherwise, they will start at Z = 0 within the cell.
	var center_z : bool = true
	
	func _init() -> void:
		cell_map = {}


func create_layer() -> void:
	layers.append(Layer.new())
	_emit_changed()
	return


func remove_layer(layer:int) -> void:
	if layers.size() <= layer:
		push_error("Layer %d is not present in SceneMap layers." % layer)
		return
	
	undoredo.create_action("SceneMap Delete Layer")
	undoredo.add_do_method(_remove_layer.bind(layer))
	
	# If the cell_map is not duplicated it gets deleted from memory.
	undoredo.add_undo_method(_undo_remove_layer.bind(layers[layer], layers[layer].cell_map.duplicate(), layer))
	undoredo.commit_action()
	
	_emit_changed()
	layer_removed.emit()
	return


func _remove_layer(index:int) -> void:
	for cell in layers[index].cell_map.keys():
		_remove_instance(cell, index)
	layers.remove_at(index)
	return


## The cell map needs to be passed through as it is deleted from memory otherwise.
func _undo_remove_layer(layer:Layer, layer_cell_map:Dictionary, index:int) -> void:
	layers.insert(index, layer)
	for cell in layer_cell_map.keys():
		_place_instance(cell, layer_cell_map[cell]["itemId"], layer_cell_map[cell]["orientation"], index)


## Used by the inspector button to trigger an undo of a layer deletion
func undo() -> void:
	undoredo.undo()
	_emit_changed()


func _emit_changed():
	notify_property_list_changed()
	changed.emit()
