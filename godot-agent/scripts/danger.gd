# scenes/DangerArea.gd
extends Area2D

@export var base_radius: float = 80.0
var radius: float = 80.0
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	monitoring = true
	monitorable = true
	# ajusta o CollisionShape2D CircleShape2D radius
	_apply_radius()

func set_radius_scale(scale: float) -> void:
	radius = base_radius * scale
	_apply_radius()

func _apply_radius() -> void:
	var shape = collision_shape.shape
	if typeof(shape) == TYPE_OBJECT and shape is CircleShape2D:
		shape.radius = radius
	# ajusta visual se houver sprite
	if $Sprite2D:
		$Sprite2D.scale = Vector2(radius / base_radius, radius / base_radius)
