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
	Tree.connect('card_selected', self, 'card_selected')
	Tree.connect('card_renamed', self, 'card_renamed')
	
	DialogFontMinus.connect('pressed', self, 'dialog_font_minus')
	DialogFontPlus.connect('pressed', self, 'dialog_font_plus')

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

func card_selected(path):
	pass
	# print('conversation_selected: ', path)

func card_renamed(old, new):
	pass
	# prints('card_renamed:', old, new)

# ******************************************************************************

func character_added(path):
	var char_map = Diagraph.load_json(Diagraph.character_map_path, {})
	var c = load(path).instance()
	char_map[c.name] = path
	Diagraph.save_json(Diagraph.character_map_path, char_map)
	Diagraph.refresh()

# ******************************************************************************

func run():
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
