tool
extends 'BaseNode.gd'

# ******************************************************************************

onready var ColorPicker = find_node('ColorPickerButton')
onready var Tooltip = find_node('Tooltip')

# ******************************************************************************

func _ready():
	ColorPicker.get_picker()
	ColorPicker.get_popup()
	ColorPicker.connect('color_changed', self, 'set_self_modulate')
	Tooltip.hide()

	if get_parent() is GraphEdit:
		connect('offset_changed', self, 'offset_changed')
		get_parent().connect('_begin_node_move', self, 'begin_move')
		get_parent().connect('_end_node_move', self, 'end_move')
		get_parent().connect('zoom_changed', self, 'zoom_changed')

# ******************************************************************************

var dragging := false
var start_pos := Vector2()
var drag_children := {}

func begin_move():
	if !selected:
		return
	dragging = true
	drag_children.clear()
	start_pos = offset
	
	var own_region = Rect2(offset, rect_size)
	for node in get_parent().nodes.values():
		if node == self or !is_instance_valid(node):
			continue
		var node_region = Rect2(node.offset, node.rect_size)
		if own_region.encloses(node_region):
			drag_children[node] = node.offset

func offset_changed():
	var difference = start_pos - offset
	for child in drag_children:
		var start = drag_children[child]
		child.offset = start - difference

func end_move():
	if !selected:
		return
	dragging = false

# ******************************************************************************

func zoom_changed(zoom):
	print(zoom)
	Tooltip.hide()
	if zoom < .8:
		Tooltip.show()


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
