extends Control
@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var help_center : Control = $CanvasLayer/help

func _ready():
	animation_player.play("RESET")
	hide()

func resume():
	get_tree().paused = false
	RunTimer.on_game_paused(false)
	
	if FirebaseManager:
		FirebaseManager.on_game_resumed()
	
	
func pause():
	get_tree().paused = true
	RunTimer.on_game_paused(true)
	
	if FirebaseManager:
		FirebaseManager.on_game_paused()
		
	show()
	animation_player.play("blur")
	
	
func testPause():
	if Input.is_action_pressed("pause") && get_tree().paused == false:
		pause()
		
func _on_resume_pressed() -> void:
	resume()
	hide()

func _on_help_pressed() -> void:
	resume()
	hide()
	help_center.show()
	help_center.pause()
	
	


func _on_quit_pressed() -> void:
	RunTimer.pause_run()
	
	if FirebaseManager:
		FirebaseManager.on_game_paused()
		
	get_tree().paused = false
	hide()
	PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.DOWN)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	
func _process(_delta: float):
	testPause()
	
