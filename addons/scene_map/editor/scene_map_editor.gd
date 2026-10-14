@tool
extends EditorDock


const SceneMap = preload("../scene_map.gd")
const ScenePalette = preload("../scene_palette.gd")
const RotateStep = PI / 4.0 # 45 degrees


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
	EditAxis_Z,
	Rotate_Clockwise,
	Rotate_Counter_Clockwise,
	Rotate_Reset,
	LayerUp,
	LayerDown
}


var plugin: EditorPlugin
var scene_map: SceneMap
var cursor: Node3D
var cursor_origin: Vector3
var cursor_rotation: Basis
var edit_axis: int = Vector3.AXIS_Y
var edit_floor: int = 0
var edit_grid: MeshInstance3D
var edit_layer : int = 0
var selected_item_id: int = -1
var current_input_action: int = InputAction.None
var changed_items: Array[ChangeItem] = []
var display_mode: int = PaletteDisplayMode.Thumbnail
var search_text: String = ""


@onready var palette_list := $Layout/Scroll/Palette as ItemList
@onready var no_palette_warning := $Layout/NoPaletteWarning as Label
@onready var floor_label := $Layout/Toolbar/FloorContainer/FloorLabel as Label
@onready var floor_control := $Layout/Toolbar/FloorContainer/FloorBox as SpinBox
@onready var layer_control := $Layout/Toolbar/LayerContainer/LayerBox as SpinBox
@onready var menu := $Layout/Toolbar/MenuButton as MenuButton
@onready var search_box := $Layout/SearchBar/Search as LineEdit
@onready var thumbnail_button := $Layout/SearchBar/Thumbnail as Button
@onready var list_button := $Layout/SearchBar/List as Button



func _enter_tree() -> void:
	pass


func _exit_tree() -> void:
	if edit_grid:
		edit_grid.queue_free()
		edit_grid = null
	
	if cursor:
		cursor.queue_free()
		cursor = null


func _ready() -> void:
	thumbnail_button.icon = EditorInterface.get_editor_theme().get_icon("FileThumbnail", "EditorIcons")
	list_button.icon = EditorInterface.get_editor_theme().get_icon("FileList", "EditorIcons")
	search_box.right_icon = EditorInterface.get_editor_theme().get_icon("Search", "EditorIcons")
	
	# Menu setup (can't be done in scene)
	var menu_popup := menu.get_popup()
	menu_popup.id_pressed.connect(_menu_option_selected)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.PreviousLevel), KEY_Q)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.NextLevel), KEY_E)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.EditAxis_X), KEY_X)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.EditAxis_Y), KEY_Y)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.EditAxis_Z), KEY_Z)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.Rotate_Clockwise), KEY_D)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.Rotate_Counter_Clockwise), KEY_A)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.Rotate_Reset), KEY_S)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.LayerUp), KEY_R)
	menu_popup.set_item_accelerator(menu_popup.get_item_index(MenuOption.LayerDown), KEY_F)


func edit(p_scene_map: SceneMap) -> void:
	if scene_map:
		if scene_map.palette_changed.is_connected(_update_palette):
			scene_map.palette_changed.disconnect(_update_palette)
		
		if scene_map.cell_size_changed.is_connected(_update_grid):
			scene_map.cell_size_changed.disconnect(_update_grid)
		
		if scene_map.cell_center_changed.is_connected(_update_grid):
			scene_map.cell_center_changed.disconnect(_update_grid)
		
		if scene_map.layer_removed.is_connected(_update_layer):
			scene_map.layer_removed.disconnect(_update_layer)
	
	scene_map = p_scene_map
	
	if scene_map:
		if not scene_map.palette_changed.is_connected(_update_palette):
			scene_map.palette_changed.connect(_update_palette)
		
		if not scene_map.cell_size_changed.is_connected(_update_grid):
			scene_map.cell_size_changed.connect(_update_grid)
		
		if not scene_map.cell_center_changed.is_connected(_update_grid):
			scene_map.cell_center_changed.connect(_update_grid)
		
		if not scene_map.layer_removed.is_connected(_update_layer):
			scene_map.layer_removed.connect(_update_layer)
		
		_update_palette(scene_map.palette)
	else:
		_update_palette(null)


