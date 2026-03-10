extends CharacterBody2D


const SPEED = 130.0
const BASE_JUMP_VELOCITY = -250.0
var JUMP_VELOCITY = BASE_JUMP_VELOCITY
const PUSH_FORCE = 30.0
var can_tp = true

var assist_applied_this_level: bool = false
var assist_boost_amount: float = 25.0


@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

func _restart_level() -> void:
	JUMP_VELOCITY = BASE_JUMP_VELOCITY
	assist_applied_this_level = false
	LevelState.record_restart()
	get_tree().reload_current_scene()
	LevelState.reset_for_level()

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		PhysicsServer2D.area_set_param(
			get_viewport().find_world_2d().space,
			PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR,
			Vector2.DOWN
		)
		FirebaseManager.log_restart()
		call_deferred("_restart_level")

	boost_stats()

	var gravity_vector = PhysicsServer2D.area_get_param(
		get_viewport().find_world_2d().space,
		PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR
	)

	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_pressed("jump") and is_on_floor():
		if gravity_vector == Vector2.UP:
			velocity.y = -JUMP_VELOCITY
			print("jumped_down")
		elif gravity_vector == Vector2.DOWN:
			velocity.y = JUMP_VELOCITY
		elif gravity_vector == Vector2.RIGHT:
			velocity.x = JUMP_VELOCITY
		elif gravity_vector == Vector2.LEFT:
			velocity.x = -JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	var move_dir := 0

	if gravity_vector == Vector2.DOWN:
		move_dir = sign(velocity.x)
	elif gravity_vector == Vector2.UP:
		move_dir = -sign(velocity.x)
	elif gravity_vector == Vector2.RIGHT:
		move_dir = -sign(velocity.y)
	elif gravity_vector == Vector2.LEFT:
		move_dir = sign(velocity.y)

	if move_dir > 0:
		animated_sprite.flip_h = false
	elif move_dir < 0:
		animated_sprite.flip_h = true

	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")

	if direction:
		if gravity_vector == Vector2.UP or gravity_vector == Vector2.DOWN:
			velocity.x = direction * SPEED
		else:
			velocity.y = direction * SPEED
	else:
		if gravity_vector == Vector2.UP or gravity_vector == Vector2.DOWN:
			velocity.x = move_toward(velocity.x, 0, SPEED)
		else:
			velocity.y = move_toward(velocity.y, 0, SPEED)

	move_and_slide()

	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_collider() is RigidBody2D:
			c.get_collider().apply_central_impulse(-c.get_normal() * PUSH_FORCE)
			
func boost_stats() -> void:
	if assist_applied_this_level:
		return

	var baseline := LevelState.get_baseline_time_seconds()
	if baseline <= 0.0:
		return

	var current_time := RunTimer.get_level_elapsed_seconds()
	var trigger_time := baseline * 0.75

	if current_time >= trigger_time:
		JUMP_VELOCITY = BASE_JUMP_VELOCITY - assist_boost_amount
		assist_applied_this_level = true
		LevelState.mark_assist_triggered()
		print("Assist applied. New jump velocity: ", JUMP_VELOCITY)
	
	
	
