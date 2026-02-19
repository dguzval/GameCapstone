extends Control
@onready var animation_player : AnimationPlayer = $AnimationPlayer
@onready var help_center : Control = $CanvasLayer/help

func _ready():
	animation_player.play("RESET")
	hide()

func resume():
	get_tree().paused = false
	
	
func pause():
	get_tree().paused = true
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
	resume()
	hide()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	
func _process(_delta: float):
	testPause()
	
