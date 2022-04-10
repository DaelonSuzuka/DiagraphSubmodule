tool
extends HBoxContainer

# ******************************************************************************

onready var Choice = $Choice
onready var Condition = $Condition

# ******************************************************************************

func get_data():
	var data = {
		choice = Choice.text,
		condition = Condition.text,
	}
	return data

func set_data(data):
	Choice.text = data.choice
	Condition.text = data.condition
