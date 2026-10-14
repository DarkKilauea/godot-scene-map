@tool
@icon("scene_palette.svg")
class_name ScenePalette

extends Resource


@export var item_map : Array[SceneItem] = []


func _init() -> void:
	# Set default name so it isn't set to "Resource".
	resource_name = "ScenePalette"


func _set(property: StringName, value : Variant) -> bool:
	if property.begins_with("items/"):
		var parts := property.split("/")
		if parts.size() != 3:
			push_error("Not enough parts (need 3) for property: %s" % property)
			return false
		
		var item_id := int(parts[1])
		var prop := parts[2]
		
		if not item_map.size() > item_id:
			for i in range(item_map.size(), item_id+1):
				## Create new items until we get to the item_id we were trying to access
				create_item()
		
		match prop:
			"name":
				set_item_name(item_id, value)
				return true
			"scene":
				set_item_scene(item_id, value)
				return true
			_:
				return false
	
	return false


func _get(property: StringName):
	if property.begins_with("items/"):
		var parts := property.split("/")
		if parts.size() != 3:
			push_error("Not enough parts (need 3) for property: %s" % property)
			return null
		
		var item_id := int(parts[1])
		var prop := parts[2]
		if item_map.size() < item_id:
			push_error("(_get error) Item ID %s is out of bounds of palette." % item_id)
			return null
		
		match prop:
			"name":
				return get_item_name(item_id)
			"scene":
				return get_item_scene(item_id)
			_:
				return null
	else:
		return null


func create_item() -> void:
	item_map.append(Item.new())
	_emit_changed()


func insert_item(index : int) -> void:
	item_map.insert(index, Item.new())
	_emit_changed()


func remove_item(item_id: int) -> void:
	if item_id < 0:
		push_error("Item ID cannot be negative.")
	
	if not item_map.size() > item_id:
		push_error("Item ID %s is not present in palette." % item_id)
		return
	
	item_map.remove_at(item_id)
	_emit_changed()


func get_item_name(item_id: int) -> String:
	if item_id < 0:
		push_error("Item ID cannot be negative.")
		return ""
	
	if not item_map.size() > item_id:
		push_error("Item ID %s is not present in palette." % item_id)
		return ""
	
	return item_map[item_id].name


func set_item_name(item_id: int, name: String) -> void:
	if item_id < 0:
		push_error("Item ID cannot be negative.")
		return
	
	if not item_map.size() > item_id:
		push_error("Item ID %s is not present in palette." % item_id)
		return
	
	item_map[item_id].name = name
	## We don't use '_emit_changed' as notifying the property editor resets the cursor placement in the text box.
	emit_changed()


func get_item_scene(item_id: int) -> PackedScene:
	if item_id < 0:
		push_error("Item ID cannot be negative.")
		return null
	if not item_map.size() > item_id:
		push_error("Item %s ID is not present in palette." % item_id)
		return null
	return item_map[item_id].scene


func set_item_scene(item_id: int, scene: PackedScene) -> void:
	if item_id < 0:
		push_error("Item ID cannot be negative.")
		return
	
	if not item_map.size() > item_id:
		push_error("Item %s ID is not present in palette." % item_id)
		return
	
	item_map[item_id].scene = scene
	_emit_changed()


func has_item(item_id: int) -> bool:
	if item_id < 0:
		push_error("Item ID cannot be negative.")
		return false
	return item_map.size() <= item_id


func clear() -> void:
	item_map.clear()
	_emit_changed()


func get_next_available_id() -> int:
	if not item_map:
		return 0
	else:
		return item_map.size()


func _emit_changed():
	notify_property_list_changed()
	emit_changed()


class Item:
	var name: String = ""
	var scene: PackedScene
