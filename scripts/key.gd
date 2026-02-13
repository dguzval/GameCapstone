extends Area2D

@onready var exit : Area2D = $"../Exit"
@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var animated_sprite : AnimatedSprite2D = $AnimatedSprite2D
var is_claimed = false

func _ready() -> void:
	
	if(!LevelState.key_required):
		exit._update_locked_state()
		LevelState.key_required = true
		
	LevelState.amount_key += 1

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_claimed = true
		animated_sprite.visible = false
		call_deferred("_update_key_access")
		LevelState.update_key_count()
		
		if(LevelState.has_key):
			exit._update_locked_state()
		
func _update_key_access(): 
	collision.set_disabled(!collision.is_disabled())

func _update_key_state():
	call_deferred("_update_key_access")
	animated_sprite.visible = false
	
	if (LevelState.all_plates_pressed):
		animated_sprite.visible = true
		
