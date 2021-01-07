tool
extends HBoxContainer


const ScenePalette = preload("../scene_palette.gd");
const ADD_ITEM = 0;
const REMOVE_ITEM = 1;


var palette: ScenePalette;
var menu_button: MenuButton;


func _ready() -> void:
	menu_button = $Menu as MenuButton;
	menu_button.get_popup().connect("id_pressed", self, "_menu_item_selected");


func edit(p_palette: ScenePalette) -> void:
	palette = p_palette;


func _menu_item_selected(option_id: int) -> void:
	match option_id:
		ADD_ITEM:
			palette.create_item(palette.get_next_available_id());
		REMOVE_ITEM:
			pass;
