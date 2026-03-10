extends Area2D

@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		animated_sprite.visible = false
		FirebaseManager.log_coin()
		MusicManager.coin_pickup()
