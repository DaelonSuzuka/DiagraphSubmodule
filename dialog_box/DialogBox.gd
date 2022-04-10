tool
extends Control

# ******************************************************************************

var OptionButton = preload('res://addons/diagraph/dialog_box/OptionButton.tscn')
var option_button = null

var TextTimer := Timer.new()
var DismissTimer := Timer.new()
var original_cooldown := 0.05
var next_char_cooldown := original_cooldown

signal done()
signal line_finished()
signal character_added(c)

onready var Name = find_node('Name')
onready var NameOutline = find_node('NameOutline')
onready var TextBox = find_node('TextBox')
onready var TextBoxOutline = find_node('TextBoxOutline')
onready var DebugLog = find_node('DebugLog')
onready var Options = find_node('Options')
onready var Portrait = find_node('Portrait')

var waiting_for_choice := false
var active := false
var direct_input := true

# ******************************************************************************

func _ready():
	add_child(TextTimer)
	TextTimer.connect('timeout', self, 'next_char')
	TextTimer.one_shot = true
	add_child(DismissTimer)
	DismissTimer.connect('timeout', self, 'next_line')
	DismissTimer.one_shot = true

	var opt_btn = get_node_or_null('OptionButton')
	if opt_btn:
		remove_child(opt_btn)
		option_button = opt_btn

# input handling shim 
func _input(event):
	if direct_input:
		handle_input(event)

func handle_input(event):
	if !visible or !active or waiting_for_choice:
		return
	if event is InputEventKey and event.pressed:
		if event.as_text() == 'Enter':
			accept_event()
			next_line()

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

	Options.add_child(button)
	return button

func remove_options() -> void:
	for child in Options.get_children():
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
var popup = false
var popup_timeout = 1.0

func start(conversation, options={}):
	# reset stuff
	var name = ''
	var entry = ''
	var line_number = 0
	active = true
	caller = null
	NameOutline.modulate = Color.white
	TextBoxOutline.modulate = Color.white
	remove_options()

	# parse conversation string
	if conversation.begins_with('res://'):
		name = conversation
	else:
		var parts = conversation.split(':')
		name = Diagraph.conversations[parts[0]]
		if parts.size() >= 2:
			entry = parts[1]
		if parts.size() >= 3:
			line_number = int(parts[2])

	nodes = Diagraph.load_conversation(name, {})

	# identify starting node
	current_node = null
	if entry:
		for node in nodes.values():
			if node.name == entry:
				current_node = str(node.id)
		if !current_node:
			current_node = entry
	else:
		current_node = nodes.keys()[0]

	# set up initial data
	current_data = nodes[current_node]
	current_data.text = split_text(current_data.text)

	line_count = 0
	current_line = line_number
	if line_number == -1 or line_number > current_data.text.size():
		current_line = current_data.text.size() - 1

	# parse options
	if 'caller' in options:
		caller = options.caller

	if 'popup' in options:
		popup = true
		popup_timeout = options.popup

	length = -1
	if 'length' in options:
		length = options.length
	if 'len' in options:
		length = options.len

	next_line()
	show()

func stop():
	active = false
	hide()
	remove_options()
	emit_signal('done')

# ******************************************************************************

func set_node(next_node):
	current_node = next_node
	current_line = 0
	current_data = nodes[current_node].duplicate(true)
	current_data.text = split_text(current_data.text)

func next_line():
	if line_active:
		while line_active:
			next_char(false)
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
						var result = evaluate(branch.condition)
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
						result = evaluate(condition)
					var option = add_option(current_data.choices[c].choice, c)
					if !result:
						option.set_disabled(true)
			if Options.get_child_count():
				Options.get_child(0).grab_focus()
			return

		set_node(current_data.next)

	var new_line = current_data.text[current_line]

	# check for line skip
	# TODO: check for lines that only contain a code block
	# TODO: skip lines that are only whitespace
	var skip := false
	if new_line.length() == 0 or new_line.begins_with('#'):
		skip = true

	if new_line.begins_with('-'):
		var choices = {}
		var lookahead = current_line

		while lookahead < current_data.text.size():
			var lookahead_line = current_data.text[lookahead]
			var choice_number = 1
			lookahead += 1
			print(lookahead_line)
			if lookahead_line.begins_with('\t'):
				continue
			if lookahead_line.begins_with('-'):
				var parts = lookahead_line.lstrip('- ').split('=>')
				var choice = {
					choice = parts[0],
					condition = '',
					next = '',
				}
				if current_data.text[lookahead + 1].begins_with('\t'):
					choice.next = lookahead + 1
				if parts.size() == 2:
					choice.next = parts[1]
				choices[str(choice_number)] = choice
				choice_number += 1

		# waiting_for_choice = true
		# for choice in choices:
		# 	var result = true
		# 	var condition = choice.condition
		# 	if condition:
		# 		result = evaluate(condition)
		# 	var option = add_option(choice.choice, c)
		# 	if !result:
		# 		option.set_disabled(true)
		print(choices)

	# do character stuff
	var color = Color.white
	var name = ''
	var parts = new_line.split(':')
	
	if parts.size() > 1:
		name = parts[0]
		if '.' in name:
			var subparts = name.split('.')
			evaluate(name)
			name = subparts[0]

		if '/' in name:
			print('multiple characters not yet supported')

		if name in Diagraph.characters:
			current_character = null
			new_line = strip_name(new_line)
			var character = Portrait.get_node_or_null(name)
			if !character:
				character = Diagraph.characters[name]

				var old_parent = character.get_parent()
				if old_parent:
					old_parent.remove_child(character)
				Portrait.add_child(character)
			
			current_character = character
			if character.get('color'):
				color = character.color
		else:
			name = ''

	if skip:
		current_line += 1
		next_line()
		return

	for child in Portrait.get_children():
		child.hide()
		if child.name == name:
			if !popup:
				child.show()
			character_idle()

	NameOutline.modulate = color
	TextBoxOutline.modulate = color
	Name.text = name
	Name.visible = (name != '') if !popup else false
	set_line(new_line)

	line_count += 1
	current_line += 1

