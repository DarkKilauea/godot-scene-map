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

enum MenuOption {
	PreviousLevel,
	NextLevel,
	EditAxis_X,
	EditAxis_Y,
	EditAxis_Z
}


var plugin: EditorPlugin;
var scene_map: SceneMap;
var cursor: Spatial;
var cursor_origin: Vector3;
var edit_axis: int = Vector3.AXIS_Y;
var edit_floor: int = 0;
var edit_grid: MeshInstance;
var selected_item_id: int = -1;
var current_input_action: int = InputAction.None;
var changed_items: Array = [];
var display_mode: int = PaletteDisplayMode.Thumbnail;
var search_text: String = "";


onready var palette_list := $Palette as ItemList;
onready var no_palette_warning := $NoPaletteWarning as Label;
onready var floor_label := $Toolbar/FloorLabel as Label;
onready var floor_control := $Toolbar/FloorBox as SpinBox;
onready var menu := $Toolbar/MenuButton as MenuButton;
onready var search_box := $SearchBar/Search as LineEdit;
onready var thumbnail_button := $SearchBar/Thumbnail as Button;
onready var list_button := $SearchBar/List as Button;


func _enter_tree() -> void:
	pass;


func _exit_tree() -> void:
	if edit_grid:
		edit_grid.queue_free();
		edit_grid = null;
	
	if cursor:
		cursor.queue_free();
		cursor = null;


func _ready() -> void:
	thumbnail_button.icon = get_icon("FileThumbnail", "EditorIcons");
	list_button.icon = get_icon("FileList", "EditorIcons");
	search_box.right_icon = get_icon("Search", "EditorIcons");
	
	# Menu setup (can't be done in scene)
	var menu_popup := menu.get_popup();
	menu_popup.connect("id_pressed", self, "_menu_option_selected");
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.PreviousLevel), KEY_Q);
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.NextLevel), KEY_E);
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.EditAxis_X), KEY_X);
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.EditAxis_Y), KEY_Y);
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.EditAxis_Z), KEY_Z);


func edit(p_scene_map: SceneMap) -> void:
	if scene_map:
		if scene_map.is_connected("palette_changed", self, "_update_palette"):
			scene_map.disconnect("palette_changed", self, "_update_palette");
		
		if scene_map.is_connected("cell_size_changed", self, "_update_grid"):
			scene_map.disconnect("cell_size_changed", self, "_update_grid");
		
		if scene_map.is_connected("cell_center_changed", self, "_update_grid"):
			scene_map.disconnect("cell_center_changed", self, "_update_grid");
	
	scene_map = p_scene_map;
	
	if scene_map:
		if !scene_map.is_connected("palette_changed", self, "_update_palette"):
			scene_map.connect("palette_changed", self, "_update_palette");
		
		if !scene_map.is_connected("cell_size_changed", self, "_update_grid"):
			scene_map.connect("cell_size_changed", self, "_update_grid");
		
		if !scene_map.is_connected("cell_center_changed", self, "_update_grid"):
			scene_map.connect("cell_center_changed", self, "_update_grid");
		
		_update_palette(scene_map.palette);
	else:
		_update_palette(null);


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
	if !cursor:
		return false;
	
	var frustum := camera.get_frustum();
	var from := camera.project_ray_origin(point);
	var normal := camera.project_ray_normal(point);

	# Convert from global space to the local space of the scene map.
	var to_local_transform = scene_map.global_transform.affine_inverse();
	from = to_local_transform.xform(from);
	normal = to_local_transform.basis.xform(normal).normalized();
	
	var plane := Plane();
	plane.normal[edit_axis] = 1.0;
	plane.d = edit_floor * scene_map.cell_size[edit_axis];
	
	var hit := plane.intersects_segment(from, normal * camera.far);
	if !hit:
		return false;
	
	# Make sure the point is still visible by the camera to avoid painting on areas outside of the camera's view.
	for frustum_plane in frustum:
		var local_plane := to_local_transform.xform(frustum_plane) as Plane;
		if local_plane.is_point_over(hit):
			return false;

	var cell := Vector3();
	for i in range(3):
		if i == edit_axis:
			cell[i] = edit_floor;
		else:
			cell[i] = floor(hit[i] / scene_map.cell_size[i]);
	
	cursor_origin = scene_map.get_global_cell_position(cell);
	_update_cursor_transform();
	
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


func _update_cursor_transform() -> void:
	var transform := Transform();
	transform.origin = cursor_origin;
	transform = scene_map.global_transform * transform;
	
	if cursor:
		cursor.transform = transform;
	
	if edit_grid:
		edit_grid.transform = transform;


func _update_cursor_instance() -> void:
	if cursor:
		cursor.queue_free();
		cursor = null;
	
	if selected_item_id >= 0 && scene_map && scene_map.palette:
		var scene := scene_map.palette.get_item_scene(selected_item_id);
		if scene:
			cursor = scene.instance();
			cursor.name = "Cursor";
			self.add_child(cursor);
		
		_update_cursor_transform();


