tool
extends MenuButton

# ******************************************************************************

onready var popup:PopupMenu = get_popup()
var callbacks := {}

signal item_selected(item)

# ******************************************************************************

func _ready() -> void:
	popup.connect('index_pressed', self, '_on_index_pressed')

func create_submenu(label:String, submenu_name:String) -> PopupMenu:
	var submenu:PopupMenu = PopupMenu.new()
	submenu.name = submenu_name
	submenu.connect('index_pressed', self, '_on_index_pressed', [submenu_name])
	popup.add_child(submenu)
	popup.add_submenu_item(label, submenu_name)
	return submenu

func add_item(label: String, cb:=[]) -> void:
	popup.add_item(label)

	if cb:
		callbacks[label] = cb

func add_submenu_item(label:String, submenu_name:String, cb:=[]) -> void:
	var submenu:PopupMenu = popup.get_node(submenu_name)
	submenu.add_item(label)
	
	if cb:
		callbacks[submenu_name + '/' + label] = cb

func _on_index_pressed(idx:int, submenu_name:='') -> void:
	var menu = popup
	var item = ''
	if submenu_name:
		menu = popup.get_node(submenu_name)
		item += menu.name + '/'
	item += menu.get_item_text(idx)

	if item in callbacks:
		var cb = callbacks[item]
		var obj = cb[0]
		var method = cb[1]
		if obj.has_method(method):
			if len(cb) == 2:
				obj.call(method)
			if len(cb) == 3:
				obj.call(method, cb[2])

	emit_signal('item_selected', item)
