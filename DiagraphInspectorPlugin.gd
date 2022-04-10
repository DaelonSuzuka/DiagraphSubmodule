tool
extends EditorInspectorPlugin

# ******************************************************************************

var plugin: EditorPlugin = null

# ******************************************************************************

var selected_object: Node
var ep = null
var select_button = null
var edit_button = null

func can_handle(object):
	selected_object = null
	return object is Node and object.get('conversation') != null

func parse_property(object, type, path, hint, hint_text, usage) -> bool:
	if path == 'conversation':
		selected_object = object
		add_control()

	return false

func add_control():
	ep = EditorProperty.new()
	var hbox = HBox.new()

	select_button = hbox.add(Button.new())
	select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_button.text = 'Select'
	select_button.connect('pressed', self, 'select_conversation')

	edit_button = hbox.add(Button.new())
	edit_button.text = 'Show'
	edit_button.connect('pressed', self, 'open_conversation')

	ep.add_child(hbox)
	ep.label = 'Conversation'
	
	add_custom_control(ep)

var selector = null
var tree = null
var root = null

func select_conversation():
	if selector:
		selector.queue_free()
		selector = null
		tree = null
		root = null

	selector = ConfirmationDialog.new()
	selector.window_title = 'Select a Conversation'

	tree = Tree.new()
	tree.hide_root = true
	root = tree.create_item()
	for name in Diagraph.conversations:
		var item = tree.create_item(root)
		item.set_text(0, name)

		for node in Diagraph.load_conversation(name, {}).values():
			var _item = tree.create_item(item)
			_item.set_text(0, node.name)

	tree.anchor_right = 1.0
	tree.anchor_bottom = 1.0
	selector.add_child(tree)

	plugin.get_editor_interface().get_editor_viewport().add_child(selector)
	selector.get_ok().connect('pressed', self, 'accepted')
	selector.popup_centered(Vector2(1000, 985))

func accepted():
	var item = tree.get_selected()
	var parent = item.get_parent()
	var path = ''
	if parent == root:
		selected_object.conversation = item.get_text(0)
		selected_object.entry = ''
	else:
		selected_object.conversation = parent.get_text(0)
		selected_object.entry = item.get_text(0)

	plugin.get_editor_interface().get_inspector().refresh()

func open_conversation():
	var obj = selected_object
	var convo = '%s:%s:%d' % [obj.conversation, obj.entry, obj.line]
	plugin.show_conversation(convo)

# ******************************************************************************
# Custom container classes

class HBox extends HBoxContainer:
	func add(object):
		add_child(object)
		return object
