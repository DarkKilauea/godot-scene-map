@tool
extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	if object is SceneMap:
		return true
	return false


func _parse_property(object: Object, type: Variant.Type, path: String, hint: PropertyHint, hint_text: String, usage: int, wide : bool) -> bool:
	var map := object as SceneMap
	
	if path == "undo":
		var undo_button := Button.new()
		undo_button.text = tr("Undo Deletion")
		undo_button.pressed.connect(map.undo)
		add_custom_control(undo_button)
		return true
	if path.begins_with("layers/"):
		var parts := path.split("/")
		if parts.size() != 3:
			push_error("Not enough parts (need 3) for property: %s" % path)
			return false
		
		var layer_id := int(parts[1])
		var prop := parts[2]
		
		match prop:
			"add_layer":
				var add_button := Button.new()
				add_button.text = tr("Add Layer")
				add_button.pressed.connect(map.create_layer)
				add_custom_control(add_button)
				return true
			"remove_layer":
				var remove_button := Button.new()
				remove_button.text = tr("Remove Layer")
				remove_button.pressed.connect(map.remove_layer.bind(layer_id))
				add_custom_control(remove_button)
				return true
	return false
