extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -250.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

func _physics_process(delta: float) -> void:
	# Add the gravity.
	var gravity_vector = PhysicsServer2D.area_get_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR)
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		if(gravity_vector == Vector2.UP):
			velocity.y = -JUMP_VELOCITY
			print("jumped_down")
		elif(gravity_vector == Vector2.DOWN):
			velocity.y = JUMP_VELOCITY


	#get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
		
	#Flip the Sprite/Character
	if direction > 0:
		animated_sprite.flip_h = false
	elif direction < 0:
		animated_sprite.flip_h = true
		
	#Play Animation
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else :
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump") 
	
	#Apply movement
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if(body.is_in_group("Movable_Box")):
		body.collision_layer = 1
		body.collision_mask = 1
		


func _on_area_2d_body_exited(body: Node2D) -> void:
	if(body.is_in_group("Movable_Box")):
		body.collision_layer = 2
		body.collision_mask = 2
