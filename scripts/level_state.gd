extends Node


# Called when the node enters the scene tree for the first time.
var has_key: bool = false
var key_required: bool = false
var amount_key: int = 0
var key_acquired: int = 0

func reset_for_level():
	has_key = false
	key_required = false
	amount_key = 0
	key_acquired = 0
	
func update_key_count():
	key_acquired += 1
	print(key_acquired)
	print(amount_key)
	
	if(key_acquired == amount_key):
		has_key = true
