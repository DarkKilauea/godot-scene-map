tool
extends EditorPlugin


const SceneMap = preload("scene_map.gd");
const SceneMapEditor = preload("editor/scene_map_editor.gd");
const ScenePalette = preload("scene_palette.gd");
const ScenePaletteEditor = preload("editor/scene_palette_editor.gd");


var scene_map_editor: SceneMapEditor;
var scene_palette_editor: ScenePaletteEditor;


func _enter_tree() -> void:
	add_custom_type("SceneMap", "Spatial", preload("scene_map.gd"), preload("scene_map.svg"));
	add_custom_type("ScenePalette", "Resource", preload("scene_palette.gd"), preload("scene_palette.svg"));
	
	scene_map_editor = preload("editor/scene_map_editor.tscn").instance();
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, scene_map_editor);
	scene_map_editor.hide();
	
	scene_palette_editor = preload("editor/scene_palette_editor.tscn").instance();
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, scene_palette_editor);
	scene_palette_editor.hide();


func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, scene_palette_editor);
	scene_palette_editor.free();
	scene_palette_editor = null;
	
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, scene_map_editor);
	scene_map_editor.free();
	scene_map_editor = null;
	
	remove_custom_type("ScenePalette");
	remove_custom_type("SceneMap");


func edit(object: Object) -> void:
	if object is SceneMap:
		_hide_scene_palette();
		_show_scene_map(object as SceneMap);
	elif object is ScenePalette:
		_hide_scene_map();
		_show_scene_palette(object as ScenePalette);
	else:
		_hide_scene_map();
		_hide_scene_palette();


func handles(object: Object) -> bool:
	return object is SceneMap || object is ScenePalette;


func make_visible(visible: bool) -> void:
	if visible:
		# Not sure what to do here, edit() seems to be called whenever this plugin needs to show a control.
		pass;
	else:
		_hide_scene_map();
		_hide_scene_palette();


func _show_scene_map(p_scene_map: SceneMap) -> void:
	scene_map_editor.edit(p_scene_map);
	scene_map_editor.show();


func _show_scene_palette(p_scene_palette: ScenePalette) -> void:
	scene_palette_editor.edit(p_scene_palette);
	scene_palette_editor.show();


func _hide_scene_map() -> void:
	scene_map_editor.edit(null);
	scene_map_editor.hide();


func _hide_scene_palette() -> void:
	scene_palette_editor.edit(null);
	scene_palette_editor.hide();
