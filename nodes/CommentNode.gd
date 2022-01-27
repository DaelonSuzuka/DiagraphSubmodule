tool
extends 'BaseNode.gd'

# ******************************************************************************

onready var ColorPicker = find_node('ColorPickerButton')

# ******************************************************************************

func _ready():
	ColorPicker.get_picker()
	ColorPicker.get_popup()
	ColorPicker.connect('color_changed', self, 'color_changed')

func color_changed(color):
	self_modulate = color

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
