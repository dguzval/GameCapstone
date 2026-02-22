extends Node

var has_key: bool = false
var key_required: bool = false
var amount_key: int = 0
var key_acquired: int = 0
var plates_exists: bool = false
var all_plates_pressed: bool = false
var plate_amount: int = 0
var plates_pressed: int = 0
var curr_level: int = 0


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
	if key_acquired == amount_key:
		has_key = true

func check_plates_pressed():
	all_plates_pressed = (plates_pressed == plate_amount)

func get_level():
	return curr_level

func on_level_started(level_id: int) -> void:
	curr_level = level_id
	if FirebaseManager:
		FirebaseManager.on_level_started(str(level_id))

func on_level_ended() -> void:
	if FirebaseManager:
		FirebaseManager.on_level_ended(str(curr_level))

func _notification(what: int) -> void:
	if typeof(FirebaseManager) == TYPE_NIL:
		return

	if what == NOTIFICATION_APPLICATION_PAUSED:
		FirebaseManager.on_level_ended(str(curr_level))

	if what == NOTIFICATION_APPLICATION_RESUMED:
		# restart the timer so time keeps accumulating
		FirebaseManager.on_level_started(str(curr_level))
