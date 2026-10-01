class_name DriverPIDOptimal
extends BaseDriver

# Pure Pursuit parameters
@export var min_lookahead: float = 90.0
@export var max_lookahead: float = 180.0
@export var max_cornering_speed: float = 240.0

# Lap Metrics
var current_lap_time: float = 0.0
var best_lap_time: float = -1.0
var laps_completed: int = 0
var highest_segment_reached: int = 0

var center_points: PackedVector2Array = []
var total_segments: int = 0

func setup(p_car: CharacterBody2D) -> void:
	super.setup(p_car)
	current_lap_time = 0.0
	highest_segment_reached = 0

func set_track_data(p_center: PackedVector2Array) -> void:
	center_points = p_center
	total_segments = center_points.size() - 1

func evaluate_inputs(delta: float) -> Dictionary:
	if not is_instance_valid(car) or center_points.is_empty():
		return {"forward": 0.0, "turn": 0.0}

	current_lap_time += delta

	var car_pos = car.global_position
	var car_speed = car.velocity.length()
	var car_heading = Vector2.from_angle(car.rotation)

	var closest_idx = _get_closest_index(car_pos)
	_update_lap_progress(closest_idx)

	# 1. Pure Pursuit: Lookahead scales smoothly with speed
	var speed_norm = clamp(car_speed / car.max_speed, 0.0, 1.0)
	var lookahead_dist = lerp(min_lookahead, max_lookahead, speed_norm)
	var target_pt = _get_lookahead_point(closest_idx, lookahead_dist)

	# 2. Geometric Steering Angle (Alpha)
	var vec_to_target = target_pt - car_pos
	var alpha = car_heading.angle_to(vec_to_target)

	# Proportional arc curvature steering (zero integral, zero oscillation)
	var turn_cmd = clamp(alpha * 2.2, -1.0, 1.0)

	# 3. Dynamic Speed Control: Slow down if heading error to target is wide
	var forward_cmd = 1.0
	var turn_severity = abs(alpha)

	if turn_severity > 0.45:
		# Sharp corner entry / S-curve transition: brake into target cornering speed
		if car_speed > max_cornering_speed:
			forward_cmd = -0.8 # Decisive trail-brake
		else:
			forward_cmd = 0.35 # Feather throttle through the corner
	elif turn_severity > 0.25:
		# Moderate bend
		if car_speed > 300.0:
			forward_cmd = 0.0 # Coast
		else:
			forward_cmd = 0.7
	else:
		# Straight line: 100% throttle
		forward_cmd = 1.0

	return {
		"forward": forward_cmd,
		"turn": turn_cmd
	}

func _get_lookahead_point(start_idx: int, target_dist: float) -> Vector2:
	var accumulated: float = 0.0
	var curr = start_idx
	while accumulated < target_dist:
		var nxt = (curr + 1) % total_segments
		accumulated += center_points[curr].distance_to(center_points[nxt])
		curr = nxt
	return center_points[curr]

func _get_closest_index(pos: Vector2) -> int:
	var closest: int = 0
	var min_dist_sq: float = INF
	for i in range(0, total_segments, 2):
		var d = pos.distance_squared_to(center_points[i])
		if d < min_dist_sq:
			min_dist_sq = d
			closest = i
	return closest

func _update_lap_progress(current_idx: int) -> void:
	var quarter = total_segments / 4
	var three_quarters = total_segments * 3 / 4

	if current_idx > highest_segment_reached and current_idx < highest_segment_reached + quarter:
		highest_segment_reached = current_idx

	if highest_segment_reached > three_quarters and current_idx < total_segments / 8:
		laps_completed += 1
		if best_lap_time < 0.0 or current_lap_time < best_lap_time:
			best_lap_time = current_lap_time
		current_lap_time = 0.0
		highest_segment_reached = 0
