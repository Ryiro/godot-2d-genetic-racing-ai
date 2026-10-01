extends Node2D

const CAR_SCENE = preload("res://car.tscn")

@export_group("Simulation Settings")
@export var population_size: int = 15
@export var max_lap_duration: float = 20.0

@export_group("Track Geometry")
@export var track_width: float = 85.0
@export var smoothness_passes: int = 4

var left_wall_points: PackedVector2Array = []
var right_wall_points: PackedVector2Array = []
var center_points: PackedVector2Array = []
var track_forward_dir: Vector2 = Vector2.ZERO
var total_segments: int = 0
var spawn_pos: Vector2 = Vector2.ZERO
var spawn_rot: float = 0.0

# GA State
var cars: Array[CharacterBody2D] = []
var drivers: Array[DriverNeuralNet] = []
var generation: int = 1
var gen_timer: float = 0.0
var all_time_best_time: float = -1.0
var best_brain_ever: NeuralNetwork = null

# Sim speed toggle: 1x, 2x, 5x, 10x
var sim_speed_presets: Array[float] = [1.0, 2.0, 5.0, 10.0]
var speed_idx: int = 0

var hud_label: Label

func _ready() -> void:
	Engine.time_scale = 1.0
	generate_custom_circuit()
	build_track_visuals_and_colliders()
	setup_hud()
	start_generation([])

func _physics_process(delta: float) -> void:
	gen_timer += delta
	var finished_count: int = 0
	var current_gen_best_time: float = -1.0
	var active_count: int = 0

	for i in range(cars.size()):
		var car = cars[i]
		var driver = drivers[i]

		if not is_instance_valid(car):
			continue

		if driver.has_finished:
			finished_count += 1
			if current_gen_best_time < 0.0 or driver.time_taken < current_gen_best_time:
				current_gen_best_time = driver.time_taken
		elif not driver.is_disqualified:
			active_count += 1
			
			# Constrained search: search within +/- 15 segments of current known position
			# This prevents cars from locking onto parallel track sections across the grass!
			var current_seg = driver.current_segment_idx
			var closest_idx = _get_local_closest_track_point(car.global_position, current_seg, 20)
			
			# Lookahead: 6 segments down the road
			var lookahead_idx = (closest_idx + 6) % total_segments
			var next_lookahead = (lookahead_idx + 1) % total_segments
			var target_tangent = (center_points[next_lookahead] - center_points[lookahead_idx]).normalized()
			
			driver.update_progress(closest_idx, total_segments, target_tangent, delta)

	if current_gen_best_time > 0.0:
		if all_time_best_time < 0.0 or current_gen_best_time < all_time_best_time:
			all_time_best_time = current_gen_best_time

	update_hud(finished_count, current_gen_best_time)

	if active_count == 0 or gen_timer >= max_lap_duration:
		_evolve_next_generation()

# Localized search window prevents jumping across grass to wrong track sections
func _get_local_closest_track_point(pos: Vector2, current_idx: int, window: int) -> int:
	var best_idx = current_idx
	var min_dist_sq = INF

	for offset in range(-window, window + 1):
		var idx = (current_idx + offset + total_segments) % total_segments
		var d = pos.distance_squared_to(center_points[idx])
		if d < min_dist_sq:
			min_dist_sq = d
			best_idx = idx

	return best_idx
func update_hud(finished_count: int, best_this_gen: float) -> void:
	var time_left = max(0.0, max_lap_duration - gen_timer)
	var best_str = ("%.2fs" % best_this_gen) if best_this_gen > 0.0 else "--"
	var record_str = ("%.2fs" % all_time_best_time) if all_time_best_time > 0.0 else "--"

	hud_label.text = "GEN: %d | FINISHED: %d/%d | TIME LEFT: %.1fs\nBEST THIS GEN: %s | RECORD: %s\nSPEED: %.0fx ([Space] Toggle | [Esc] Quit)" % [
		generation, finished_count, population_size, time_left, best_str, record_str, sim_speed_presets[speed_idx]
	]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_SPACE:
			speed_idx = (speed_idx + 1) % sim_speed_presets.size()
			Engine.time_scale = sim_speed_presets[speed_idx]

func _get_closest_track_point(pos: Vector2) -> int:
	var closest_idx: int = 0
	var min_dist_sq: float = INF
	for i in range(0, total_segments, 2):
		var d = pos.distance_squared_to(center_points[i])
		if d < min_dist_sq:
			min_dist_sq = d
			closest_idx = i
	return closest_idx

func start_generation(brains: Array) -> void:
	gen_timer = 0.0

	for c in cars:
		if is_instance_valid(c):
			c.queue_free()
	cars.clear()
	drivers.clear()

	for i in range(population_size):
		var car = CAR_SCENE.instantiate()
		car.position = spawn_pos
		car.rotation = spawn_rot

		var brain: NeuralNetwork
		if brains.size() > i:
			brain = brains[i]
		else:
			brain = NeuralNetwork.new(7, 6, 2)

		var driver = DriverNeuralNet.new(brain)
		car.set_driver(driver)
		car.modulate = Color.from_hsv(float(i) / float(population_size), 0.75, 0.95, 0.75)

		add_child(car)
		cars.append(car)
		drivers.append(driver)

