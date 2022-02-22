tool
extends Control

# ******************************************************************************

var OptionButton = preload('res://addons/diagraph/dialog_box/OptionButton.tscn')
var Eval = preload('res://addons/diagraph/utils/Eval.gd').new()
var option_button = null

var TextTimer := Timer.new()
var original_cooldown := 0.05
var next_char_cooldown := original_cooldown

signal done
signal line_finished
signal character_added(c)

onready var text_box = $TextBox

var waiting_for_choice := false
var active := false

# ******************************************************************************

func _ready():
	add_child(TextTimer)
	TextTimer.connect('timeout', self, 'process_text')
	TextTimer.one_shot = true

	var opt_btn = get_node_or_null('OptionButton')
	if opt_btn:
		remove_child(opt_btn)
		option_button = opt_btn

func _input(event):
	if !visible or !active or waiting_for_choice:
		return
	if event is InputEventKey and event.pressed:
		if event.as_text() == 'Enter':
			accept_event()
			next()

# ******************************************************************************

func add_option(option, value=null):
	var button
	if option_button:
		button = option_button.duplicate()
	else:
		button = OptionButton.instance()

	var arg = value if value else option
	button.connect("pressed", self, "option_selected", [arg])
	button.text = option

	$Options.add_child(button)
	return button

func remove_options() -> void:
	for child in $Options.get_children():
		if child is Button:
			child.queue_free()

# ******************************************************************************

var current_character = null

func character_talk(c):
	if current_character and current_character.has_method('talk'):
		current_character.talk(c)

func character_idle():
	if current_character and current_character.has_method('idle'):
		current_character.idle()

# ******************************************************************************
# utils

func strip_name(text):
	return text.split(':')[1].trim_prefix(':').trim_prefix(' ')

func split_text(text):
	var parts = text.split('\n')
	var original = -1
	var parts_to_concat = []

	for i in len(parts):
		if parts[i].ends_with('\\'):
			if original == -1:
				original = i
			parts_to_concat.append(i + 1)
		elif original != -1:
			for x in parts_to_concat:
				if x < len(parts):
					var next_part = parts[x]
					if ':' in next_part:
						next_part = strip_name(next_part)
					parts[original] += '\n' + next_part
					parts[x] = '#' + parts[x]
			original = -1

	return parts

# ******************************************************************************

var nodes = {}
var current_node = 0
var current_line = 0
var current_data = null
var caller = null
var line_count = 0
var length = -1

func start(conversation, options={}):
	var name = ''
	var entry = ''
	var line_number = 0
	remove_options()

	if conversation.begins_with('res://'):
		name = conversation
	else:
		var parts = conversation.split(':')
		name = Diagraph.name_to_path(parts[0])
		if parts.size() >= 2:
			entry = parts[1]
		if parts.size() >= 3:
			line_number = int(parts[2])

	active = true
	caller = null
	$Name/Outline.modulate = Color.white
	$TextBox/Outline.modulate = Color.white

	nodes = Diagraph.load_json(name, {})

	current_node = null
	if entry:
		for node in nodes.values():
			if node.name == entry:
				current_node = str(node.id)
		if !current_node:
			current_node = entry
	else:
		current_node = nodes.keys()[0]

	current_data = nodes[current_node]
	current_data.text = split_text(current_data.text)

	line_count = 0
	current_line = line_number
	if line_number == -1 or line_number > current_data.text.size():
		current_line = current_data.text.size() - 1

	if 'caller' in options:
		caller = options.caller

	length = -1
	if 'length' in options:
		length = options.length
	if 'len' in options:
		length = options.len

	next()
	show()

func stop():
	active = false
	hide()
	remove_options()
	emit_signal('done')

