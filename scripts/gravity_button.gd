extends Area2D

@onready var player : CharacterBody2D = $"../Player"
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
@export var gravity_change = "UP"

func _on_body_entered(body: Node2D) -> void:

	if(body.is_in_group("player")):
		animated_sprite.play("pressed")
		if(gravity_change == "UP"):
			print("button pressed : gravity UP")
			PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.UP)
			player.set_up_direction(Vector2.DOWN)
			player.rotation_degrees = 180
		elif(gravity_change == "DOWN"):
			print("button pressed : gravity DOWN")
			PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.DOWN)
			player.set_up_direction(Vector2.UP)
			player.rotation_degrees = 0
		elif(gravity_change == "LEFT"):
			print("button pressed : gravity LEFT")
			PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.LEFT)
			player.set_up_direction(Vector2.RIGHT)
			player.rotation_degrees = 90
		elif(gravity_change == "RIGHT"):
			print("button pressed : gravity RIGHT")
			PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.RIGHT)
			player.set_up_direction(Vector2.LEFT)
			player.rotation_degrees = -90
