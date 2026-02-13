extends Node2D
@onready var key : Area2D = $"../Key"
# Called when the node enters the scene tree for the first time
var pressed := false
var items_on_plate := 0

func _ready() -> void:
	if(!LevelState.plates_exists):
		key._update_key_state()
		LevelState.plates_exists = true

	LevelState.plate_amount += 1

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("Movable_Box"):
		pressed = true
		$AnimatedSprite2D.play("pressed")
		items_on_plate += 1
		LevelState.plates_pressed += 1
		LevelState.check_plates_pressed()
		
		if(LevelState.all_plates_pressed && !key.is_claimed):
			key._update_key_state()
		
		



func _on_area_2d_body_exited(body: Node2D) -> void:
	# Check if anything is still on the plate
	if  body.is_in_group("player") or body.is_in_group("Movable_Box"):
		items_on_plate -= 1
		LevelState.plates_pressed -= 1
	if (items_on_plate <= 0):
		pressed = false
		$AnimatedSprite2D.play("unpressed")		
	LevelState.check_plates_pressed()
	if(!LevelState.all_plates_pressed && !key.is_claimed):
		key._update_key_state()
		
func update_plate_direction(gravity_vector: Vector2):
	$Area2D.position = gravity_vector * -6
