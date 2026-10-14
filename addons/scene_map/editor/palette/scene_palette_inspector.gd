@tool
extends EditorInspectorPlugin


func _can_handle(object: Object) -> bool:
	if object is ScenePalette:
		return true
	return false


func _parse_property(object: Object, type: Variant.Type, path: String, hint: PropertyHint, hint_text: String, usage: int, wide : bool) -> bool:
	var palette := object as ScenePalette
	if path == "add_item":
		var add_button := Button.new()
		add_button.text = tr("Add Item")
		add_button.pressed.connect(palette.create_item)
		add_custom_control(add_button)
		return true
	
	if path.begins_with("items/"):
		var parts := path.split("/")
		if parts.size() != 3:
			push_error("Not enough parts (need 3) for property: %s" % path)
			return false
		
		var item_id := int(parts[1])
		var prop := parts[2]
		
		match prop:
			
			"remove_item":
				var hbox := HBoxContainer.new()
				var remove_button := Button.new()
				remove_button.text = tr("Remove Item")
				remove_button.pressed.connect(palette.remove_item.bind(item_id))
				hbox.add_child(remove_button)
				var insert_button := Button.new()
				insert_button.text = tr("Insert Below")
				insert_button.pressed.connect(palette.insert_item.bind(item_id))
				hbox.add_child(insert_button)
				add_custom_control(hbox)
				return true
	return false
