tool
class_name ScenePalette, "scene_palette.svg"
extends Resource


var item_map := {};


func _set(property: String, value) -> bool:
	if property.begins_with("items/"):
		var parts := property.split("/");
		if parts.size() != 3:
			push_error("Not enough parts (need 3) for property: %s" % property);
			return false;
		
		var item_id := int(parts[1]);
		var prop := parts[2];
		
		if !item_map.has(item_id):
			create_item(item_id);
		
		match prop:
			"name":
				set_item_name(item_id, value);
				return true;
			"scene":
				set_item_scene(item_id, value);
				return true;
			_:
				return false;
	
	return false;


func _get(property: String):
	if property.begins_with("items/"):
		var parts := property.split("/");
		if parts.size() != 3:
			push_error("Not enough parts (need 3) for property: %s" % property);
			return null;
		
		var item_id := int(parts[1]);
		var prop := parts[2];
		
		if !item_map.has(item_id):
			push_error("Item ID is not present in palette.");
			return null;
		
		match prop:
			"name":
				return get_item_name(item_id);
			"scene":
				return get_item_scene(item_id);
			_:
				return null;
	else:
		return null;


func _get_property_list() -> Array:
	var props := [
		{
			"name": "ScenePalette",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_CATEGORY
		}
	];
	
	for item_id in item_map:
		var prefix = "items/%d/" % item_id;
		props.append({ 
			"name": prefix + "name", 
			"type": TYPE_STRING 
		});
		props.append({ 
			"name": prefix + "scene", 
			"type": TYPE_OBJECT, 
			"hint": PROPERTY_HINT_RESOURCE_TYPE, 
			"hint_string": "PackedScene" 
		});
		props.append({
			"name": prefix + "remove_item",
			"type": TYPE_NIL,
			"usage": PROPERTY_USAGE_EDITOR
		});
	
	props.append({
		"name": "items/%d/add_item" % get_next_available_id(),
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_EDITOR
	});
	
	return props;


func create_item(item_id: int) -> void:
	if item_id < 0:
		push_error("Item ID cannot be negative.");
	if item_map.has(item_id):
		push_error("Item ID is already present in palette.");
	
	item_map[item_id] = Item.new();
	_emit_changed();


func remove_item(item_id: int) -> void:
	if item_id < 0:
		push_error("Item ID cannot be negative.");
	if !item_map.has(item_id):
		push_error("Item ID is not present in palette.");
	
	item_map.erase(item_id);
	_emit_changed();


func get_item_name(item_id: int) -> String:
	if item_id < 0:
		push_error("Item ID cannot be negative.");
		return "";
	if !item_map.has(item_id):
		push_error("Item ID is not present in palette.");
		return "";
	
	return item_map[item_id].name;


func set_item_name(item_id: int, name: String) -> void:
	if item_id < 0:
		push_error("Item ID cannot be negative.");
	if !item_map.has(item_id):
		push_error("Item ID is not present in palette.");
	
	item_map[item_id].name = name;
	_emit_changed();


func get_item_scene(item_id: int) -> PackedScene:
	if item_id < 0:
		push_error("Item ID cannot be negative.");
		return null;
	if !item_map.has(item_id):
		push_error("Item ID is not present in palette.");
		return null;
	
	return item_map[item_id].scene;


func set_item_scene(item_id: int, scene: PackedScene) -> void:
	if item_id < 0:
		push_error("Item ID cannot be negative.");
	if !item_map.has(item_id):
		push_error("Item ID is not present in palette.");
	
	item_map[item_id].scene = scene;
	_emit_changed();


func has_item(item_id: int) -> bool:
	if item_id < 0:
		push_error("Item ID cannot be negative.");
	
	return item_map.has(item_id);


func get_item_ids() -> Array:
	return item_map.keys();


func clear() -> void:
	item_map.clear();
	_emit_changed();


func get_next_available_id() -> int:
	if item_map.empty():
		return 0;
	else:
		return item_map.size();


func _emit_changed():
	property_list_changed_notify();
	emit_signal("changed");


class Item:
	var name: String;
	var scene: PackedScene;
