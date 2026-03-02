# scenes/Agent.gd
extends CharacterBody2D

# --- PAGE architecture mapping ---
# Environment -> nodes: Mushrooms (Area2D), DangerAreas (Area2D)
# Perception -> Area2D child (Perception)
# Goal -> prioridade interna (manter energia > limiar, coletar, evitar)
# Action -> movimento: explorar, seek, flee

enum State { EXPLORE, SEEK, FLEE, IDLE }
var screen_size

# parâmetros
@export var max_speed: float = 140.0
@export var perception_radius: float = 160.0
@export var max_energy: float = 100.0
@export var energy_threshold: float = 30.0  # prioridade para recolher se abaixo
@export var energy_depletion_move: float = 5.0  # por segundo quando anda
@export var danger_damage_per_sec: float = 20.0

# estado interno
var energy: float
var state: State = State.EXPLORE
var target_mushroom: Node = null
var flee_from_position: Vector2 = Vector2.ZERO

# nós
@onready var perception_area: Area2D = $PerceptionArea
@onready var perception_shape: CollisionShape2D = $PerceptionArea/CollisionShape2D

func _ready():
	screen_size = get_viewport_rect().size
	name = "Agent"
	energy = max_energy
	# ajusta área de percepção
	var shape = perception_shape.shape
	if shape is CircleShape2D:
		shape.radius = perception_radius
	perception_area.monitoring = true
	perception_area.monitorable = true
	set_process(true)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_update_perception()
	_decide_goal()
	_perform_action(delta)
	_apply_energy_decay(delta)
	_check_dead()
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)

# PERCEPTION
var seen_mushrooms: Array = []
var seen_dangers: Array = []

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

func _update_perception() -> void:
	seen_mushrooms.clear()
	seen_dangers.clear()
	var areas = perception_area.get_overlapping_areas()
	for a in areas:
		print("Detectou algo:", a.name)
		if a is Area2D:
			if a.has_method("energy_amount"):
				seen_mushrooms.append(a)
			elif a.name.begins_with("Danger"):
				seen_dangers.append(a)
			else:
				# tentativa de distinguir por sinal
				if a.has_method("set_radius_scale"):
					seen_dangers.append(a)
	# também checa colisões ponto-a-ponto (se estiver dentro de uma danger, pode levar dano)
	# (mais adiante no _apply_energy_decay usamos distâncias)

# GOAL (priorização)
func _decide_goal() -> void:
	# 1) Se perigo muito perto -> fugir
	if seen_dangers.size() > 0:
		# pega o perigo mais próximo
		var nearest_danger = _nearest_node(seen_dangers)
		var dist = nearest_danger.global_position.distance_to(global_position)
		if dist < (nearest_danger.radius if nearest_danger.has_method("radius") else 120):
			state = State.FLEE
			flee_from_position = nearest_danger.global_position
			target_mushroom = null
			return

	# 2) Se energia baixa -> procurar cogumelo
	if energy < energy_threshold:
		# se enxergou cogumelos, vai para o mais próximo
		if seen_mushrooms.size() > 0:
			target_mushroom = _nearest_node(seen_mushrooms)
			state = State.SEEK
			return
		else:
			# se não vê, explorar com prioridade de encontrar cogumelos (random walk)
			state = State.EXPLORE
			target_mushroom = null
			return

	# 3) Se viu um cogumelo e está com energia normal -> pode coletar
	if seen_mushrooms.size() > 0:
		target_mushroom = _nearest_node(seen_mushrooms)
		state = State.SEEK
		return

	# default
	state = State.EXPLORE
	target_mushroom = null

# ACTIONS
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
	# aplica movimento
	if velocity.length() > 0:
		velocity = velocity.limit_length(max_speed)
	
	move_and_slide()
	

func _action_explore(delta: float) -> void:
	# passeio aleatório suave (mudamos direção de vez em quando)
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
	# se estiver bem perto, coleta automaticamente (simular colisão)
	if global_position.distance_to(target_mushroom.global_position) < 18:
		_collect_mushroom(target_mushroom)

func _action_flee(delta: float) -> void:
	# move-se na direção oposta do perigo
	var dir = (global_position - flee_from_position).normalized()
	velocity = dir * max_speed * 1.1
	# se longe o suficiente, volta a explorar
	if global_position.distance_to(flee_from_position) > perception_radius * 1.2:
		state = State.EXPLORE

# interação de coleta
func _collect_mushroom(mushroom: Node) -> void:
	if not mushroom or not is_instance_valid(mushroom):
		return
	# supomos que o mushroom tem 'energy_amount' (no nosso Mushroom.gd)
	var amount = 0
	if "energy_amount" in mushroom:
		amount = mushroom.energy_amount
	elif mushroom.has_method("get_energy_amount"):
		amount = mushroom.get_energy_amount()
	energy = min(max_energy, energy + amount)
	# atualiza estado e pede ao jogo para spawnar outro
	# Se o cogumelo já se removeu via sinal, apenas atualizamos energia.
	# Também podemos emitir um som ou animação aqui.
	# Não tentamos queue_free aqui porque o cogumelo já faz isso ao detectar o Agent
	target_mushroom = null
	state = State.EXPLORE

# Energia: caminhar gasta energia; ficar em danger causa dano
func _apply_energy_decay(delta: float) -> void:
	# gasto por movimento
	if velocity.length() > 1.0:
		energy -= energy_depletion_move * delta
	# dano ao ficar dentro de uma danger (se estiver sobrepondo alguma danger)
	var areas = perception_area.get_overlapping_areas()
	for a in areas:
		if a and a.has_method("set_radius_scale"):
			# está dentro de uma zona perigosa
			energy -= danger_damage_per_sec * delta

	# bloqueia energia entre 0 e max
	energy = clamp(energy, 0.0, max_energy)

func _check_dead() -> void:
	if energy <= 0.0:
		state = State.IDLE
		velocity = Vector2.ZERO
		# mostra que morreu (pode adicionar animação)
		# Para simplicidade: paramos tudo. Você pode reiniciar cena ou reabastecer depois.
