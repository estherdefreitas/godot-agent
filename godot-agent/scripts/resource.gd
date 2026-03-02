extends Area2D

signal collected(amount)

@export var energy_amount: int = 20
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()

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

	add_to_group("mushrooms")

func get_energy_amount():
	return energy_amount

func collect():
	print("COLETOU")
	emit_signal("collected", energy_amount)
	queue_free()
