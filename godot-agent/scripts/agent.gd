extends CharacterBody2D

enum State { EXPLORE, SEEK, FLEE }

@export var max_speed: float = 140.0
@export var perception_radius: float = 160.0
@export var max_energy: float = 100.0
@export var energy_threshold: float = 30.0
@export var energy_cost_per_pixel: float = 0.05
@export var danger_damage_per_sec: float = 20.0
@export var memory_cell_size: int = 80

var screen_size

var state: State = State.EXPLORE
var energy: float
var is_dead: bool = false

var target_mushroom: Node = null
var flee_from_position: Vector2 = Vector2.ZERO
var last_position: Vector2

var visited_cells := {}
var recent_positions: Array = []
var max_recent_positions := 12
var memory_decay_rate := 0.8

@onready var perception_area: Area2D = $PerceptionArea
@onready var perception_shape: CollisionShape2D = $PerceptionArea/CollisionShape2D
@onready var energy_bar: ProgressBar = $EnergyBar

func _ready():
	energy_bar.max_value = max_energy
	energy_bar.value = energy
	screen_size = get_viewport_rect().size
	energy = max_energy
	last_position = global_position
	var shape = perception_shape.shape
	if shape is CircleShape2D:
		shape.radius = perception_radius
	perception_area.monitoring = true
	perception_area.monitorable = true

func _physics_process(delta):
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_register_current_cell()
	_update_perception()
	_decide_goal()
	_perform_action(delta)
	_apply_energy_decay(delta)
	_check_dead()
	var hit_border = false
	if position.x <= 0 or position.x >= screen_size.x:
		hit_border = true
	if position.y <= 0 or position.y >= screen_size.y:
		hit_border = true
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
	if hit_border:
		wander_change_time = 0

var seen_mushrooms: Array = []
var seen_dangers: Array = []

func _update_perception():
	seen_mushrooms.clear()
	seen_dangers.clear()
	for a in perception_area.get_overlapping_areas():
		if a.is_in_group("mushrooms"):
			seen_mushrooms.append(a)
		elif a.is_in_group("dangers"):
			seen_dangers.append(a)

func _nearest_node(nodes: Array) -> Node:
	if nodes.is_empty():
		return null
	var nearest = nodes[0]
	var min_dist = global_position.distance_to(nearest.global_position)
	for n in nodes:
		var d = global_position.distance_to(n.global_position)
		if d < min_dist:
			min_dist = d
			nearest = n
	return nearest

func _decide_goal():
	if seen_dangers.size() > 0:
		var nearest = _nearest_node(seen_dangers)
		var dist = global_position.distance_to(nearest.global_position)
		if dist < 100:
			state = State.FLEE
			flee_from_position = nearest.global_position
			target_mushroom = null
			return
	if energy < energy_threshold:
		if seen_mushrooms.size() > 0:
			state = State.SEEK
			target_mushroom = _nearest_node(seen_mushrooms)
			return
		else:
			state = State.EXPLORE
			target_mushroom = null
			return
	if seen_mushrooms.size() > 0:
		state = State.SEEK
		target_mushroom = _nearest_node(seen_mushrooms)
		return
	state = State.EXPLORE
	target_mushroom = null

var rng := RandomNumberGenerator.new()
var wander_direction: Vector2 = Vector2.RIGHT
var wander_change_time := 0.0

func _perform_action(delta):
	match state:
		State.EXPLORE:
			_action_explore(delta)
		State.SEEK:
			_action_seek()
		State.FLEE:
			_action_flee()
	if velocity.length() > 0:
		velocity = velocity.limit_length(max_speed)
	move_and_slide()

