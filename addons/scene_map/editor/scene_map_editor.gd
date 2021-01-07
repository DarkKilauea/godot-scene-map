tool
extends Control


const SceneMap = preload("../scene_map.gd");


var scene_map: SceneMap;


func edit(p_scene_map: SceneMap) -> void:
	scene_map = p_scene_map;
	
	_update_palette();


func _update_palette() -> void:
	pass;
