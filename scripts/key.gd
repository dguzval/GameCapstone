extends Area2D

@onready var exit : Area2D = $"../Exit"
@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("collected key")
		animated_sprite.visible = false
		call_deferred("_update_key_access")
		LevelState.update_key_count()
		
		if(LevelState.has_key):
			exit._update_locked_state()
		
func _update_key_access(): 
	collision.set_disabled(true)
