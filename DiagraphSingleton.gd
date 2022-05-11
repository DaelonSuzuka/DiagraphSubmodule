tool
extends Node

# ******************************************************************************

var prefix := 'user://' if OS.has_feature('HTML5') else 'res://'

var characters_path = 'characters/'
var character_map_path = characters_path + 'other_characters.json'
var characters := {}

var sandbox = load('res://addons/diagraph/Sandbox.gd').new()

var conversation_path := 'conversations/'
var conversations := {}

var conversation_prefix := prefix + conversation_path

signal refreshed

# ******************************************************************************

func _ready():
	validate_paths()
	call_deferred('refresh')

	if OS.has_feature('HTML5'):
		for file in get_all_files('res://' + conversation_path, '.json'):
			var to_path = file.replace('res://', 'user://')
			save_json(to_path, load_json(file))
		for file in get_all_files('res://' + conversation_path, '.yarn'):
			var to_path = file.replace('res://', 'user://')
			save_yarn(to_path, load_yarn(file))

func refresh():
	load_conversations()
	load_characters()
	emit_signal('refreshed')

func load_conversations():
	conversations.clear()
	var json_conversations = get_all_files(prefix + conversation_path, '.json')
	for convo in json_conversations:
		conversations[path_to_name(convo)] = convo
	var yarn_conversations = get_all_files(prefix + conversation_path, '.yarn')
	for convo in yarn_conversations:
		conversations[path_to_name(convo)] = convo

func load_conversation(path, default=null):
	var result = default

	# handle complete path
	if path.begins_with(prefix):
		if path.ends_with('.json'):
			result = load_json(path, default)
		if path.ends_with('.yarn'):
			result = load_yarn(path, default)
		return result

	if !(path in conversations):
		return result

	# handle shorthand convo path
	if conversations[path].ends_with('.json'):
		result = load_json(conversations[path], default)
	if conversations[path].ends_with('.yarn'):
		result = load_yarn(conversations[path], default)
	return result

func save_conversation(path, data):
	if !data:
		# print("can't save empty data")
		return
	if path.begins_with(prefix):
		if path.ends_with('.json'):
			save_json(path, data)
		if path.ends_with('.yarn'):
			save_yarn(path, data)
		return
	if path in conversations:
		if conversations[path].ends_with('.json'):
			save_json(conversations[path], data)
			# var path = conversations[path].replace('.json', '.yarn')
			# save_yarn(path, data)
		if conversations[path].ends_with('.yarn'):
			save_yarn(conversations[path], data)
	else:
		save_yarn(prefix + conversation_path + path + '.yarn', data)

func load_characters():
	characters.clear()
	for file in get_all_files('res://' + characters_path, '.tscn'):
		var c = load(file).instance()
		characters[c.name] = c

	# for folder in get_files('res://' + characters_path):
	# 	for file in get_files('res://' + characters_path + folder, '.tscn'):
	# 		var file = 'res://' + characters_path + folder + '/' + file
	# 		if dir.file_exists(file):
	# 			var c = load(file).instance()
	# 			characters[c.name] = c

	# var dir := Directory.new()
	# var char_map = load_json(character_map_path, {})
	# for name in char_map:
	# 	if dir.file_exists(char_map[name]):
	# 		characters[name] = load(char_map[name]).instance()

# ******************************************************************************

func ensure_prefix(path):
	if !path.begins_with(Diagraph.conversation_prefix):
		path = Diagraph.conversation_prefix.plus_file(path)
	return path

func name_to_path(name):
	return conversation_path + name

func path_to_name(path):
	return path.trim_prefix(prefix + conversation_path)

func validate_paths():
	var dir = Directory.new()
	if !dir.dir_exists(prefix + characters_path):
		dir.make_dir_recursive(prefix + characters_path)
	if !dir.dir_exists(prefix + conversation_path):
		dir.make_dir_recursive(prefix + conversation_path)

func get_files(path, ext='') -> Array:
	var files = []
	var dir = Directory.new()
	dir.open(path)
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file == '':
			break
		elif not file.begins_with('.'):
			if ext:
				if file.ends_with(ext):
					files.append(file)
			else:
				files.append(file)
	dir.list_dir_end()
	return files

func get_all_files(path: String, ext:='', max_depth:=10, depth:=0, files:=[]) -> Array:
	if depth >= max_depth:
		return []

	var dir = Directory.new()
	dir.open(path)

	dir.list_dir_begin(true, true)

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().plus_file(file)
		if dir.current_is_dir():
			get_all_files(file_path, ext, max_depth, depth + 1, files)
		else:
			if ext:
				if file.ends_with(ext):
					files.append(file_path)
			else:
				files.append(file_path)
		file = dir.get_next()
	dir.list_dir_end()
	return files