func handle_spatial_input(camera: Camera3D, event: InputEvent) -> int:
	if !scene_map || !scene_map.palette || !scene_map.layers:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	var undo_redo := plugin.get_undo_redo()
	
	var click_event := event as InputEventMouseButton
	if click_event:
		if click_event.button_index == MOUSE_BUTTON_WHEEL_UP && click_event.shift_pressed:
			if click_event.pressed:
				floor_control.value += click_event.factor
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		elif click_event.button_index == MOUSE_BUTTON_WHEEL_DOWN && click_event.shift_pressed:
			if click_event.pressed:
				floor_control.value -= click_event.factor
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		
		if click_event.pressed:
			if click_event.button_index == MOUSE_BUTTON_LEFT:
				current_input_action = InputAction.Paint
			elif click_event.button_index == MOUSE_BUTTON_RIGHT:
				current_input_action = InputAction.Erase
			else:
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			
			return _handle_input(camera, click_event.position)
		else:
			if (click_event.button_index == MOUSE_BUTTON_LEFT && current_input_action == InputAction.Paint) \
			|| (click_event.button_index == MOUSE_BUTTON_RIGHT && current_input_action == InputAction.Erase):
				if changed_items:
					var action := "SceneMap Paint" if current_input_action == InputAction.Paint else "SceneMap Erase"
					undo_redo.create_action(action)
					
					for i in range(changed_items.size()):
						var item : ChangeItem = changed_items[i]
						undo_redo.add_do_method(scene_map, "set_cell_item", item.coordinates, item.new_item, item.layer, item.new_orientation)
						item = changed_items[changed_items.size() - 1 - i]
						undo_redo.add_undo_method(scene_map, "set_cell_item", item.coordinates, item.old_item, item.layer, item.old_orientation)
					
					undo_redo.commit_action(false)
					
					changed_items = []
					current_input_action = InputAction.None
					return EditorPlugin.AFTER_GUI_INPUT_STOP
			
			current_input_action = InputAction.None
	
	var move_event := event as InputEventMouseMotion
	if move_event:
		return _handle_input(camera, move_event.position)
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _handle_input(camera: Camera3D, point: Vector2) -> int:
	if !cursor:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	var frustum := camera.get_frustum()
	var from := camera.project_ray_origin(point)
	var normal := camera.project_ray_normal(point)

	# Convert from global space to the local space of the scene map.
	var to_local_transform = scene_map.global_transform.affine_inverse()
	from = to_local_transform * from
	normal = (to_local_transform.basis * normal).normalized()
	
	var plane := Plane()
	plane.normal[edit_axis] = 1.0
	plane.d = edit_floor * scene_map.layers[edit_layer].cell_size[edit_axis]
	
	var hit := plane.intersects_segment(from, normal * camera.far)
	if !hit:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	
	# Make sure the point is still visible by the camera to avoid painting on areas outside of the camera's view.
	for frustum_plane in frustum:
		var local_plane := (to_local_transform * frustum_plane) as Plane
		if local_plane.is_point_over(hit):
			return EditorPlugin.AFTER_GUI_INPUT_PASS

	var cell := Vector3()
	for i in range(3):
		if i == edit_axis:
			cell[i] = edit_floor
		else:
			cell[i] = floor(hit[i] / scene_map.layers[edit_layer].cell_size[i])
	
	cursor_origin = scene_map.get_cell_position(cell, edit_layer)
	_update_cursor_transform()
	_update_edit_grid_transform()
	
	match current_input_action:
		InputAction.Paint:
			var change := ChangeItem.new()
			change.coordinates = cell
			change.old_item = scene_map.get_cell_item_id(cell, edit_layer)
			change.old_orientation = scene_map.get_cell_item_orientation(cell, edit_layer)
			change.new_item = selected_item_id
			change.new_orientation = cursor_rotation.get_rotation_quaternion()
			change.layer = edit_layer
			
			# Prevent duplicate changes
			var last_item := changed_items[-1] if changed_items.size() > 0 else null
			if last_item and last_item.layer == change.layer and last_item.coordinates == change.coordinates and last_item.new_item==change.new_item and last_item.new_orientation == change.new_orientation:
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			if change.old_item == change.new_item and change.old_orientation == change.new_orientation:
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			
			changed_items.append(change)
			scene_map.set_cell_item(change.coordinates, change.new_item, change.layer, change.new_orientation)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		InputAction.Erase:
			var change := ChangeItem.new()
			change.coordinates = cell
			change.old_item = scene_map.get_cell_item_id(cell, edit_layer)
			change.old_orientation = scene_map.get_cell_item_orientation(cell, edit_layer)
			change.new_item = -1
			change.new_orientation = Quaternion.IDENTITY
			change.layer = edit_layer
			
			# Prevent duplicate changes
			var last_item := changed_items[-1] if changed_items.size() > 0 else null
			if last_item and last_item.layer == change.layer and last_item.coordinates == change.coordinates and last_item.new_item==change.new_item and last_item.new_orientation == change.new_orientation:
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			if change.old_item == change.new_item and change.old_orientation == change.new_orientation:
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			
			changed_items.append(change)
			scene_map.set_cell_item(change.coordinates, change.new_item, change.layer, change.new_orientation)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
	
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _update_cursor_transform() -> void:
	var transform := Transform3D(cursor_rotation)
	transform.origin = cursor_origin
	transform = scene_map.global_transform * transform
	
	if cursor:
		cursor.transform = transform


