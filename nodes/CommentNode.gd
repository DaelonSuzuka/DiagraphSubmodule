tool
extends 'BaseNode.gd'

# ******************************************************************************

onready var ColorPicker = find_node('ColorPickerButton')

# ******************************************************************************

func _ready():
	ColorPicker.get_picker()
	ColorPicker.get_popup()
	ColorPicker.connect('color_changed', self, 'set_self_modulate')

	connect('dragged', self, 'dragged')
	connect('offset_changed', self, 'offset_changed')

	# required because 'offset_changed' is emitted when the node is created
	# without this the first drag attempt won't grab children
	set_deferred('dragging', false)

# ******************************************************************************

var dragging := false

func dragged(from, to):
	dragging = false

var start_pos := Vector2()
var drag_children := {}

func offset_changed():
	if !dragging:
		drag_children.clear()
		start_pos = offset
		
		var region = Rect2(offset, rect_size)
		for node in get_parent().nodes.values():
			if node == self:
				continue
			var node_region = Rect2(node.offset, node.rect_size)
			if region.encloses(node_region):
				drag_children[node] = node.offset
		dragging = true
		
	var difference = start_pos - offset
	for child in drag_children:
		var start = drag_children[child]
		child.offset = start - difference

# ******************************************************************************

func get_data():
	var data = .get_data()
	data['color'] = ColorPicker.color.to_html()
	return data

func set_data(new_data):
	if 'color' in new_data:
		self_modulate = Color(new_data.color)
		ColorPicker.color = Color(new_data.color)
	.set_data(new_data)