func _evolve_next_generation() -> void:
	generation += 1

	for d in drivers:
		d.calculate_final_fitness()

	# Sort descending: highest fitness first
	drivers.sort_custom(func(a, b): return a.fitness > b.fitness)

	if drivers[0].has_finished:
		if best_brain_ever == null or drivers[0].time_taken <= all_time_best_time:
			best_brain_ever = drivers[0].brain.clone()

	var next_brains: Array = []

	# 1. ELITISM: Top 2 from the generation pass completely untouched
	next_brains.append(drivers[0].brain.clone())
	next_brains.append(drivers[1].brain.clone())

	# 2. SELECT TOP 5 PARENT POOL
	var top_5_pool: Array[NeuralNetwork] = []
	for i in range(min(5, drivers.size())):
		top_5_pool.append(drivers[i].brain)

	# 3. DIRECT CLONES WITH MICRO-MUTATIONS (60% of field)
	while next_brains.size() < int(population_size * 0.65):
		var parent = top_5_pool[randi() % top_5_pool.size()]
		var child = parent.clone()
		child.mutate(0.08, 0.06)
		next_brains.append(child)

	# 4. CROSSOVER WITHIN TOP 5 (25% of field)
	while next_brains.size() < int(population_size * 0.90):
		var p1 = top_5_pool[randi() % top_5_pool.size()]
		var p2 = top_5_pool[randi() % top_5_pool.size()]
		var child = p1.crossover(p2)
		child.mutate(0.05, 0.05)
		next_brains.append(child)

	# 5. RANDOM IMMIGRANTS (10% fresh DNA to prevent population dead-ends)
	while next_brains.size() < population_size:
		next_brains.append(NeuralNetwork.new(7, 6, 2))

	start_generation(next_brains)

func generate_custom_circuit() -> void:
	var anchors: Array[Vector2] = [
		Vector2(100, 360),
		Vector2(-220, 360),
		Vector2(-460, 350),
		Vector2(-580, 290),
		Vector2(-640, 180),
		Vector2(-620, 70),
		Vector2(-540, -10),
		Vector2(-490, -70),
		Vector2(-530, -140),
		Vector2(-610, -220),
		Vector2(-570, -320),
		Vector2(-440, -370),
		Vector2(-180, -370),
		Vector2(140, -360),
		Vector2(380, -340),
		Vector2(560, -270),
		Vector2(650, -160),
		Vector2(680, -20),
		Vector2(640, 110),
		Vector2(530, 210),
		Vector2(380, 260),
		Vector2(330, 275),
		Vector2(285, 310),
		Vector2(245, 355),
		Vector2(210, 375),
		Vector2(180, 360)
	]

	var smoothed: Array[Vector2] = anchors
	for p in range(smoothness_passes):
		smoothed = _chaikin_subdivide(smoothed)

	center_points = PackedVector2Array(smoothed)
	left_wall_points.clear()
	right_wall_points.clear()
	var count = center_points.size()
	var half_w = track_width / 2.0

	for i in range(count):
		var prev_pt = center_points[(i - 1 + count) % count]
		var curr_pt = center_points[i]
		var next_pt = center_points[(i + 1) % count]

		var forward = (next_pt - prev_pt).normalized()
		var normal = Vector2(-forward.y, forward.x)

		left_wall_points.append(curr_pt + normal * half_w)
		right_wall_points.append(curr_pt - normal * half_w)

	left_wall_points.append(left_wall_points[0])
	right_wall_points.append(right_wall_points[0])
	center_points.append(center_points[0])

	total_segments = center_points.size() - 1
	# Spawn 20px PAST the start line, pointing cleanly down the straight towards segment 1 & 2
	track_forward_dir = (center_points[1] - center_points[0]).normalized()
	spawn_pos = center_points[0] + (track_forward_dir * 20.0)
	spawn_rot = track_forward_dir.angle()

func _chaikin_subdivide(pts: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var n = pts.size()
	for i in range(n):
		var p0 = pts[i]
		var p1 = pts[(i + 1) % n]
		result.append(p0 * 0.75 + p1 * 0.25)
		result.append(p0 * 0.25 + p1 * 0.75)
	return result

func build_track_visuals_and_colliders() -> void:
	_create_boundary("OuterWall", left_wall_points)
	_create_boundary("InnerWall", right_wall_points)

	var center_line = Line2D.new()
	center_line.points = center_points
	center_line.width = 2.0
	center_line.default_color = Color(1.0, 1.0, 1.0, 0.2)
	add_child(center_line)

	var gate = Line2D.new()
	gate.points = PackedVector2Array([left_wall_points[0], right_wall_points[0]])
	gate.width = 8.0
	gate.default_color = Color(1.0, 0.2, 0.2, 0.95)
	add_child(gate)

func _create_boundary(body_name: String, points: PackedVector2Array) -> void:
	var static_body = StaticBody2D.new()
	static_body.name = body_name
	for i in range(points.size() - 1):
		var segment = SegmentShape2D.new()
		segment.a = points[i]
		segment.b = points[i + 1]
		var col = CollisionShape2D.new()
		col.shape = segment
		static_body.add_child(col)

	var line = Line2D.new()
	line.points = points
	line.width = 5.0
	line.default_color = Color.WHITE
	add_child(static_body)
	add_child(line)

func setup_hud() -> void:
	var canvas_layer = CanvasLayer.new()
	hud_label = Label.new()
	hud_label.position = Vector2(40, 30)
	hud_label.add_theme_font_size_override("font_size", 20)
	canvas_layer.add_child(hud_label)
	add_child(canvas_layer)
