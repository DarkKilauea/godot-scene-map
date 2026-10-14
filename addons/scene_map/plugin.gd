@tool
extends EditorPlugin


const SceneMap = preload("scene_map.gd")
const SceneMapEditor = preload("editor/scene_map_editor.gd")
const ScenePalette = preload("scene_palette.gd")
const ScenePaletteInspector = preload("editor/palette/scene_palette_inspector.gd")
const SceneMapLayerInspector = preload("res://addons/scene_map/editor/scene_map/scene_map_layer_inspector.gd")


var scene_map_editor: SceneMapEditor
var scene_palette_inspector: ScenePaletteInspector
var scene_map_inspector : SceneMapLayerInspector


func _enter_tree() -> void:
	scene_palette_inspector = ScenePaletteInspector.new()
	add_inspector_plugin(scene_palette_inspector)
	scene_map_inspector = SceneMapLayerInspector.new()
	add_inspector_plugin(scene_map_inspector)
	
	scene_map_editor = preload("editor/scene_map_editor.tscn").instantiate()
	scene_map_editor.plugin = self
	
	## Use this to add a control to the viewport
	#add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, scene_map_editor)
	add_dock(scene_map_editor)
	scene_map_editor.hide()


func _exit_tree() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, scene_map_editor)
	scene_map_editor.plugin = null
	scene_map_editor.free()
	scene_map_editor = null
	
	remove_inspector_plugin(scene_palette_inspector)
	remove_inspector_plugin(scene_map_inspector)


func _edit(object: Object) -> void:
	if object is SceneMap:
		scene_map_editor.edit(object)
		scene_map_editor.show()


func _handles(object: Object) -> bool:
	return object is SceneMap


func _make_visible(visible: bool) -> void:
	if visible:
		scene_map_editor.make_visible()
	else:
		scene_map_editor.edit(null)
		scene_map_editor.close()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	return scene_map_editor.handle_spatial_input(camera, event)