func _update_edit_grid_transform() -> void:
	var transform := Transform3D()
	transform.origin = cursor_origin
	transform = scene_map.global_transform * transform

	if edit_grid:
		edit_grid.transform = transform


func _update_cursor_instance() -> void:
	if cursor:
		cursor.queue_free()
		cursor = null
	
	if selected_item_id >= 0 && scene_map && scene_map.palette:
		var scene := scene_map.palette.get_item_scene(selected_item_id)
		if scene:
			cursor = scene.instantiate()
			cursor.name = "Cursor"
			self.add_child(cursor)
		
		_update_cursor_transform()


func _update_palette(palette: ScenePalette) -> void:
	var last_selected_id := selected_item_id
	
	palette_list.clear()
	
	if not palette:
		search_box.text = ""
		search_box.editable = false
		no_palette_warning.show()
		palette_list.hide()
		
		selected_item_id = -1
		_update_cursor_instance()
		_update_grid()
		return
	
	search_box.editable = true
	no_palette_warning.hide()
	palette_list.show()
	
	match display_mode:
		PaletteDisplayMode.Thumbnail:
			palette_list.max_columns = 0
			palette_list.icon_mode = ItemList.ICON_MODE_TOP
			palette_list.fixed_column_width = 64
			palette_list.fixed_icon_size = Vector2(64, 64)
		PaletteDisplayMode.List:
			palette_list.max_columns = 1
			palette_list.icon_mode = ItemList.ICON_MODE_LEFT
			palette_list.fixed_column_width = 0
			palette_list.fixed_icon_size = Vector2.ZERO
	
	#var item_count = 0
	var selected_item_index := -1
	var previewer := plugin.get_editor_interface().get_resource_previewer()
	for item_id in palette.item_map.size():
		var name := palette.get_item_name(item_id)
		if not name:
			name = "#%s" % item_id
		
		if not search_text and not search_text.is_subsequence_of(name):
			continue
		
		if last_selected_id == item_id:
			selected_item_index = item_id
		
		palette_list.add_item(name)
		palette_list.set_item_metadata(item_id, item_id)
		palette_list.set_item_icon(item_id, EditorInterface.get_editor_theme().get_icon("PackedScene", "EditorIcons"))
		
		var scene := palette.get_item_scene(item_id)
		if scene:
			previewer.queue_resource_preview(scene.resource_path, self, "_thumbnail_result", item_id)
	
	if selected_item_index >= 0:
		palette_list.select(selected_item_index)
		_item_selected(selected_item_index)
	elif selected_item_id >= 0:
		selected_item_id = -1
		_update_cursor_instance()
		_update_grid()


func _floor_changed(value: float) -> void:
	edit_floor = value


func _layer_changed(value: float) -> void:
	if value >= scene_map.layers.size():
		layer_control.value = scene_map.layers.size()-1
		edit_layer = scene_map.layers.size()-1
		return
	edit_layer = value


func _item_selected(index: int) -> void:
	var item_id := palette_list.get_item_metadata(index) as int
	
	if selected_item_id != item_id:
		selected_item_id = item_id
		_update_cursor_instance()
		_update_grid()


func _menu_option_selected(option_id: int) -> void:
	match option_id:
		MenuOption.PreviousLevel:
			floor_control.value -= 1
		MenuOption.NextLevel:
			floor_control.value += 1
		MenuOption.EditAxis_X, MenuOption.EditAxis_Y, MenuOption.EditAxis_Z:
			var base_option := MenuOption.EditAxis_X as int
			var new_axis := option_id - base_option
			
			# Check the newly selected option
			for i in range(3):
				var idx := menu.get_popup().get_item_index(base_option + i)
				menu.get_popup().set_item_checked(idx, i == new_axis)
			
			# Update the text of the floor selector to match the current edit mode.
			var next_level_item := menu.get_popup().get_item_index(MenuOption.NextLevel)
			var prev_level_item := menu.get_popup().get_item_index(MenuOption.PreviousLevel)
			
			if new_axis == Vector3.AXIS_Y:
				menu.get_popup().set_item_text(next_level_item, tr("Next Floor"))
				menu.get_popup().set_item_text(prev_level_item, tr("Previous Floor"))
				floor_label.text = tr("Floor:")
			else:
				menu.get_popup().set_item_text(next_level_item, tr("Next Plane"))
				menu.get_popup().set_item_text(prev_level_item, tr("Previous Plane"))
				floor_label.text = tr("Plane:")
			
			# Try to keep the cursor in the same location in the new axis
			edit_axis = new_axis
			floor_control.value = floor(cursor_origin[edit_axis] / scene_map.layers[edit_layer].cell_size[edit_axis])
			
			_update_grid()
		MenuOption.Rotate_Clockwise, MenuOption.Rotate_Counter_Clockwise:
			var clockwise: bool = option_id == MenuOption.Rotate_Clockwise
			var axis := Vector3()
			axis[edit_axis] = 1.0
			
			cursor_rotation = cursor_rotation.rotated(axis, -RotateStep if clockwise else RotateStep)
			_update_cursor_transform()
		MenuOption.Rotate_Reset:
			cursor_rotation = Basis.IDENTITY
			_update_cursor_transform()


