extends Area2D
## CILJ LEVELA: igrac ulazi u garažu -> pobeda (samo kad je policija u RETURNING).
## Vlasnik: A. Instanciraj u main.tscn (pored Player/Police) i pomeri po levelu.

const BLOCKED_MESSAGE := "MORAS DA POBEGNES OD POLICIJE"

@export var zone_size: Vector2 = Vector2(100, 100)
@export var blocked_message_cooldown: float = 1.5

@onready var _shape: CollisionShape2D = $CollisionShape2D

var _blocked_message_left: float = 0.0

func _ready() -> void:
	add_to_group(Constants.GROUP_GARAGE)
	if _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = zone_size
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _process(delta: float) -> void:
	if _blocked_message_left > 0.0:
		_blocked_message_left = maxf(0.0, _blocked_message_left - delta)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(Constants.GROUP_PLAYER):
		return
	if not GameState.is_running:
		return

	if not _any_police_pursuing():
		GameState.reach_base()   # pobeda SAMO kad nijedan policajac ne juri (svi odustali)
		return

	if _blocked_message_left <= 0.0:
		GameState.garage_blocked.emit(BLOCKED_MESSAGE)
		_blocked_message_left = blocked_message_cooldown

## Da li bar JEDAN policajac aktivno juri (CHASE ili SEARCHING)?
func _any_police_pursuing() -> bool:
	for cop in get_tree().get_nodes_in_group(Constants.GROUP_POLICE):
		if cop.has_method("is_actively_pursuing") and cop.is_actively_pursuing():
			return true
	return false

func _draw() -> void:
	var half := zone_size * 0.5
	draw_rect(Rect2(-half, zone_size), Color(0.2, 0.75, 0.35, 0.35))
