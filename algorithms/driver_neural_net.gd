class_name DriverNeuralNet
extends BaseDriver

var brain: NeuralNetwork
var has_finished: bool = false
var is_disqualified: bool = false
var fitness: float = 0.0
var current_segment_idx: int = 0
# 5 Balanced Raycasts: -60°, -30°, 0°, 30°, 60°
var ray_range: float = 220.0
var ray_angles: Array[float] = [-1.047, -0.524, 0.0, 0.524, 1.047]

# Metrics
var highest_segment_reached: int = 0
var time_taken: float = 0.0
var wall_hits: int = 0
var current_heading_error: float = 0.0

# Anti-Reversal Watchdog
var wrong_way_timer: float = 0.0

func _init(p_brain: NeuralNetwork = null) -> void:
	if p_brain != null:
		brain = p_brain
	else:
		brain = NeuralNetwork.new(7, 6, 2)

func evaluate_inputs(delta: float) -> Dictionary:
	if has_finished or is_disqualified or not is_instance_valid(car):
		return {"forward": 0.0, "turn": 0.0}

	time_taken += delta

	# Track wall contacts
	if car.get_slide_collision_count() > 0:
		wall_hits += 1

	# 1. Cast Rays
	var space_state = car.get_world_2d().direct_space_state
	var car_pos = car.global_position
	var inputs: Array = []

	for angle in ray_angles:
		var dir = Vector2.from_angle(car.rotation + angle)
		var target = car_pos + (dir * ray_range)
		var query = PhysicsRayQueryParameters2D.create(car_pos, target)
		query.exclude = [car.get_rid()]
		var hit = space_state.intersect_ray(query)

		if hit.is_empty():
			inputs.append(1.0)
		else:
			var dist = (hit.position - car_pos).length() / ray_range
			inputs.append(clamp(dist, 0.0, 1.0))

	# Input 6: Normalized forward speed [0.0, 1.0]
	var speed = car.velocity.length()
	inputs.append(clamp(speed / car.max_speed, 0.0, 1.0))

	# Input 7: Normalized track alignment [-1.0, 1.0]
	inputs.append(clamp(current_heading_error / PI, -1.0, 1.0))

	# 2. Forward pass
	var outputs = brain.predict(inputs)
	var forward_cmd = clamp(outputs[0], -1.0, 1.0)
	var turn_cmd = clamp(outputs[1], -1.0, 1.0)

	return {
		"forward": forward_cmd,
		"turn": turn_cmd
	}

func update_progress(p_segment_idx: int, total_segments: int, track_tangent: Vector2, delta: float) -> void:
	if has_finished or is_disqualified or not is_instance_valid(car):
		return

	current_segment_idx = p_segment_idx

	var car_heading = Vector2.from_angle(car.rotation)
	current_heading_error = car_heading.angle_to(track_tangent)

	# Forward alignment check against local track tangent
	var forward_alignment = car_heading.dot(track_tangent)
	if forward_alignment < -0.1:
		wrong_way_timer += delta
		if wrong_way_timer > 0.35:
			disqualify()
			return
	else:
		wrong_way_timer = max(0.0, wrong_way_timer - (delta * 2.0))

	# Progression check (must progress forward sequentially)
	var quarter = total_segments / 4
	var three_quarters = total_segments * 3 / 4

	# Only register forward steps, never backwards
	if current_segment_idx > highest_segment_reached and current_segment_idx < highest_segment_reached + quarter:
		highest_segment_reached = current_segment_idx

	# Lap completion
	if highest_segment_reached > three_quarters and current_segment_idx < total_segments / 8:
		complete_lap()
func complete_lap() -> void:
	has_finished = true
	if is_instance_valid(car):
		car.current_speed = 0.0
		car.velocity = Vector2.ZERO
		car.modulate = Color(0.2, 1.0, 0.4, 0.85)

func disqualify() -> void:
	is_disqualified = true
	if is_instance_valid(car):
		car.current_speed = 0.0
		car.velocity = Vector2.ZERO
		car.modulate = Color(0.3, 0.3, 0.3, 0.3) # Ghost out / gray out disqualified car

func calculate_final_fitness() -> void:
	if has_finished:
		var time_bonus = max(0.0, (50.0 - time_taken) * 1200.0)
		var wall_penalty = wall_hits * 200.0
		fitness = 100000.0 + time_bonus - wall_penalty
	else:
		# If disqualified for driving backward, slash its score to near zero
		var progress_pts = highest_segment_reached * 100.0
		var wall_penalty = wall_hits * 35.0
		var score = progress_pts - wall_penalty
		if is_disqualified:
			score *= 0.1 # Heavily degraded parent candidacy
		fitness = max(1.0, score)