func _set_display_mode(mode: int) -> void:
	if display_mode == mode:
		return
	
	display_mode = mode
	
	match display_mode:
		PaletteDisplayMode.Thumbnail:
			thumbnail_button.set_pressed_no_signal(true)
			list_button.set_pressed_no_signal(false)
		PaletteDisplayMode.List:
			thumbnail_button.set_pressed_no_signal(false)
			list_button.set_pressed_no_signal(true)
	
	_update_palette(scene_map.palette)


func _thumbnail_result(path: String, preview: Texture, small_preview: Texture, user_data: int) -> void:
	if !preview:
		return
	
	for i in range(palette_list.get_item_count()):
		var item_id := palette_list.get_item_metadata(i) as int
		if item_id == user_data:
			palette_list.set_item_icon(i, preview)


func _search_text_changed(new_text: String) -> void:
	if search_text == new_text:
		return
	
	search_text = new_text.strip_edges() if new_text else ""
	_update_palette(scene_map.palette)


func _update_grid() -> void:
	if edit_grid:
		edit_grid.queue_free()
		edit_grid = null
	
	if selected_item_id < 0 || !scene_map || !scene_map.palette || scene_map.layers.size() <= edit_layer || is_equal_approx(scene_map.layers[edit_layer].cell_size[edit_axis], 0.0):
		return
	
	var offset := Vector3()
	if scene_map.layers[edit_layer].center_x:
		offset.x -= 0.5
	if scene_map.layers[edit_layer].center_y:
		offset.y -= 0.5
	if scene_map.layers[edit_layer].center_z:
		offset.z -= 0.5
	offset *= scene_map.layers[edit_layer].cell_size
	
	var grid_material := preload("grid_material.tres") as ShaderMaterial
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_LINES)
	surface_tool.set_material(grid_material)
	
	var radius := 64
	match edit_axis:
		Vector3.AXIS_X:
			for i in range(-radius, radius + 1, scene_map.layers[edit_layer].cell_size.z):
				surface_tool.add_vertex(Vector3(0, -radius, i) + offset)
				surface_tool.add_vertex(Vector3(0, radius, i) + offset)
			for i in range(-radius, radius + 1, scene_map.layers[edit_layer].cell_size.y):
				surface_tool.add_vertex(Vector3(0, i, -radius) + offset)
				surface_tool.add_vertex(Vector3(0, i, radius) + offset)
		Vector3.AXIS_Y:
			for i in range(-radius, radius + 1, scene_map.layers[edit_layer].cell_size.z):
				surface_tool.add_vertex(Vector3(-radius, 0, i) + offset)
				surface_tool.add_vertex(Vector3(radius, 0, i) + offset)
			for i in range(-radius, radius + 1, scene_map.layers[edit_layer].cell_size.x):
				surface_tool.add_vertex(Vector3(i, 0, -radius) + offset)
				surface_tool.add_vertex(Vector3(i, 0, radius) + offset)
		Vector3.AXIS_Z:
			for i in range(-radius, radius + 1, scene_map.layers[edit_layer].cell_size.y):
				surface_tool.add_vertex(Vector3(-radius, i, 0) + offset)
				surface_tool.add_vertex(Vector3(radius, i, 0) + offset)
			for i in range(-radius, radius + 1, scene_map.layers[edit_layer].cell_size.x):
				surface_tool.add_vertex(Vector3(i, -radius, 0) + offset)
				surface_tool.add_vertex(Vector3(i, radius, 0) + offset)
	
	var mesh := surface_tool.commit()
	edit_grid = MeshInstance3D.new()
	edit_grid.mesh = mesh
	edit_grid.layers = 1 << 25
	self.add_child(edit_grid)
	
	_update_edit_grid_transform()


func _update_layer() -> void:
	if edit_layer >= scene_map.layers.size():
		edit_layer = scene_map.layers.size()-1
		layer_control.value = edit_layer
	return


class ChangeItem:
	var coordinates: Vector3
	var new_item: int = -1
	var new_orientation: Quaternion = Quaternion.IDENTITY
	var old_item: int = -1
	var old_orientation: Quaternion = Quaternion.IDENTITY
	var layer : int = 0
