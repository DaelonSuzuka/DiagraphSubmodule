tool
extends GraphNode

# ******************************************************************************

var ContextMenu = preload('../utils/ContextMenu.gd')

var data := {
	id = 0,
	type = 'base',
	name = '',
	text = '',
	next = 'none',
	rect_size = '',
	offset = '',
	connections = {}
}

onready var Edit = $Body/Toolbar/Edit
onready var CloseButton = $Body/Toolbar/Close
onready var Toolbar = $Body/Toolbar
onready var Title = $Body/Toolbar/Title
onready var Id = $Body/Toolbar/Id
onready var Parent = get_parent()

signal changed

# ******************************************************************************

func _ready() -> void:
	CloseButton.connect('pressed', self, 'emit_signal', ['close_request'])
	connect('resize_request', self, 'resize_request')
	connect('gui_input', self, '_gui_input')

	Title.connect('text_changed', self, 'renamed')

func resize_request(new_minsize: Vector2) -> void:
	emit_signal('changed')
	if get_parent().use_snap:
		var snap = get_parent().get_snap()
		rect_size = new_minsize.snapped(Vector2(snap, snap))
	else:
		rect_size = new_minsize

# ******************************************************************************
# Context Menu trigger

func _gui_input(event: InputEvent) -> void:
	if !visible:
		return
	if !(event is InputEventMouseButton) or !event.pressed:
		return

	var title_rect = Rect2(Toolbar.rect_global_position, Toolbar.rect_size * Parent.zoom)
	if title_rect.has_point(event.global_position):
		if event.button_index == 2:
			title_bar_ctx(event.global_position)
			return

	var body_rect = Rect2(rect_global_position, rect_size * Parent.zoom)
	if body_rect.has_point(event.global_position):
		if event.button_index == 2:
			body_ctx(event.global_position)
			return

# ******************************************************************************
# Context Menu override stuff

# Override this
func get_title_bar_ctx_items() -> Array:
	return []
	
func title_bar_ctx_selection(selection: String):
	pass

# Override this
func get_body_ctx_items() -> Array:
	return []

func body_ctx_selection(selection: String):
	pass
	
# ******************************************************************************
# Context Menu spawner

func title_bar_ctx(pos: Vector2) -> void:
	Parent.dismiss_ctx()
	Parent.ctx = ContextMenu.new(self, '_title_bar_ctx_selection')
	Parent.ctx.add_item('Copy Path')
	for item in self.get_title_bar_ctx_items():
		Parent.ctx.add_item(item)
	Parent.ctx.open(pos)
	accept_event()

func _title_bar_ctx_selection(selection: String):
	if selection == 'Copy Path':
		var path = '%s:%s' % [Parent.owner.current_conversation, data.name]
		OS.clipboard = path

	self.title_bar_ctx_selection(selection)

func body_ctx(pos: Vector2) -> void:
	Parent.dismiss_ctx()
	Parent.ctx = ContextMenu.new(self, '_body_ctx_selection')
	var items = self.get_body_ctx_items()
	for item in items:
		Parent.ctx.add_item(item)
	if items:
		Parent.ctx.open(pos)
	accept_event()

func _body_ctx_selection(selection: String):
	# default body options go here

	self.body_ctx_selection(selection)

# ******************************************************************************

func set_id(id) -> void:
	data.id = id
	name = str(id)
	Id.text = str(data.id) + " | "

func rename(new_name):
	Title.text = new_name
	renamed(new_name)

func renamed(new_name):
	emit_signal('changed')
	Parent.emit_signal('node_renamed', data.name, new_name)
	data.name = new_name

# ******************************************************************************

func get_data() -> Dictionary:
	data.offset = var2str(offset)
	data.rect_size = var2str(rect_size)
	data.name = Title.text
	return data.duplicate(true)

func set_data(new_data: Dictionary) -> GraphNode:
	if 'type' in new_data:
		data.type = new_data.type
	if 'connections' in new_data:
		for con in new_data.connections:
			data.connections[con] = []
			data.connections[con].append(int(new_data.connections[con][0]))
			data.connections[con].append(int(new_data.connections[con][1]))
	if 'id' in new_data:
		set_id(new_data.id)
	if 'name' in new_data:
		data.name = new_data.name
		rename(new_data.name)
	if 'offset' in new_data:
		offset = str2var(new_data.offset)
	if 'rect_size' in new_data:
		rect_size = str2var(new_data.rect_size)
	return self
