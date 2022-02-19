tool
extends Tree

# ******************************************************************************

onready var ContextMenu = preload('res://addons/diagraph/utils/ContextMenu.gd')

var root: TreeItem = null
var convos: TreeItem = null
var chars: TreeItem = null

export var folder_icon: ImageTexture
export var file_icon: ImageTexture
export var card_icon: ImageTexture

signal conversation_changed(path)
signal conversation_selected(path)
signal conversation_created(path)
signal conversation_deleted(path)
signal conversation_renamed(old_path, new_path)

signal card_selected(path)
signal card_focused(path)
signal card_renamed(id, new_path)
signal card_deleted(id)

# ******************************************************************************

func _ready():
	Diagraph.connect('refreshed', self, 'refresh')
		
	connect('item_selected', self, '_on_item_selected')
	connect('gui_input', self, '_on_gui_input')
	connect('item_edited', self, '_on_item_edited')
	connect('item_activated', self, 'item_activated')

func refresh():
	if root:
		root.free()
	root = create_item()

	var current_conversation = owner.current_conversation

	for convo in Diagraph.conversations:
		var item = create_item(root)
		var text = convo
		var path = convo
		item.set_text(0, text)
		item.set_metadata(0, path)
		item.set_tooltip(0, path)
		item.set_icon(0, file_icon)

		item.collapsed = convo != current_conversation

		var nodes = Diagraph.load_json(Diagraph.name_to_path(path), {})
		var node_names = []
		var nodes_by_name = {}
		
		for node in nodes.values():
			nodes_by_name[node.name] = node
			node_names.append(node.name)

		node_names.sort()

		for name in node_names:
			var _item = create_item(item)
			_item.set_text(0, nodes_by_name[name].name)
			_item.set_metadata(0, nodes_by_name[name].id)
			_item.set_icon(0, card_icon)
			# _item.set_tooltip(0, str(node.id))

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		# if event.button_index == 1 and event.doubleclick:
		# 	item_activated()
		# 	accept_event()
		if event.button_index == 2:
			open_context_menu(event.position)
			# accept_event()

func item_activated():
	var item = get_selected()
	var parent = item.get_parent()
	var path = get_item_path(item)

	if parent == root:
		emit_signal('conversation_changed', path)
	else:
		emit_signal('card_focused', path)

# ******************************************************************************

func _start_rename():
	var item = get_selected()
	item.set_editable(0, true)
	edit_selected()

func _on_item_edited():
	var item = get_selected()
	item.set_editable(0, false)
	if item.get_parent() == root:
		var name = item.get_text(0)
		var path = item.get_metadata(0)
		var new_path = name
		if path:
			item.set_metadata(0, new_path)
			item.set_tooltip(0, new_path)
			emit_signal('conversation_renamed', path, new_path)
		else:
			item.set_metadata(0, new_path)
			item.set_tooltip(0, new_path)
			emit_signal('conversation_created', new_path)
	else:
		var name = item.get_text(0)
		var id = item.get_metadata(0)
		item.set_tooltip(0, name)
		emit_signal('card_renamed', id, name)

# ******************************************************************************

func get_item_path(item:TreeItem) -> String:
	var parent = item.get_parent()
	if parent == root:
		return item.get_text(0)
	else:
		return parent.get_text(0) + ':' + item.get_text(0)

func _on_item_selected() -> void:
	var item = get_selected()
	var parent = item.get_parent()
	var path = get_item_path(item)
	
	if parent == root:
		item.collapsed = !item.collapsed
		emit_signal('conversation_selected', path)
	else:
		var id = item.get_metadata(0)
		emit_signal('card_selected', id)

func select_item(path):
	pass
	# print('tree select_item ', path)

func delete_item(id):
	var item = root.get_children()
	while true:
		if item == null:
			break
		if item.get_text(0) == owner.current_conversation:
			var card = item.get_children()
			while true:
				if card == null:
					break
				if card.get_metadata(0) == id:
					item.remove_child(card)
					card.free()
					break
				card = card.get_next()
			break
		item = item.get_next()

# ******************************************************************************

var ctx = null

func open_context_menu(position) -> void:
	if ctx:
		ctx.queue_free()
		ctx = null

	var item = get_item_at_position(position)

	ctx = ContextMenu.new(self, 'context_menu_item_selected')
	if item:
		if item.get_parent() == root:
			ctx.add_item('New')
			ctx.add_item('Copy Path')
			ctx.add_item('Rename')
			ctx.add_item('Delete')
		else:
			ctx.add_item('Copy Path')
			# ctx.add_item('Copy Name')
			ctx.add_item('Rename')
			ctx.add_item('Delete')
	else:
		ctx.add_item('New')
	ctx.open(get_global_mouse_position())

func context_menu_item_selected(selection:String) -> void:
	match selection:
		'New':
			var item = create_item(root)
			item.set_text(0, 'new')
			item.set_editable(0, true)
			item.set_icon(0, file_icon)
			item.select(0)
			call_deferred('edit_selected')
		'Copy Path':
			var item = get_selected()
			var path = get_item_path(item)
			OS.clipboard = path
		'Rename':
			_start_rename()
		'Delete':
			var item = get_selected()
			item.get_parent().remove_child(item)
			
			if item.get_parent() == root:
				var path = item.get_metadata(0)
				if path:
					emit_signal('conversation_deleted', path)
			else:
				var id = item.get_metadata(0)
				emit_signal('card_deleted', id)