func option_selected(choice):
	remove_options()
	waiting_for_choice = false
	var next_node = current_data.choices[choice].next
	if !next_node:
		stop()
		return
		
	set_node(next_node)
	next_line()

# ******************************************************************************

var line := ''
var line_index := 0
var line_active := false

func set_line(_line):
	line_active = true
	line = _line
	line_index = 0
	TextBox.bbcode_text = ''
	DebugLog.text = ''
	next_char_cooldown = original_cooldown
	TextTimer.start(next_char_cooldown)

func next_char(use_timer=true):
	if line_index == line.length():
		if popup:
			line_active = false
			DismissTimer.start(popup_timeout)
			return
		emit_signal('line_finished')
		character_idle()
		TextTimer.stop()
		line_active = false
		return 

	var next_char = line[line_index]
	var cooldown = next_char_cooldown

	match next_char:
		'{': # detect commands
			if line[line_index + 1] == '{':
				var end = line.findn('}}', line_index)
				if end != -1:
					var command = line.substr(line_index, end - line_index + 2)
					line_index = end + 2
					if line_index < line.length():
						if line[line_index] == ' ':
							line_index += 1
					var cmd = command.lstrip('{{').rstrip('}}')
					var result = evaluate(cmd)
					line.erase(line_index, end - line_index + 2)
					line = line.insert(line_index, str(result))
					DebugLog.text += '\nexpansion: ' + str(result)
					next_char()
			else:
				var end = line.findn('}', line_index)
				if end != -1:
					var command = line.substr(line_index, end - line_index + 1)
					line_index = end + 1
					if line_index < line.length():
						if line[line_index] == ' ':
							line_index += 1
					var cmd = command.lstrip('{').rstrip('}')
					var result = evaluate(cmd)
					DebugLog.text += '\ncommand: ' + command
					next_char()
		'<': # reserved for future use
			var end = line.findn('>', line_index)
			if end != -1:
				var block = line.substr(line_index, end - line_index + 1)
				DebugLog.text += '\nangle_brackets: ' + block
				line_index = end + 1
		'[': # detect chunks of bbcode
			var end = line.findn(']', line_index)
			if end != -1:
				var block = line.substr(line_index, end - line_index + 1)
				DebugLog.text += '\nbbcode: ' + block
				TextBox.bbcode_text += block
				line_index = end + 1
				next_char()
		'|': # pipe denotes chunks of text that should pop all at once
			var end = line.findn('|', line_index + 1)
			if end != -1:
				var chunk = line.substr(line_index + 1 , end - line_index - 1)
				DebugLog.text += '\npop: ' + chunk
				TextBox.bbcode_text += chunk
				line_index = end + 1
		'_': # pause
			cooldown = 0.25
			DebugLog.text += '\npause'
			character_idle()
			line_index += 1
		'\\': # escape the next character
			DebugLog.text += '\nescape'
			line_index += 1
			if line_index < line.length():
				print_char(line[line_index])
				line_index += 1
		_: # not a special character, just print it
			print_char(next_char)
			line_index += 1

	if use_timer:
		TextTimer.start(cooldown)

func print_char(c):
	character_talk(c)
	
	TextBox.bbcode_text += c
	emit_signal('character_added', c)

# ******************************************************************************

func evaluate(input:String):
	var ctx = Diagraph.sandbox.get_eval_context()

	ctx.variable('onready var caller = get_parent().caller')
	ctx.variable('onready var scene = get_parent().caller.owner')

	ctx.variable('var _original_cooldown = ' + str(original_cooldown))
	ctx.method('func speed(value=_original_cooldown):', [
		'get_parent().next_char_cooldown = value',
	])

	var context = ctx.build(self)
	add_child(context)
	return Diagraph.sandbox.evaluate(input, context)
