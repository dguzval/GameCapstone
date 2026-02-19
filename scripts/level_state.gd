extends Node


# Called when the node enters the scene tree for the first time.
var has_key: bool = false
var key_required: bool = false
var amount_key: int = 0
var key_acquired: int = 0
var plates_exists: bool = false
var all_plates_pressed: bool = false
var plate_amount: int = 0
var plates_pressed: int = 0
var curr_level : int = 0

func reset_for_level():
	has_key = false
	key_required = false
	amount_key = 0
	key_acquired = 0
	plates_exists = false
	all_plates_pressed = false
	plate_amount = 0
	plates_pressed = 0
	
func update_key_count():
	key_acquired += 1
	
	if(key_acquired == amount_key):
		has_key = true
func check_plates_pressed():
	if(plates_pressed == plate_amount):
		all_plates_pressed = true
	else:
		all_plates_pressed = false
		
func get_level():
	return curr_level
	