func next():
	if line_active:
		while line_active:
			process_text(false)
		return

	if length > 0 and line_count >= length:
		stop()
		return

	if current_line == current_data.text.size():
		if current_data.type == 'branch':
			for b in current_data.branches:
				var branch = current_data.branches[b]
				if branch.next:
					if branch.condition:
						var result = Eval.evaluate(branch.condition, self, Diagraph.get_locals())
						if !(result is String) and result == true:
							current_data.next = branch.next
							break
					else:
						current_data.next = branch.next
						break
		if current_data.next == 'none':
			stop()
			return
		if current_data.next == 'choice':
			waiting_for_choice = true
			for c in current_data.choices:
				if current_data.choices[c].choice:
					var result = true
					var condition = current_data.choices[c].condition
					if condition:
						result = Eval.evaluate(condition, self, Diagraph.get_locals())
					var option = add_option(current_data.choices[c].choice, c)
					if !result:
						option.set_disabled(true)
			if $Options.get_child_count():
				$Options.get_child(0).grab_focus()
			return

		current_node = current_data.next
		current_data = nodes[current_node]
		current_data.text = split_text(current_data.text)
		current_line = 0

	var line = current_data.text[current_line]
	if line.length() == 0 or line.begins_with('#'):
		current_line += 1
		next()
		return

	var color = Color.white
	var name = ''
	var parts = line.split(':')
	
	if parts.size() > 1:
		name = parts[0]
		if '.' in name:
			var subparts = name.split('.')
			Eval.evaluate(name, self, Diagraph.get_locals())
			name = subparts[0]
		else:
			Diagraph.characters[name].idle()

		if '/' in name:
			print('multiple characters')

		if name in Diagraph.characters:
			current_character = null
			line = line.trim_prefix(parts[0]).trim_prefix(':').trim_prefix(' ')
			var character = $Portrait.get_node_or_null(name)
			if !character:
				$Portrait.add_child(Diagraph.characters[name])
				character = $Portrait.get_node_or_null(name)
			if character.get('color'):
				color = character.color

	for child in $Portrait.get_children():
		child.hide()
		if child.name == name:
			child.show()
			current_character = child

	$Name/Outline.modulate = color
	$TextBox/Outline.modulate = color
	$Name.text = name
	$Name.visible = name != ''
	set_line(line)

	line_count += 1
	current_line += 1

func option_selected(choice):
	remove_options()
	waiting_for_choice = false
	var next_node = current_data.choices[choice].next
	if !next_node:
		stop()
		return
		
	current_node = next_node
	current_line = 0
	current_data = nodes[current_node].duplicate(true)
	current_data.text = current_data.text.split('\n')
	next()

# ******************************************************************************

var next_line := ''
var line_index := 0
var line_active := false

func set_line(line):
	line_active = true
	next_line = line
	line_index = 0
	text_box.bbcode_text = ''
	$DebugLog.text = ''
	next_char_cooldown = original_cooldown
	TextTimer.start(next_char_cooldown)

func speed(value=original_cooldown):
	next_char_cooldown = value

func process_text(use_timer=true):
	if line_index == next_line.length():
		emit_signal('line_finished')
		character_idle()
		TextTimer.stop()
		line_active = false
		return 

	var next_char = next_line[line_index]
	var cooldown = next_char_cooldown

	match next_char:
		'{': # detect commands
			if next_line[line_index + 1] == '{':
				var end = next_line.findn('}}', line_index)
				if end != -1:
					var command = next_line.substr(line_index, end - line_index + 2)
					line_index = end + 2
					var cmd = command.lstrip('{{').rstrip('}}')
					var result = Eval.evaluate(cmd, self, Diagraph.get_locals())
					next_line.erase(line_index, end - line_index + 2)
					next_line = next_line.insert(line_index, str(result))
					$DebugLog.text += '\nexpansion: ' + str(result)
					process_text()
			else:
				var end = next_line.findn('}', line_index)
				if end != -1:
					var command = next_line.substr(line_index, end - line_index + 1)
					line_index = end + 1
					var cmd = command.lstrip('{').rstrip('}')
					var result = Eval.evaluate(cmd, self, Diagraph.get_locals())
					$DebugLog.text += '\ncommand: ' + command
					process_text()
		'<': # reserved for future use
			var end = next_line.findn('>', line_index)
			if end != -1:
				var block = next_line.substr(line_index, end - line_index + 1)
				$DebugLog.text += '\nangle_brackets: ' + block
				line_index = end + 1
		'[': # detect chunks of bbcode
			var end = next_line.findn(']', line_index)
			if end != -1:
				var block = next_line.substr(line_index, end - line_index + 1)
				$DebugLog.text += '\nbbcode: ' + block
				text_box.bbcode_text += block
				line_index = end + 1
				process_text()
		'|': # pipe denotes chunks of text that should pop all at once
			var end = next_line.findn('|', line_index + 1)
			if end != -1:
				var chunk = next_line.substr(line_index + 1 , end - line_index - 1)
				$DebugLog.text += '\npop: ' + chunk
				text_box.bbcode_text += chunk
				line_index = end + 1
		'_': # pause
			cooldown = 0.25
			$DebugLog.text += '\npause'
			character_idle()
			line_index += 1
		'\\': # escape the next character
			$DebugLog.text += '\nescape'
			line_index += 1
			if line_index < next_line.length():
				print_char(next_line[line_index])
				line_index += 1
		_: # not a special character, just print it
			print_char(next_char)
			line_index += 1

	if use_timer:
		TextTimer.start(cooldown)

func print_char(c):
	character_talk(c)
	
	text_box.bbcode_text += c
	emit_signal('character_added', c)
