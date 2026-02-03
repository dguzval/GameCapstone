extends Area2D

const FILE_BEGIN =  "res://levels/level_" 
@onready var player : CharacterBody2D = $"../Player"
@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

func _process(_delta: float) -> void:
	if(!animated_sprite.is_playing()):
		print("animation stopped playing")
		animated_sprite.play("default")
		animated_sprite.set_autoplay("default")
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var current_scene_file = get_tree().current_scene.scene_file_path
		var next_level_number = current_scene_file.to_int() + 1

		PhysicsServer2D.area_set_param(
			get_viewport().find_world_2d().space,
			PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR,
			Vector2.DOWN
		)

		var next_level_path = FILE_BEGIN + str(next_level_number) + ".tscn"

		# Safer than changing scenes directly inside physics callback
		call_deferred("_go_to_next_level", next_level_path)

func _go_to_next_level(path: String) -> void:
	get_tree().change_scene_to_file(path)

func _update_locked_state() -> void:
	call_deferred("_update_exit_access")
	animated_sprite.visible = false
	# If we just transitioned from locked -> unlocked, pop up + animate once
	print(LevelState.has_key)
	
	if LevelState.has_key:
		print("unlocked gate")
		animated_sprite.visible = true
		animated_sprite.play("gate_open")
		
func _update_exit_access():
	collision.set_disabled(!collision.is_disabled())
