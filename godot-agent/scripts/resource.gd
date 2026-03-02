# scenes/Mushroom.gd
extends Area2D

signal collected(amount)

@export var energy_amount: int = 20  # default, será alterado no _ready para diversidade
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	# energia variada: pequeno(10), médio(20), grande(40)
	var choice = rng.randi_range(0, 2)
	match choice:
		0:
			energy_amount = 10
			$Sprite2D.modulate = Color(0.7, 0.9, 0.6)
		1:
			energy_amount = 20
			$Sprite2D.modulate = Color(0.5, 0.9, 0.5)
		2:
			energy_amount = 40
			$Sprite2D.modulate = Color(0.9, 0.7, 0.8)
	monitoring = true
	monitorable = true

func collect():
	emit_signal("collected", energy_amount)
	queue_free()
	
func _on_body_entered(body):
	if body.name == "Agent":
		# emite sinal e remove-se
		collect()
		# informa o Game para spawnar outro
		var game = get_tree().get_root().get_node_or_null("root/Main") # alternativa - veja abaixo nota
		# Para simplicidade, chamamos o parent que é Main: assumimos a hierarquia Main -> Mushrooms -> this
		var main = get_tree().get_current_scene()
		# Melhor: procura um nó chamado "Main" na cena
		var root = get_tree().get_root()
		# Simples e robusto: procurar por um nó chamado "Game" ou "Main" na cena
		# Em vez de tentar ser complexo, chamamos o parent do parent:
		var main_node = get_parent().get_parent()
		if main_node and main_node.has_method("on_mushroom_collected"):
			main_node.on_mushroom_collected()
