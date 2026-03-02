extends CharacterBody2D

enum State { EXPLORE, SEEK, FLEE, IDLE }

var screen_size

var last_position: Vector2
@export var energy_cost_per_pixel: float = 0.02
@export var max_speed: float = 140.0
@export var perception_radius: float = 160.0
@export var max_energy: float = 100.0
@export var energy_threshold: float = 30.0
@export var energy_depletion_move: float = 5.0
@export var danger_damage_per_sec: float = 20.0

var energy: float
var state: State = State.EXPLORE
var target_mushroom: Node = null
var flee_from_position: Vector2 = Vector2.ZERO

@onready var perception_area: Area2D = $PerceptionArea
@onready var perception_shape: CollisionShape2D = $PerceptionArea/CollisionShape2D

func _ready():
	last_position = global_position
	screen_size = get_viewport_rect().size
	name = "Agent"
	energy = max_energy
	
	var shape = perception_shape.shape
	if shape is CircleShape2D:
		shape.radius = perception_radius

	perception_area.monitoring = true
	perception_area.monitorable = true

func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_update_perception()
	_decide_goal()
	_perform_action(delta)
	_apply_energy_decay(delta)
	_check_dead()
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)

	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)

# ------------------ PERCEPTION ------------------

var seen_mushrooms: Array = []
var seen_dangers: Array = []

func _update_perception() -> void:
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
	var min_distance = global_position.distance_to(nearest.global_position)

	for n in nodes:
		var dist = global_position.distance_to(n.global_position)
		if dist < min_distance:
			min_distance = dist
			nearest = n

	return nearest

# ------------------ GOAL ------------------

func _decide_goal() -> void:
	if seen_dangers.size() > 0:
		var nearest_danger = _nearest_node(seen_dangers)
		var dist = nearest_danger.global_position.distance_to(global_position)
		if dist < 100:
			state = State.FLEE
			flee_from_position = nearest_danger.global_position
			target_mushroom = null
			return

	if energy < energy_threshold:
		if seen_mushrooms.size() > 0:
			target_mushroom = _nearest_node(seen_mushrooms)
			state = State.SEEK
			return
		else:
			state = State.EXPLORE
			target_mushroom = null
			return

	if seen_mushrooms.size() > 0:
		target_mushroom = _nearest_node(seen_mushrooms)
		state = State.SEEK
		return

	state = State.EXPLORE
	target_mushroom = null

# ------------------ ACTIONS ------------------

var rng := RandomNumberGenerator.new()
var wander_direction: Vector2 = Vector2.RIGHT
var wander_change_time := 0.0

func _perform_action(delta: float) -> void:
	match state:
		State.EXPLORE:
			_action_explore(delta)
		State.SEEK:
			_action_seek(delta)
		State.FLEE:
			_action_flee(delta)
		State.IDLE:
			velocity = Vector2.ZERO

	if velocity.length() > 0:
		velocity = velocity.limit_length(max_speed)

	move_and_slide()

func _action_explore(delta: float) -> void:
	wander_change_time -= delta
	if wander_change_time <= 0:
		rng.randomize()
		var angle = rng.randf_range(0, PI * 2)
		wander_direction = Vector2(cos(angle), sin(angle)).normalized()
		wander_change_time = rng.randf_range(1.0, 3.0)

	velocity = wander_direction * max_speed * 0.6

func _action_seek(delta: float) -> void:
	if not target_mushroom or not is_instance_valid(target_mushroom):
		state = State.EXPLORE
		target_mushroom = null
		return

	var dir = (target_mushroom.global_position - global_position).normalized()
	velocity = dir * max_speed

	var dist = global_position.distance_to(target_mushroom.global_position)

	# Distância aumentada para garantir coleta
	if dist < 30:
		_collect_mushroom(target_mushroom)

func _action_flee(delta: float) -> void:
	var dir = (global_position - flee_from_position).normalized()
	velocity = dir * max_speed * 1.1

	if global_position.distance_to(flee_from_position) > perception_radius * 1.2:
		state = State.EXPLORE

# ------------------ COLLECTION ------------------

func _collect_mushroom(mushroom: Node) -> void:
	if not mushroom or not is_instance_valid(mushroom):
		return

	var amount = mushroom.get_energy_amount()

	energy = min(max_energy, energy + amount)

	mushroom.collect()

	print("Agente coletou:", amount)

	target_mushroom = null
	state = State.EXPLORE

# ------------------ ENERGY ------------------

func _apply_energy_decay(delta: float) -> void:
	# -------- Gasto por movimento real --------
	var distance_moved = global_position.distance_to(last_position)

	if distance_moved > 0:
		energy -= distance_moved * energy_cost_per_pixel

	last_position = global_position

	# -------- Dano em áreas perigosas --------
	for a in perception_area.get_overlapping_areas():
		if a.is_in_group("dangers"):
			energy -= danger_damage_per_sec * delta

	energy = clamp(energy, 0.0, max_energy)
	print("energia", energy)

func _check_dead() -> void:
	if energy <= 0.0 and state != State.IDLE:
		energy = 0
		state = State.IDLE
		velocity = Vector2.ZERO
		print("AGENTE MORREU")
