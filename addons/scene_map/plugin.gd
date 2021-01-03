tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("SceneMap", "Spatial", preload("scene_map.gd"), preload("scene_map.svg"));
	add_custom_type("ScenePalette", "Resource", preload("scene_palette.gd"), preload("scene_palette.svg"));


func _exit_tree() -> void:
	remove_custom_type("ScenePalette");
	remove_custom_type("SceneMap");
