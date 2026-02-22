extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -250.0
const PUSH_FORCE = 30.0
var can_tp = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

func _restart_level() -> void:
	get_tree().reload_current_scene()
	LevelState.reset_for_level()

func _physics_process(delta: float) -> void:
	# Level restart keybind
	if Input.is_action_just_pressed("restart"):
		PhysicsServer2D.area_set_param(
			get_viewport().find_world_2d().space,
			PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR,
			Vector2.DOWN
		)
		call_deferred("_restart_level")
	
	# Add the gravity.
	var gravity_vector = PhysicsServer2D.area_get_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR)
	if not is_on_floor():
		velocity += get_gravity() * delta
	# Handle jump.
	if Input.is_action_pressed("jump") and is_on_floor():
		if(gravity_vector == Vector2.UP):
			velocity.y = -JUMP_VELOCITY
			print("jumped_down")
		elif(gravity_vector == Vector2.DOWN):
			velocity.y = JUMP_VELOCITY
		elif(gravity_vector == Vector2.RIGHT):
			velocity.x = JUMP_VELOCITY
		elif(gravity_vector == Vector2.LEFT):
			velocity.x = -JUMP_VELOCITY


	#get the input direction: -1, 0, 1
	var direction := Input.get_axis("move_left", "move_right")
		
	# Determine movement direction relative to gravity
	var move_dir := 0

	if gravity_vector == Vector2.DOWN:
		move_dir = sign(velocity.x)
	elif gravity_vector == Vector2.UP:
		move_dir = -sign(velocity.x)   # reversed because player is upside down
	elif gravity_vector == Vector2.RIGHT:
		move_dir = -sign(velocity.y)
	elif gravity_vector == Vector2.LEFT:
		move_dir = sign(velocity.y)   # reversed because player is rotated

	# Apply flipping
	if move_dir > 0:
		animated_sprite.flip_h = false
	elif move_dir < 0:
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
		if(gravity_vector == Vector2.UP || gravity_vector == Vector2.DOWN):
			velocity.x = direction * SPEED
		else:
			velocity.y = direction * SPEED
	else:
		if(gravity_vector == Vector2.UP || gravity_vector == Vector2.DOWN):
			velocity.x = move_toward(velocity.x, 0, SPEED)
		else: 
			velocity.y = move_toward(velocity.y, 0, SPEED)


	move_and_slide()
	
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			c.get_collider().apply_central_impulse(-c.get_normal() * PUSH_FORCE)
