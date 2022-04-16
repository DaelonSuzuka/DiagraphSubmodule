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
	connect('item_activated', self, '_on_item_activated')

var icon_colors = {
	'speech': Color.olivedrab,
	'branch': Color.tomato,
	'comment': Color.steelblue,
}

func refresh():
	if root:
		root.free()
	root = create_item()

	var current_conversation = ''
	if owner:
		current_conversation = owner.get('current_conversation')

	var items = {}

	for name in Diagraph.conversations:
		var path = Diagraph.conversations[name]
		var parts = path.trim_prefix(Diagraph.conversation_prefix).split('/')
		var last = parts[len(parts) - 1]
		var prev = root
		var chunk = ''
		for part in parts:
			chunk += part + '/'
			if chunk in items:
				prev = items[chunk]
				continue
			var item = create_item(prev)
			items[chunk] = item
			prev = item
			if part == last:  # file
				item.set_meta('type', 'file')
				item.set_meta('path', path)
				item.set_text(0, name.get_file())
				item.set_icon(0, file_icon)
				item.set_icon_modulate(0, Color.silver)
				item.set_tooltip(0, path)

				item.disable_folding = true
				item.collapsed = true
				if name == current_conversation:
					item.collapsed = false

					var nodes = Diagraph.load_conversation(path, {})
					var node_names = []
					var nodes_by_name = {}

					for node in nodes.values():
						nodes_by_name[node.name] = node
						node_names.append(node.name + ':' + str(node.id))

					node_names.sort()

					for node in node_names:
						var id = node.split(':')[1]
						var _item = create_item(item)
						_item.set_meta('type', 'node')
						_item.set_meta('path', path + ':' + str(id))
						_item.set_meta('id', id)
						_item.set_meta('node', nodes[id])
						_item.set_text(0, nodes[id].name)
						_item.set_icon(0, card_icon)
						_item.set_icon_modulate(0, icon_colors[nodes[id].type])
						_item.set_tooltip(0, nodes[id].type)
			else:  # folder
				item.set_meta('type', 'folder')
				item.set_meta('path', Diagraph.conversation_prefix + chunk)
				item.set_text(0, part)
				item.set_tooltip(0, Diagraph.conversation_prefix + chunk)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == 2:
			open_context_menu(event.position)

func _on_item_selected() -> void:
	var item = get_selected()
	var path = item.get_meta('path')
	var type = item.get_meta('type')

	match type:
		'file':
			emit_signal('conversation_selected', path)
		'folder':
			pass
		'node':
			emit_signal('card_selected', path)

func _on_item_activated():
	var item = get_selected()
	var path = item.get_meta('path')
	var type = item.get_meta('type')

	match type:
		'file':
			emit_signal('conversation_changed', path)
		'folder':
			pass
		'node':
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

func get_item_path(item: TreeItem) -> String:
	var parent = item.get_parent()
	if parent == root:
		return item.get_text(0)
	else:
		return parent.get_text(0) + ':' + item.get_text(0)

func select_item(path):
	pass

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
				if str(card.get_metadata(0)) == str(id):
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

func context_menu_item_selected(selection: String) -> void:
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
			var path = item.get_meta('path')
			path = path.replace('.yarn', '')
			path = path.replace('.json', '')
			OS.clipboard = path.trim_prefix(Diagraph.conversation_prefix)
		'Rename':
			_start_rename()
		'Delete':
			var item = get_selected()
			var path = item.get_meta('path')
			var type = item.get_meta('type')

			match type:
				'file':
					emit_signal('conversation_deleted', path)
				'folder':
					pass
				'node':
					emit_signal('card_deleted', item.get_meta('id'))

			item.get_parent().remove_child(item)
