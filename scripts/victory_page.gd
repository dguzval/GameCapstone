extends Node2D

@onready var time_label = $CanvasLayer/time_label

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var ms := RunTimer.get_elapsed_ms()
	time_label.text = format_time(ms)

func format_time(ms: int) -> String:
	var total_seconds := ms / 1000  # integer seconds
	var minutes := total_seconds / 60
	var secs := total_seconds % 60
	return "It took you %d:%02d" % [minutes, secs]


func _on_replay_pressed() -> void:
	RunTimer.start_new_run()
	LevelState.reset_for_level()
	LevelState.curr_level = 1
	PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.DOWN)
	get_tree().change_scene_to_file("res://levels/level_1.tscn")
