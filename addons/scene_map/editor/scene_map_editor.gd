tool
extends Control


const SceneMap = preload("../scene_map.gd");
const ScenePalette = preload("../scene_palette.gd");


enum PaletteDisplayMode {
	Thumbnail,
	List
}

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
var changed_items: Array = [];
var display_mode: int = PaletteDisplayMode.Thumbnail;
var search_text: String = "";


onready var palette_list := $Palette as ItemList;
onready var no_palette_warning := $NoPaletteWarning as Label;
onready var floor_control := $Toolbar/FloorBox as SpinBox;
onready var search_box := $SearchBar/Search as LineEdit;
onready var thumbnail_button := $SearchBar/Thumbnail as Button;
onready var list_button := $SearchBar/List as Button;


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


func _ready() -> void:
	thumbnail_button.icon = get_icon("FileThumbnail", "EditorIcons");
	list_button.icon = get_icon("FileList", "EditorIcons");
	search_box.right_icon = get_icon("Search", "EditorIcons");


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
	
	var undo_redo := plugin.get_undo_redo();
	
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
			if (click_event.button_index == BUTTON_LEFT && current_input_action == InputAction.Paint) \
			|| (click_event.button_index == BUTTON_RIGHT && current_input_action == InputAction.Erase):
				if !changed_items.empty():
					var action := "SceneMap Paint" if current_input_action == InputAction.Paint else "SceneMap Erase";
					undo_redo.create_action(action);
					
					for i in range(changed_items.size()):
						var item := changed_items[i] as ChangeItem;
						undo_redo.add_do_method(scene_map, "set_cell_item", item.coordinates, item.newItem);
						
						item = changed_items[changed_items.size() - 1 - i] as ChangeItem;
						undo_redo.add_undo_method(scene_map, "set_cell_item", item.coordinates, item.oldItem);
					
					undo_redo.commit_action();
				
				changed_items = [];
				current_input_action = InputAction.None;
				return true;
			
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
			var change := ChangeItem.new();
			change.coordinates = cell;
			change.oldItem = scene_map.get_cell_item(cell);
			change.newItem = selected_item_id;
			changed_items.append(change);
			
			scene_map.set_cell_item(cell, selected_item_id);
			return true;
		InputAction.Erase:
			var change := ChangeItem.new();
			change.coordinates = cell;
			change.oldItem = scene_map.get_cell_item(cell);
			change.newItem = -1;
			changed_items.append(change);
			
			scene_map.set_cell_item(cell, -1);
			return true;
	
	return false;


func _update_cursor_location(cell: Vector3) -> void:
	var cell_location := scene_map.get_global_cell_position(cell);
	
	cursor.scale = scene_map.cell_size;
	cursor.global_transform.origin = cell_location;


func _update_palette(palette: ScenePalette) -> void:
	var last_selected_id := selected_item_id;
	
	palette_list.clear();
	
	if !palette:
		search_box.text = "";
		search_box.editable = false;
		no_palette_warning.show();
		palette_list.hide();
		return;
	
	search_box.editable = true;
	no_palette_warning.hide();
	palette_list.show();
	
	match display_mode:
		PaletteDisplayMode.Thumbnail:
			palette_list.max_columns = 0;
			palette_list.icon_mode = ItemList.ICON_MODE_TOP;
			palette_list.fixed_column_width = 64;
			palette_list.fixed_icon_size = Vector2(64, 64);
		PaletteDisplayMode.List:
			palette_list.max_columns = 1;
			palette_list.icon_mode = ItemList.ICON_MODE_LEFT;
			palette_list.fixed_column_width = 0;
			palette_list.fixed_icon_size = Vector2.ZERO;
	
	var item_count = 0;
	var previewer := plugin.get_editor_interface().get_resource_previewer();
	for item_id in palette.get_item_ids():
		var name := palette.get_item_name(item_id);
		if !name || name.empty():
			name = "#%s" % item_count;
		
		if !search_text.empty() && !search_text.is_subsequence_ofi(name):
			continue;
		
		palette_list.add_item(name);
		palette_list.set_item_metadata(item_count, item_id);
		palette_list.set_item_icon(item_count, get_icon("PackedScene", "EditorIcons"));
		
		var scene := palette.get_item_scene(item_id);
		if scene:
			previewer.queue_resource_preview(scene.resource_path, self, "_thumbnail_result", item_id);
		
		item_count = item_count + 1;
	
	if last_selected_id >= 0 && palette_list.get_item_count() > 0:
		palette_list.select(last_selected_id);


func _floor_changed(value: float) -> void:
	edit_floor = value;


func _item_selected(index: int) -> void:
	var item_id := palette_list.get_item_metadata(index) as int;
	selected_item_id = item_id;


func _set_display_mode(mode: int) -> void:
	if display_mode == mode:
		return;
	
	display_mode = mode;
	
	match display_mode:
		PaletteDisplayMode.Thumbnail:
			thumbnail_button.pressed = true;
			list_button.pressed = false;
		PaletteDisplayMode.List:
			thumbnail_button.pressed = false;
			list_button.pressed = true;
	
	_update_palette(scene_map.palette);


func _thumbnail_result(path: String, preview: Texture, small_preview: Texture, user_data: int) -> void:
	if !preview:
		return;
	
	for i in range(palette_list.get_item_count()):
		var item_id := palette_list.get_item_metadata(i) as int;
		if item_id == user_data:
			palette_list.set_item_icon(i, preview);


class ChangeItem:
	var coordinates: Vector3;
	var newItem: int;
	var oldItem: int;


func _search_text_changed(new_text: String) -> void:
	if search_text == new_text:
		return;
	
	search_text = new_text.strip_edges() if new_text else "";
	_update_palette(scene_map.palette);
