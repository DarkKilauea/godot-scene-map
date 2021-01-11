extends EditorInspectorPlugin


const ScenePalette = preload("../../scene_palette.gd");


func can_handle(object: Object) -> bool:
	if object is ScenePalette:
		return true;
	
	return false;


func parse_property(object: Object, type: int, path: String, hint: int, hint_text: String, usage: int) -> bool:
	var palette := object as ScenePalette;
	if path.begins_with("items/"):
		var parts := path.split("/");
		if parts.size() != 3:
			push_error("Not enough parts (need 3) for property: %s" % path);
			return false;
		
		var item_id := int(parts[1]);
		var prop := parts[2];
		
		match prop:
			"add_item":
				var add_button := Button.new();
				add_button.text = tr("Add Item");
				add_button.connect("pressed", palette, "create_item", [ item_id ]);
				add_custom_control(add_button);
				
				return true;
			"remove_item":
				var remove_button := Button.new();
				remove_button.text = tr("Remove Item");
				remove_button.connect("pressed", palette, "remove_item", [ item_id ]);
				add_custom_control(remove_button);
				return true;
	
	return false;
