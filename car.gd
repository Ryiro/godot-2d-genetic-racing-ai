extends CharacterBody2D

@export var max_speed: float = 380.0
@export var acceleration: float = 380.0
@export var braking_force: float = 650.0
@export var friction: float = 180.0
@export var turn_speed: float = 3.8

var current_speed: float = 0.0
var driver: BaseDriver = null

func set_driver(p_driver: BaseDriver) -> void:
	driver = p_driver
	driver.setup(self)

func _physics_process(delta: float) -> void:
	var forward_cmd: float = 0.0
	var turn_cmd: float = 0.0

	if driver != null:
		var command = driver.evaluate_inputs(delta)
		forward_cmd = command.get("forward", 0.0)
		turn_cmd = command.get("turn", 0.0)
	else:
		# Manual fallback controls
		if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W): forward_cmd += 1.0
		if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S): forward_cmd -= 1.0
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A): turn_cmd -= 1.0
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D): turn_cmd += 1.0

	# In _physics_process:
	if forward_cmd > 0.0:
		current_speed += forward_cmd * acceleration * delta
		current_speed = min(current_speed, max_speed)
	elif forward_cmd < 0.0:
		if current_speed > 10.0:
			current_speed += forward_cmd * braking_force * delta
		else:
			# Strict reverse cap: practically stationary (max 20 px/s)
			current_speed = max(current_speed + forward_cmd * 80.0 * delta, -20.0)
	else:
		current_speed = move_toward(current_speed, 0.0, friction * delta)

	# 2. Steering (Scales with motion, no stationary spinning)
	if abs(current_speed) > 5.0:
		var dir_factor = 1.0 if current_speed >= 0.0 else -1.0
		rotation += turn_cmd * turn_speed * dir_factor * delta

	# 3. Direct Kinematic Velocity
	velocity = Vector2.from_angle(rotation) * current_speed
	move_and_slide()

	# 4. Pure Natural Wall Collision (Speed scrub without artificial steering)
	if get_slide_collision_count() > 0:
		# Shed 35% speed on impact
		current_speed = current_speed * 0.65
		velocity = Vector2.from_angle(rotation) * current_speed
