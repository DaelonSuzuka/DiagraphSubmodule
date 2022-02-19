tool
extends Control

# ******************************************************************************

onready var GraphEdit: GraphEdit = find_node('GraphEdit')
onready var Tree: Tree = find_node('Tree')
onready var Run = find_node('Run')
onready var Stop = find_node('Stop')
onready var Next = find_node('Next')
onready var Debug = find_node('Debug')
onready var Preview = find_node('Preview')
onready var DialogFontMinus = find_node('DialogFontMinus')
onready var DialogFontPlus = find_node('DialogFontPlus')
onready var GraphToolbar = find_node('GraphToolbar')
onready var DialogBox = find_node('DialogBox')
onready var ToggleRightPanel = find_node('ToggleRightPanel')
onready var ToggleLeftPanel = find_node('ToggleLeftPanel')
onready var LeftPanelSplit: HSplitContainer = find_node('LeftPanelSplit')
onready var SettingsMenu:MenuButton = find_node('SettingsMenu')

var is_plugin = false
var current_conversation := ''
var editor_data := {}

# ******************************************************************************

func _ready():
	Run.connect('pressed', self, 'run')
	Stop.connect('pressed', self, 'stop')
	Next.connect('pressed', self, 'next')
	Debug.connect('toggled', $Preview/DialogBox/DebugLog, 'set_visible')
	DialogBox.connect('done', self, 'stop')

	Preview.hide()

	Tree.connect('conversation_changed', self, 'change_conversation')
	Tree.connect('conversation_selected', self, 'conversation_selected')
	Tree.connect('conversation_created', self, 'create_conversation')
	Tree.connect('conversation_deleted', self, 'delete_conversation')
	Tree.connect('conversation_renamed', self, 'rename_conversation')
	Tree.connect('card_selected', GraphEdit, 'select_node')
	Tree.connect('card_focused', self, 'focus_card')
	Tree.connect('card_renamed', GraphEdit, 'rename_node')
	Tree.connect('card_deleted', GraphEdit, 'delete_node')
	
	DialogFontMinus.connect('pressed', self, 'dialog_font_minus')
	DialogFontPlus.connect('pressed', self, 'dialog_font_plus')

	ToggleLeftPanel.connect('pressed', self, 'toggle_left_panel')

	GraphEdit.connect('node_renamed', self, 'node_renamed')
	GraphEdit.connect('node_created', self, 'node_created')
	GraphEdit.connect('node_deleted', self, 'node_deleted')
	GraphEdit.connect('node_selected', self, 'node_selected')

	SettingsMenu.add_check_item('Scroll While Zooming', [GraphEdit, 'set_zoom_scroll'])
	var sub = SettingsMenu.create_submenu('Set Font Size', 'FontSize')
	sub.hide_on_item_selection = false
	SettingsMenu.add_submenu_item('Font Size Reset', 'FontSize', [self, 'reset_font_size'])
	SettingsMenu.add_submenu_item('Font Size +', 'FontSize', [self, 'set_font_size', 1])
	SettingsMenu.add_submenu_item('Font Size -', 'FontSize', [self, 'set_font_size', -1])

	if !Engine.editor_hint or is_plugin:
		load_editor_data()
		var zoom_hbox = GraphEdit.get_zoom_hbox()
		var zoom_container = GraphToolbar.get_node('HBox/ZoomContainer')
		zoom_hbox.get_parent().remove_child(zoom_hbox)
		zoom_container.add_child(zoom_hbox)

	$AutoSave.connect('timeout', self, 'autosave')

func autosave():
	save_conversation()
	save_editor_data()

func toggle_left_panel():
	LeftPanelSplit.collapsed = !LeftPanelSplit.collapsed

func reset_font_size():
	theme.default_font.size = 12

func set_font_size(amount):
	theme.default_font.size += amount

func dialog_font_minus():
	DialogBox.theme.default_font.size -= 1

func dialog_font_plus():
	DialogBox.theme.default_font.size += 1

# ******************************************************************************

func save_conversation():
	if !current_conversation:
		return
	var nodes = GraphEdit.get_nodes()
	var path = Diagraph.name_to_path(current_conversation)
	Diagraph.save_json(path, nodes)

