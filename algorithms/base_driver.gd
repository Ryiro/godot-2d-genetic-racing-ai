class_name BaseDriver
extends RefCounted

# The car this driver is controlling
var car: CharacterBody2D

func setup(p_car: CharacterBody2D) -> void:
	car = p_car

# Called every tick. Must return a dict with forward [-0.6 to 1.0] and turn [-1.0 to 1.0]
func evaluate_inputs(delta: float) -> Dictionary:
	return {
		"forward": 1.0,
		"turn": 0.0
	}
