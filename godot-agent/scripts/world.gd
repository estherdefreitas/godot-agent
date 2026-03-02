extends Node2D

const MAP_BOUNDS: Rect2 = Rect2(0, 0, 1024, 768)
const INITIAL_MUSHROOMS := 10
const DANGER_COUNT := 3
const SPAWN_ATTEMPTS := 100
const AGENT_COUNT := 2

@export var MushroomScene: PackedScene
@export var DangerScene: PackedScene 
@export var AgentScene: PackedScene 

@onready var mushrooms_parent: Node2D = $Mushrooms
@onready var dangers_parent: Node2D = $Dangers
@onready var agent_parent: Node2D = $AgentHolder

func _ready():
	_spawn_agents(AGENT_COUNT)
	_spawn_dangers(DANGER_COUNT)
	_spawn_initial_mushrooms(INITIAL_MUSHROOMS)

func _spawn_agents(n: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in n:
		var agent = AgentScene.instantiate()
		agent_parent.add_child(agent)
		agent.global_position = _random_position_safe(rng)

func _spawn_initial_mushrooms(n: int) -> void:
	for i in n:
		_spawn_mushroom()

func _spawn_dangers(n: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for i in n:
		var danger = DangerScene.instantiate()
		dangers_parent.add_child(danger)
		danger.global_position = _random_position_safe(rng)
		var scale = rng.randf_range(0.6, 1.6)
		danger.set_radius_scale(scale)

func _spawn_mushroom() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for attempt in SPAWN_ATTEMPTS:
		var pos = _random_position_safe(rng)
		var collides = false
		for d in dangers_parent.get_children():
			if d.global_position.distance_to(pos) < d.radius + 24:
				collides = true
				break
		if collides:
			continue
		for agent in agent_parent.get_children():
			if agent.global_position.distance_to(pos) < 40:
				collides = true
				break
		if collides:
			continue
		var m = MushroomScene.instantiate()
		mushrooms_parent.add_child(m)
		m.global_position = pos
		m.collected.connect(on_mushroom_collected)
		return
	var fallback = MushroomScene.instantiate()
	mushrooms_parent.add_child(fallback)
	fallback.global_position = MAP_BOUNDS.size / 2 + Vector2(50, 50)
	fallback.collected.connect(on_mushroom_collected)

func _random_position_safe(rng: RandomNumberGenerator) -> Vector2:
	var x = rng.randi_range(MAP_BOUNDS.position.x + 32, MAP_BOUNDS.position.x + MAP_BOUNDS.size.x - 32)
	var y = rng.randi_range(MAP_BOUNDS.position.y + 32, MAP_BOUNDS.position.y + MAP_BOUNDS.size.y - 32)
	return Vector2(x, y)

func on_mushroom_collected():
	_spawn_mushroom()
