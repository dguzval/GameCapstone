extends Area2D

const FILE_BEGIN =  "res://levels/level_" 
@onready var player : CharacterBody2D = $"../Player"

func _on_body_entered(body: Node2D) -> void:
	if(body.is_in_group("player")):
		var current_scene_file = get_tree().current_scene.scene_file_path
		var next_level_number = current_scene_file.to_int() + 1
		
		# changes the scene and updates to original gravity
		PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.DOWN)
		var next_level_path = FILE_BEGIN + str(next_level_number) + ".tscn"
		await get_tree().process_frame
		get_tree().change_scene_to_file(next_level_path)
		
