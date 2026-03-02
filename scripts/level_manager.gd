extends Node

const FILE_BEGIN =  "res://levels/level_" 
var _booted := false

func _ready() -> void:
	if _booted:
		return
	_booted = true

	print("READY:", name, " path=", get_path(), " id=", get_instance_id())
	LevelState.load_progress()
	print("loading...")

	var scene_path = FILE_BEGIN + str(LevelState.curr_level) + ".tscn"
	LevelState.start_level_after_scene_change(scene_path, LevelState.curr_level)