func _action_explore(delta):
	wander_change_time -= delta

	if wander_change_time <= 0:

		var best_direction = Vector2.ZERO
		var best_score = INF

		for i in 16:
			var angle = i * TAU / 16
			var dir = Vector2(cos(angle), sin(angle)).normalized()
			var test_pos = global_position + dir * 120

			var score = 0.0

			# Border penalty
			var energy_ratio = energy / max_energy
			var risk_factor = 1.0 - energy_ratio

			var border_penalty = 0.0

			if test_pos.x < 40 or test_pos.x > screen_size.x - 40:
				border_penalty += 2000

			if test_pos.y < 40 or test_pos.y > screen_size.y - 40:
				border_penalty += 2000

			# if energy is low, reduce penalty
			border_penalty *= (1.0 - risk_factor * 0.8)

			# check if there's a resource near border
			var reward_bonus = 0.0
			var resource_near_border = false

			for mushroom in seen_mushrooms:
				var dist = test_pos.distance_to(mushroom.global_position)

				if dist < 150:
					resource_near_border = true
					reward_bonus -= 2500  # reward > penalty

			# reduces penalty if there is a resource
			if resource_near_border:
				score += reward_bonus
			else:
				score += border_penalty

			# Danger penalty

			for danger in seen_dangers:
				var dist = test_pos.distance_to(danger.global_position)

				if dist < danger.radius:
					score += 5000
				elif dist < danger.radius + 40:
					score += 2000

			# Memory penalty

			var cell = Vector2(
				int(test_pos.x / memory_cell_size),
				int(test_pos.y / memory_cell_size)
			)

			# Cell penalty
			score += visited_cells.get(cell, 0) * 15

			# Recent position penalty
			for recent_pos in recent_positions:
				if test_pos.distance_to(recent_pos) < 50:
					score += 300

			# choose best direction
			
			score += rng.randf_range(-50, 50)
			if score < best_score:
				best_score = score
				best_direction = dir

		if best_direction == Vector2.ZERO:
			best_direction = Vector2.RIGHT

		wander_direction = best_direction
		wander_change_time = 1.0
	velocity = wander_direction * max_speed * 0.6

func _action_seek():
	if not target_mushroom or not is_instance_valid(target_mushroom):
		state = State.EXPLORE
		return
	var dir = (target_mushroom.global_position - global_position).normalized()
	velocity = dir * max_speed
	if global_position.distance_to(target_mushroom.global_position) < 30:
		_collect_mushroom(target_mushroom)

func _action_flee():

	var dir = (global_position - flee_from_position).normalized()

	velocity = dir * max_speed * 1.2

	# exits state when is safe
	var safe_distance = perception_radius + 60

	if global_position.distance_to(flee_from_position) > safe_distance:
		state = State.EXPLORE

func _collect_mushroom(mushroom):
	if not is_instance_valid(mushroom):
		return
	energy = min(max_energy, energy + mushroom.get_energy_amount())
	mushroom.collect()
	target_mushroom = null
	state = State.EXPLORE

func _apply_energy_decay(delta):

	var dist_moved = global_position.distance_to(last_position)

	if dist_moved > 0:
		energy -= dist_moved * energy_cost_per_pixel

	last_position = global_position

	

	energy = clamp(energy, 0.0, max_energy)
	energy_bar.value = energy

func _check_dead():
	if energy <= 0 and not is_dead:
		energy = 0
		is_dead = true
		velocity = Vector2.ZERO

func _register_current_cell():
	var cell = Vector2(
		int(global_position.x / memory_cell_size),
		int(global_position.y / memory_cell_size)
	)

	# Incrementa célula atual
	if not visited_cells.has(cell):
		visited_cells[cell] = 0
	visited_cells[cell] += 1

	# 🔥 Decaimento da memória global
	for key in visited_cells.keys():
		visited_cells[key] *= memory_decay_rate
		if visited_cells[key] < 0.1:
			visited_cells.erase(key)

	# 🧠 Memória de caminho recente (anti loop curto)
	recent_positions.append(global_position)

	if recent_positions.size() > max_recent_positions:
		recent_positions.pop_front()
