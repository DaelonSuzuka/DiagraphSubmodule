tool
extends EditorInspectorPlugin

# ******************************************************************************

var plugin = null

# ******************************************************************************

var selected_object: Node
var ep = null
var button = null

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

	button = hbox.add(Button.new())
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = 'Open Conversation'
	button.connect('pressed', self, 'pressed')

	ep.add_child(hbox)
	ep.label = 'Conversation'
	
	add_custom_control(ep)
	
func pressed():
	var obj = selected_object
	var convo = '%s:%s:%d' % [obj.conversation, obj.entry, obj.line]
	plugin.show_conversation(convo)

# ******************************************************************************
# Custom container classes

class HBox extends HBoxContainer:
	func add(object):
		add_child(object)
		return object
