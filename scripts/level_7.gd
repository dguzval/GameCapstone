extends Node2D
@onready var exit : Area2D = $Exit

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	LevelState.reset_for_level()
	exit._update_locked_state()
	LevelState.key_required = has_node("Key") # adjust path if needed
	LevelState.amount_key = 1
