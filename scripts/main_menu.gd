extends Node2D
@onready var help_screen : Control = $CanvasLayer/help
const FILE_BEGIN =  "res://levels/level_" 
const save_location = "user://SaveFile.tres"
var play_level = "res://levels/level_1.tscn"
var level_loaded = 1


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	help_screen.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func new_data_updated(data) -> void:
	print("new_data")
	print(data)
		
func patch_data_updated(data):
	print("patch_data")
	print(data)
		
		
func _on_play_pressed() -> void:
	LevelState.curr_level = level_loaded
	RunTimer.start_new_run()
	get_tree().change_scene_to_file(play_level)
		
	call_deferred("_start_level")

func _start_level() -> void:
	LevelState.on_level_started(level_loaded)

func _on_help_pressed() -> void:
	help_screen.pause()


func _save() -> void:
	var data = SceneData.new()
	data.last_level_played = FILE_BEGIN + str(LevelState.get_level()) + ".tscn"
	data.level_stored = LevelState.get_level()
	data.elapsed_ms = RunTimer.get_elapsed_ms()
	
	ResourceSaver.save(data, save_location)
	print("saved!")

func _load() -> void:
	if not ResourceLoader.exists(save_location):
		return
	
	var data = ResourceLoader.load(save_location) as SceneData
	play_level = data.last_level_played
	level_loaded = data.level_stored
	RunTimer.resume_from_elapsed(data.elapsed_ms)
	print("loaded!")