func change_conversation(path):
	save_conversation()
	save_editor_data()
	load_conversation(path)

	var parts = path.split(':')
	if len(parts) > 1:
		GraphEdit.focus_node(parts[1])

func load_conversation(path):
	var parts = path.split(':')
	var name = parts[0]
	if current_conversation == name:
		return
	GraphEdit.clear()
	current_conversation = name

	if name in editor_data:
		GraphEdit.set_data(editor_data[name])
	else:
		editor_data[name] = {}
	var nodes = Diagraph.load_json(Diagraph.name_to_path(name), {})
	if nodes:
		GraphEdit.set_nodes(nodes)

func create_conversation(path):
	GraphEdit.clear()
	current_conversation = path
	Diagraph.refresh()

func delete_conversation(path):
	if current_conversation == path:
		GraphEdit.clear()
		current_conversation = ''
	editor_data.erase(path)
	save_editor_data()
	var dir = Directory.new()
	dir.remove(Diagraph.prefix + Diagraph.name_to_path(path))
	Diagraph.refresh()

func rename_conversation(old, new):
	if current_conversation == old:
		GraphEdit.clear()
		current_conversation = ''
	editor_data[new] = editor_data[old]
	editor_data.erase(old)
	save_editor_data()
	var dir = Directory.new()
	var old_path = Diagraph.prefix + Diagraph.name_to_path(old)
	var new_path = Diagraph.prefix + Diagraph.name_to_path(new)
	dir.rename(old_path, new_path)
	load_conversation(new)
	Diagraph.refresh()

func conversation_selected(path):
	pass
	# print('conversation_selected: ', path)

func focus_card(path):
	var parts = path.split(':')
	if parts[0] != current_conversation:
		save_conversation()
		save_editor_data()
		load_conversation(parts[0])
	if len(parts) > 1:
		GraphEdit.focus_node(parts[1])

func node_selected(node):
	var path = current_conversation + '/' + node.data.name
	Tree.select_item(path)

func node_deleted(id):
	save_conversation()
	Tree.delete_item(id)

func node_renamed(old, new):
	save_conversation()
	Tree.refresh()

func node_created(path):
	save_conversation()
	Tree.refresh()

func select_card(path):
	prints('select_card', path)

# ******************************************************************************

func character_added(path):
	var char_map = Diagraph.load_json(Diagraph.character_map_path, {})
	var c = load(path).instance()
	char_map[c.name] = path
	Diagraph.save_json(Diagraph.character_map_path, char_map)
	Diagraph.refresh()

# ******************************************************************************

func run():
	Diagraph.load_characters()
	var selection = GraphEdit.get_selected_nodes()
	if selection.size() == 1:
		var node = selection[0]
		save_conversation()
		save_editor_data()
		$Preview.show()
		DialogBox.start(current_conversation + ':' + node.name)
	
func stop():
	$Preview.hide()

func next():
	DialogBox.next()

# ******************************************************************************

var editor_data_file_name = 'user://editor_data.json'

func save_editor_data():
	if !current_conversation:
		return
	editor_data['current_conversation'] = current_conversation
	editor_data['font_size'] = theme.default_font.size
	editor_data['zoom_scroll'] = GraphEdit.zoom_scroll
	editor_data['left_panel_size'] = LeftPanelSplit.split_offset
	editor_data['left_panel_collapsed'] = LeftPanelSplit.collapsed
	editor_data[current_conversation] = GraphEdit.get_data()
	Diagraph.save_json(editor_data_file_name, editor_data)

func load_editor_data():
	var data = Diagraph.load_json(editor_data_file_name)
	if !data:
		editor_data['current_conversation'] = '0 Introduction'
		load_conversation(editor_data['current_conversation'])
		return
	editor_data = data
	if 'current_conversation' in editor_data:
		load_conversation(editor_data['current_conversation'])

	if 'font_size' in editor_data:
		theme.default_font.size = editor_data['font_size']

	if 'zoom_scroll' in editor_data:
		var state = editor_data['zoom_scroll']
		GraphEdit.zoom_scroll = state
		SettingsMenu.set_item_checked('Scroll While Zooming', state)

	if 'left_panel_size' in editor_data:
		LeftPanelSplit.split_offset = editor_data['left_panel_size']
	if 'left_panel_collapsed' in editor_data:
		LeftPanelSplit.collapsed = editor_data['left_panel_collapsed']