func get_all_files_and_folders(path: String, ext:='', max_depth:=10, depth:=0, files:=[]) -> Array:
	if depth >= max_depth:
		return []

	var dir = Directory.new()
	dir.open(path)

	dir.list_dir_begin(true, true)

	var file = dir.get_next()
	while file != '':
		var file_path = dir.get_current_dir().plus_file(file)
		if dir.current_is_dir():
			files.append(file_path)
			get_all_files_and_folders(file_path, ext, max_depth, depth + 1, files)
		else:
			if ext and file.ends_with(ext):
				files.append(file_path)
			else:
				files.append(file_path)
		file = dir.get_next()
	dir.list_dir_end()
	return files

# ******************************************************************************

func save_json(path, data):
	if !data:
		return
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = prefix + path

	var dir = Directory.new()
	dir.make_dir_recursive(path.get_base_dir())

	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string(JSON.print(data, '\t'))
	f.close()

func load_json(path, default=null):
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = prefix + path
	var result = default
	var f = File.new()
	if f.file_exists(path):
		f.open(path, File.READ)
		var text = f.get_as_text()
		f.close()
		var parse = JSON.parse(text)
		if parse.result is Dictionary:
			result = parse.result
	return result

# ******************************************************************************

func save_yarn(path, data):
	if !data:
		return
	if !path.begins_with('res://') and !path.begins_with('user://'):
		path = prefix + path

	var dir = Directory.new()
	dir.make_dir_recursive(path.get_base_dir())

	var out = convert_nodes_to_yarn(data)

	var f = File.new()
	f.open(path, File.WRITE)
	f.store_string(out)
	f.close()

func convert_nodes_to_yarn(data):
	var out = ''

	for id in data:
		var node = data[id]

		node['title'] = node['name']
		node.erase('name')

		var text = node['text']
		node.erase('text')

		node.erase('rect_size')
		node.erase('offset')

		if 'connections' in node:
			node.connections = var2str(node.connections).replace('\n', '')
		if 'choices' in node:
			node.choices = var2str(node.choices).replace('\n', '')
		if 'branches' in node:
			node.branches = var2str(node.branches).replace('\n', '')

		for field in node:
			out += field + ': ' + str(node[field]) + '\n'

		out += '---' + '\n'

		out += text + '\n'
		out += '===' + '\n'

	return out

# ------------------------------------------------------------------------------

func load_yarn(path, default=null):
	var result = default

	var f = File.new()
	if f.file_exists(path):
		f.open(path, File.READ)
		var text = f.get_as_text()
		f.close()
		parse_yarn(text)
		if nodes:
			result = nodes
	return result

var nodes := {}

func parse_yarn(text):
	nodes.clear()
	var mode := 'header'

	var header := []
	var body := []
	var i := 0
	var lines = text.split('\n')
	while i < lines.size():
		var line = lines[i]
		if line == '===':  # end of node
			create_node(header, body)
			header.clear()
			body.clear()
			mode = 'header'
		elif line == '---':  # end of header
			mode = 'body'
		else:
			if mode == 'header':
				header.append(line)
			if mode == 'body':
				body.append(line)
		i += 1

var used_ids = []

func get_id() -> int:
	var id = randi()
	if id in used_ids:
		id = get_id()
	used_ids.append(id)
	return id

func create_node(header, body):
	var node := {
		id = 0,
		type = '',
		name = '',
		text = '',
		next = 'none',
	}

	var fields := {}
	for line in header:
		var parts = line.split(':', true, 1)
		if parts.size() != 2:
			continue
		fields[parts[0]] = parts[1].lstrip(' ')

	node.name = fields.title
	fields.erase('title')

	node.id = fields.get('id', get_id())
	fields.erase('id')

	node.type = fields.get('type', 'speech')
	fields.erase('type')

	for field in fields:
		node[field] = fields[field]

	if 'connections' in node:
		node.connections = str2var(node.connections)
	if 'choices' in node:
		node.choices = str2var(node.choices)
	if 'branches' in node:
		node.branches = str2var(node.branches)

	var _body = body[0]
	var i = 1
	while i < body.size():
		_body += '\n' + body[i]
		i += 1
	node['text'] = _body

	nodes[str(node.id)] = node
