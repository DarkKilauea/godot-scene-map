tool
extends Control


const SceneMap = preload("../scene_map.gd");
const ScenePalette = preload("../scene_palette.gd");


var scene_map: SceneMap;


onready var palette_list := $Palette as ItemList;
onready var no_palette_warning := $NoPaletteWarning as Label;


func edit(p_scene_map: SceneMap) -> void:
	if scene_map:
		scene_map.disconnect("palette_changed", self, "_update_palette");
	
	scene_map = p_scene_map;
	
	if scene_map:
		scene_map.connect("palette_changed", self, "_update_palette");
		_update_palette(scene_map.palette);
	else:
		_update_palette(null);


func _update_palette(palette: ScenePalette) -> void:
	palette_list.clear();
	
	if !palette:
		no_palette_warning.show();
		palette_list.hide();
		return;
	
	no_palette_warning.hide();
	palette_list.show();
	
	for item_id in palette.get_item_ids():
		palette_list.add_item(palette.get_item_name(item_id));
