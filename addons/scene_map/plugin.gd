tool
extends EditorPlugin


const SceneMap = preload("scene_map.gd");
const SceneMapEditor = preload("editor/scene_map_editor.gd");
const ScenePalette = preload("scene_palette.gd");
const ScenePaletteInspector = preload("editor/palette/scene_palette_inspector.gd");


var scene_map_editor: SceneMapEditor;
var scene_palette_inspector: ScenePaletteInspector;


func _enter_tree() -> void:
	add_custom_type("SceneMap", "Spatial", preload("scene_map.gd"), preload("scene_map.svg"));
	add_custom_type("ScenePalette", "Resource", preload("scene_palette.gd"), preload("scene_palette.svg"));
	
	scene_palette_inspector = ScenePaletteInspector.new();
	add_inspector_plugin(scene_palette_inspector);
	
	scene_map_editor = preload("editor/scene_map_editor.tscn").instance();
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, scene_map_editor);
	scene_map_editor.hide();


func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, scene_map_editor);
	scene_map_editor.free();
	scene_map_editor = null;
	
	remove_inspector_plugin(scene_palette_inspector);
	
	remove_custom_type("ScenePalette");
	remove_custom_type("SceneMap");


func edit(object: Object) -> void:
	if object is SceneMap:
		scene_map_editor.edit(object);
		scene_map_editor.show();


func handles(object: Object) -> bool:
	return object is SceneMap;


func make_visible(visible: bool) -> void:
	if visible:
		scene_map_editor.show();
	else:
		scene_map_editor.hide();
