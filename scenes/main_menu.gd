extends Node2D
@onready var help_screen : Control = $CanvasLayer/help

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	help_screen.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/level_1.tscn")

func _on_help_pressed() -> void:
	help_screen.pause()


func _on_quit_pressed() -> void:
	get_tree().quit()
