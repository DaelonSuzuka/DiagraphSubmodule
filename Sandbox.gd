tool
extends Node

# ******************************************************************************

var locals := {}

func add_local(name, value):
	locals[name] = value

func add_locals(dict):
	for name in dict:
		add_local(name, dict[name])

# ------------------------------------------------------------------------------

var temp_locals := {}

func clear_temp_locals():
	temp_locals.clear()

func add_temp_local(name, value):
	temp_locals[name] = value

func add_temp_locals(dict):
	for name in dict:
		add_temp_local(name, dict[name])

# ------------------------------------------------------------------------------

func get_locals():
	var _locals = locals.duplicate(true)
	if Diagraph.dialog_target and Diagraph.dialog_target.get('caller'):
		_locals['caller'] = Diagraph.dialog_target.caller
		if Diagraph.dialog_target.caller.owner:
			_locals['scene'] = Diagraph.dialog_target.caller.owner
	for name in temp_locals:
		_locals[name] = temp_locals[name]
	for c in Diagraph.characters:
		_locals[c] = Diagraph.characters[c]
	return _locals

# ******************************************************************************
# eval context object

class EvalContext extends Node:
	var script_template = """
extends Node
var _parent = null
"""

	var init_template = """
func init(parent):
	name = 'EvalContext'
	_parent = parent
"""

	var methods := []
	var init_code := []
	var variables := []

	func reset_script():
		methods.clear()
		init_code.clear()
		variables.clear()

	func init(code=''):
		init_code.append(code)

	func method(signature='', body=[]):
		var code = signature
		for line in body:
			code += '\n\t' + line
		methods.append(code)

	func variable(name, value=null):
		var code = 'var ' + name
		if value:
			code += ' = ' + str(value)
		variables.append(code)

	func build(parent):
		var source = script_template
		var init_source = init_template

		for v in variables:
			source += '\n' + v

		for line in init_code:
			init_source += '\n\t' + line
		source += '\n' + init_source
		
		for m in methods:
			source += '\n' + m

		var script = GDScript.new()
		script.source_code = source
		script.reload()

		var node = Node.new()
		node.script = script
		node.init(parent)
		return node

func get_eval_context():
	var context = EvalContext.new()
	return context

func evaluate(input:String, context_object=null):
	var locals = get_locals()
	var expression = Expression.new()
	var result = null
	
	var error = expression.parse(input, PoolStringArray(locals.keys()))
	if error == OK:
		result = expression.execute(locals.values(), context_object)
		if expression.has_execute_failed():
			return input
	else:
		push_warning(expression.get_error_text())
		
	return result
