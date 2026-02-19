extends Control

@onready var animation_player : AnimationPlayer = $AnimationPlayer

func _ready():
	animation_player.play("RESET")
	hide()

func resume():
	get_tree().paused = false
	
	
func pause():
	get_tree().paused = true
	show()
	animation_player.play("blur")
	
func _on_close_pressed() -> void:
	resume()
	hide()
