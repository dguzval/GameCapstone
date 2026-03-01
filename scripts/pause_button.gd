extends Button

@onready var pause_menu: Control = $"../Pause_Menu"

func _on_pressed() -> void:
	pause_menu.pause()
	
