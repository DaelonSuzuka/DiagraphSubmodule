tool
extends 'BaseNode.gd'

# ******************************************************************************

onready var ColorPicker = find_node('ColorPickerButton')
onready var Tooltip = find_node('Tooltip')
onready var TooltipBG = find_node('TooltipBG')

# ******************************************************************************

func _ready():
	ColorPicker.get_picker()
	ColorPicker.get_popup()
	ColorPicker.connect('color_changed', self, 'set_color')
	Tooltip.hide()

	var parent = get_parent()
	if parent is GraphEdit:
		connect('offset_changed', self, 'offset_changed')
		parent.connect('_begin_node_move', self, 'begin_move')
		parent.connect('_end_node_move', self, 'end_move')
		parent.connect('zoom_changed', self, 'zoom_changed')
		zoom_changed(parent.zoom)

func set_color(color):
	self_modulate = color
	TooltipBG.modulate = color

# ******************************************************************************

var dragging := false
var start_pos := Vector2()
var drag_children := {}

func begin_move():
	if !selected:
		return
	print('grabbed')
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
	print('released')
	dragging = false

# ******************************************************************************

func zoom_changed(zoom):
	Tooltip.hide()
	
	var stylebox:StyleBox = theme.get_stylebox('comment', 'GraphNode')
	var width = max(round(1 / zoom), 1)
	print(width)
	stylebox.border_width_bottom = width
	stylebox.border_width_top = width
	stylebox.border_width_left = width
	stylebox.border_width_right = width

	TooltipBG.get_stylebox('panel').border_width_bottom = width
	TooltipBG.get_stylebox('panel').border_width_top = width
	TooltipBG.get_stylebox('panel').border_width_left = width
	TooltipBG.get_stylebox('panel').border_width_right = width

	# var tooltip_stylebox = TooltipBG.theme.get_stylebox('comment', 'Panel')

	if zoom < .8:
		Tooltip.show()
		Tooltip.theme.default_font.size = round(16 / zoom)


# ******************************************************************************

func get_data():
	var data = .get_data()
	data['color'] = ColorPicker.color.to_html()
	return data

func set_data(new_data):
	if 'color' in new_data:
		self_modulate = Color(new_data.color)
		TooltipBG.modulate = Color(new_data.color)
		ColorPicker.color = Color(new_data.color)
	.set_data(new_data)
