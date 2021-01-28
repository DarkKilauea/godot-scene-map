tool
extends Control


const SceneMap = preload("../scene_map.gd");
const ScenePalette = preload("../scene_palette.gd");


var scene_map: SceneMap;
var cursor: MeshInstance;


onready var palette_list := $Palette as ItemList;
onready var no_palette_warning := $NoPaletteWarning as Label;


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
	
	var move_event := event as InputEventMouseMotion;
	if move_event:
		_update_cursor_location(camera, move_event.position);
		return false;
	
	return false;


func _update_cursor_location(camera: Camera, point: Vector2) -> void:
	var from := camera.project_ray_origin(point);
	var normal := camera.project_ray_normal(point);
	
	var plane := Plane.PLANE_XZ;
	var hit := plane.intersects_ray(from, normal);
	if !hit:
		return;
	
	var cell := (hit / scene_map.cell_size).floor();
	var cell_location := cell;
	
	if scene_map.cell_center_x:
		cell_location.x += 0.5;
	if scene_map.cell_center_y:
		cell_location.y += 0.5;
	if scene_map.cell_center_z:
		cell_location.z += 0.5;
	
	cell_location *= scene_map.cell_size;
	
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
