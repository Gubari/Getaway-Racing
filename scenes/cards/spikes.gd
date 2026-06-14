extends Area2D
## EKSERI: hrpa eksera iza auta — usporava policiju dok vozi preko.
## Vlasnik: B.

@export var slow_factor: float = 0.55
@export var slow_duration: float = 2.5
@export var lifetime: float = 8.0

func _ready() -> void:
	collision_layer = Constants.LAYER_CARD_FX
	collision_mask = Constants.LAYER_POLICE
	body_entered.connect(_on_body_entered)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
	if body.has_method("apply_slowdown"):
		body.apply_slowdown(slow_factor, slow_duration)
