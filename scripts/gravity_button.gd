extends Area2D

@onready var player : CharacterBody2D = $"../Player"

func _on_body_entered(body: Node2D) -> void:
	
	var gravity_vector = PhysicsServer2D.area_get_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR)
	if(body.is_in_group("player")):
		print("button pressed : gravity changed")
		if(gravity_vector == Vector2.DOWN):
			PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.UP)
			player.set_up_direction(Vector2.DOWN)
			player.animated_sprite.flip_v = true
			player.collision_shape_2d.position = Vector2(0, -12.0)
		else:
			PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.DOWN)
			player.set_up_direction(Vector2.UP)
			player.animated_sprite.flip_v = false
			player.collision_shape_2d.position = Vector2(0, -4.0)
