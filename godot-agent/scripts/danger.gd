extends Area2D

@export var base_radius: float = 80.0
var radius: float = 80.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	monitoring = true
	monitorable = true
	add_to_group("dangers")
	_apply_radius()

func set_radius_scale(scale: float) -> void:
	radius = base_radius * scale
	_apply_radius()

func _apply_radius() -> void:
	var shape = collision_shape.shape
	if shape is CircleShape2D:
		shape.radius = radius

	if $Sprite2D:
		$Sprite2D.scale = Vector2(radius / base_radius, radius / base_radius)
