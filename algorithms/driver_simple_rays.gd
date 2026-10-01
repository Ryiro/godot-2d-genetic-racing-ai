class_name DriverSimpleRays
extends BaseDriver

var look_ahead_distance: float = 120.0
var side_sensor_angle: float = deg_to_rad(55.0)

var tick_interval: float = 0.05
var tick_timer: float = 0.0

var cached_forward: float = 1.0
var cached_turn: float = 0.0

func evaluate_inputs(delta: float) -> Dictionary:
	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		_make_decision()

	return {
		"forward": cached_forward,
		"turn": cached_turn
	}

func _make_decision() -> void:
	if not is_instance_valid(car):
		return

	var space_state = car.get_world_2d().direct_space_state
	var car_pos = car.global_position
	var forward_dir = Vector2.from_angle(car.rotation)

	# 1. Cast 3 rays: Center (0°), Left (-55°), Right (+55°)
	var center_hit = _cast_ray(space_state, car_pos, forward_dir)
	var left_hit = _cast_ray(space_state, car_pos, forward_dir.rotated(-side_sensor_angle))
	var right_hit = _cast_ray(space_state, car_pos, forward_dir.rotated(side_sensor_angle))

	var center_dist = (center_hit.position - car_pos).length() if not center_hit.is_empty() else look_ahead_distance
	var left_dist = (left_hit.position - car_pos).length() if not left_hit.is_empty() else look_ahead_distance
	var right_dist = (right_hit.position - car_pos).length() if not right_hit.is_empty() else look_ahead_distance

	# 2. Continuous Proportional Steering:
	# If right_dist > left_dist (left wall closer) -> diff is positive -> steer Right (+).
	# If left_dist > right_dist (right wall closer) -> diff is negative -> steer Left (-).
	var diff = right_dist - left_dist
	cached_turn = clamp(diff / 50.0, -1.0, 1.0)

	# 3. Head-on avoidance if approaching a wall in front
	if not center_hit.is_empty() and center_dist < 70.0:
		# Slow down for sharp corner
		cached_forward = 0.4
		# Steer hard toward whichever side has more room
		cached_turn = 1.0 if right_dist >= left_dist else -1.0
	else:
		cached_forward = 1.0

func _cast_ray(space_state: PhysicsDirectSpaceState2D, origin: Vector2, direction: Vector2) -> Dictionary:
	var target = origin + (direction * look_ahead_distance)
	var query = PhysicsRayQueryParameters2D.create(origin, target)
	query.exclude = [car.get_rid()]
	return space_state.intersect_ray(query)
