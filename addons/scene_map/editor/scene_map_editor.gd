tool
extends Control


const SceneMap = preload("../scene_map.gd");
const ScenePalette = preload("../scene_palette.gd");


enum InputAction {
	None,
	Paint,
	Erase
}


var plugin: EditorPlugin;
var scene_map: SceneMap;
var cursor: MeshInstance;
var edit_axis: int = Vector3.AXIS_Y;
var edit_floor: int = 0;
var selected_item_id: int = 0;
var current_input_action: int = InputAction.None;


onready var palette_list := $Palette as ItemList;
onready var no_palette_warning := $NoPaletteWarning as Label;
onready var floor_control := $Toolbar/FloorBox as SpinBox;


func _enter_tree() -> void:
	var cursor_material := SpatialMaterial.new();
	cursor_material.albedo_color = Color(0.7, 0.7, 1.0, 0.2);
	cursor_material.flags_unshaded = true;
	cursor_material.flags_transparent = true;
	
	var cursor_mesh := CubeMesh.new();
	cursor_mesh.size = Vector3(1, 1, 1);
	cursor_mesh.material = cursor_material;
	
	cursor = MeshInstance.new();
	cursor.mesh = cursor_mesh;
	self.add_child(cursor);
	cursor.hide();


func _exit_tree() -> void:
	cursor.queue_free();
	cursor = null;


func edit(p_scene_map: SceneMap) -> void:
	if scene_map:
		scene_map.disconnect("palette_changed", self, "_update_palette");
	
	scene_map = p_scene_map;
	
	if scene_map:
		scene_map.connect("palette_changed", self, "_update_palette");
		_update_palette(scene_map.palette);
		cursor.visible = true;
	else:
		_update_palette(null);
		cursor.visible = false;


func handle_spatial_input(camera: Camera, event: InputEvent) -> bool:
	if !scene_map || !scene_map.palette:
		return false;
	
	var click_event := event as InputEventMouseButton;
	if click_event:
		if click_event.button_index == BUTTON_WHEEL_UP && click_event.shift:
			if click_event.pressed:
				floor_control.value += click_event.factor;
			return true;
		elif click_event.button_index == BUTTON_WHEEL_DOWN && click_event.shift:
			if click_event.pressed:
				floor_control.value -= click_event.factor;
			return true;
		
		if click_event.pressed:
			if click_event.button_index == BUTTON_LEFT:
				current_input_action = InputAction.Paint;
			elif click_event.button_index == BUTTON_RIGHT:
				current_input_action = InputAction.Erase;
			else:
				return false;
			
			return _handle_input(camera, click_event.position);
		else:
			current_input_action = InputAction.None;
	
	var move_event := event as InputEventMouseMotion;
	if move_event:
		return _handle_input(camera, move_event.position);
	
	return false;


func _handle_input(camera: Camera, point: Vector2) -> bool:
	var from := camera.project_ray_origin(point);
	var normal := camera.project_ray_normal(point);
	
	var plane := Plane();
	plane.normal[edit_axis] = 1.0;
	plane.d = edit_floor * scene_map.cell_size[edit_axis];
	
	var hit := plane.intersects_ray(from, normal);
	if !hit:
		return false;
	
	var cell := Vector3();
	for i in range(3):
		if i == edit_axis:
			cell[i] = edit_floor;
		else:
			cell[i] = floor(hit[i] / scene_map.cell_size[i]);
	
	_update_cursor_location(cell);
	
	match current_input_action:
		InputAction.Paint:
			scene_map.set_cell_item(cell, selected_item_id);
			return true;
		InputAction.Erase:
			scene_map.set_cell_item(cell, -1);
			return true;
	
	return false;


func _update_cursor_location(cell: Vector3) -> void:
	var cell_location := scene_map.get_global_cell_position(cell);
	
	cursor.scale = scene_map.cell_size;
	cursor.global_transform.origin = cell_location;


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
		palette_list.set_item_metadata(palette_list.get_item_count() - 1, item_id);


func _floor_changed(value: float) -> void:
	edit_floor = value;


func _item_selected(index: int) -> void:
	var item_id := palette_list.get_item_metadata(index) as int;
	selected_item_id = item_id;
