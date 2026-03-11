extends Area2D

@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if FirebaseManager.ab_group != 1:
		animated_sprite.visible = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and animated_sprite.visible:
		animated_sprite.visible = false
		MusicManager.coin_pickup()
		FirebaseManager.log_coin()