func _update_palette(palette: ScenePalette) -> void:
	var last_selected_id := selected_item_id;
	
	palette_list.clear();
	
	if !palette:
		search_box.text = "";
		search_box.editable = false;
		no_palette_warning.show();
		palette_list.hide();
		
		selected_item_id = -1;
		_update_cursor_instance();
		_update_grid();
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
	var selected_item_index := -1;
	var previewer := plugin.get_editor_interface().get_resource_previewer();
	for item_id in palette.get_item_ids():
		var name := palette.get_item_name(item_id);
		if !name || name.empty():
			name = "#%s" % item_count;
		
		if !search_text.empty() && !search_text.is_subsequence_ofi(name):
			continue;
		
		if last_selected_id == item_id:
			selected_item_index = item_count;
		
		palette_list.add_item(name);
		palette_list.set_item_metadata(item_count, item_id);
		palette_list.set_item_icon(item_count, get_icon("PackedScene", "EditorIcons"));
		
		var scene := palette.get_item_scene(item_id);
		if scene:
			previewer.queue_resource_preview(scene.resource_path, self, "_thumbnail_result", item_id);
		
		item_count = item_count + 1;
	
	if selected_item_index >= 0:
		palette_list.select(selected_item_index);
		_item_selected(selected_item_index);
	elif selected_item_id >= 0:
		selected_item_id = -1;
		_update_cursor_instance();
		_update_grid();


func _floor_changed(value: float) -> void:
	edit_floor = value;


func _item_selected(index: int) -> void:
	var item_id := palette_list.get_item_metadata(index) as int;
	
	if selected_item_id != item_id:
		selected_item_id = item_id;
		_update_cursor_instance();
		_update_grid();


func _menu_option_selected(option_id: int) -> void:
	match option_id:
		MenuOption.PreviousLevel:
			floor_control.value -= 1;
		MenuOption.NextLevel:
			floor_control.value += 1;
		MenuOption.EditAxis_X, MenuOption.EditAxis_Y, MenuOption.EditAxis_Z:
			var base_option := MenuOption.EditAxis_X as int;
			var new_axis := option_id - base_option;
			
			# Check the newly selected option
			for i in range(3):
				var idx := menu.get_popup().get_item_index(base_option + i);
				menu.get_popup().set_item_checked(idx, i == new_axis);
			
			# Update the text of the floor selector to match the current edit mode.
			var next_level_item := menu.get_popup().get_item_index(MenuOption.NextLevel);
			var prev_level_item := menu.get_popup().get_item_index(MenuOption.PreviousLevel);
			
			if new_axis == Vector3.AXIS_Y:
				menu.get_popup().set_item_text(next_level_item, tr("Next Floor"));
				menu.get_popup().set_item_text(prev_level_item, tr("Previous Floor"));
				floor_label.text = tr("Floor:");
			else:
				menu.get_popup().set_item_text(next_level_item, tr("Next Plane"));
				menu.get_popup().set_item_text(prev_level_item, tr("Previous Plane"));
				floor_label.text = tr("Plane:");
			
			edit_axis = new_axis;
			_update_grid();


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


func _search_text_changed(new_text: String) -> void:
	if search_text == new_text:
		return;
	
	search_text = new_text.strip_edges() if new_text else "";
	_update_palette(scene_map.palette);


func _update_grid() -> void:
	if edit_grid:
		edit_grid.queue_free();
		edit_grid = null;
	
	if selected_item_id < 0 || !scene_map || !scene_map.palette || is_equal_approx(scene_map.cell_size[edit_axis], 0.0):
		return;
	
	var offset := Vector3();
	if scene_map.cell_center_x:
		offset.x -= 0.5;
	if scene_map.cell_center_y:
		offset.y -= 0.5;
	if scene_map.cell_center_z:
		offset.z -= 0.5;
	offset *= scene_map.cell_size;
	
	var grid_material := preload("grid_material.tres") as ShaderMaterial;
	var surface_tool := SurfaceTool.new();
	surface_tool.begin(Mesh.PRIMITIVE_LINES);
	surface_tool.set_material(grid_material);
	
	var radius := 64;
	match edit_axis:
		Vector3.AXIS_X:
			for i in range(-radius, radius + 1, scene_map.cell_size.z):
				surface_tool.add_vertex(Vector3(0, -radius, i) + offset);
				surface_tool.add_vertex(Vector3(0, radius, i) + offset);
			for i in range(-radius, radius + 1, scene_map.cell_size.y):
				surface_tool.add_vertex(Vector3(0, i, -radius) + offset);
				surface_tool.add_vertex(Vector3(0, i, radius) + offset);
		Vector3.AXIS_Y:
			for i in range(-radius, radius + 1, scene_map.cell_size.z):
				surface_tool.add_vertex(Vector3(-radius, 0, i) + offset);
				surface_tool.add_vertex(Vector3(radius, 0, i) + offset);
			for i in range(-radius, radius + 1, scene_map.cell_size.x):
				surface_tool.add_vertex(Vector3(i, 0, -radius) + offset);
				surface_tool.add_vertex(Vector3(i, 0, radius) + offset);
		Vector3.AXIS_Z:
			for i in range(-radius, radius + 1, scene_map.cell_size.y):
				surface_tool.add_vertex(Vector3(-radius, i, 0) + offset);
				surface_tool.add_vertex(Vector3(radius, i, 0) + offset);
			for i in range(-radius, radius + 1, scene_map.cell_size.x):
				surface_tool.add_vertex(Vector3(i, -radius, 0) + offset);
				surface_tool.add_vertex(Vector3(i, radius, 0) + offset);
	
	var mesh := surface_tool.commit();
	edit_grid = MeshInstance.new();
	edit_grid.mesh = mesh;
	edit_grid.layers = 1 << 25;
	self.add_child(edit_grid);
	
	_update_cursor_transform();


class ChangeItem:
	var coordinates: Vector3;
	var newItem: int;
	var oldItem: int;
