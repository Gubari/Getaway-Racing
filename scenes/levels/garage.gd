extends Area2D
## CILJ LEVELA: igrac ulazi u garažu -> pobeda (samo kad je heat 0).
## Vlasnik: A. Instanciraj u main.tscn (pored Player/Police) i pomeri po levelu.

@export var zone_size: Vector2 = Vector2(100, 100)

@onready var _shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group(Constants.GROUP_GARAGE)
	if _shape.shape is RectangleShape2D:
		(_shape.shape as RectangleShape2D).size = zone_size
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(Constants.GROUP_PLAYER):
		return
	if not GameState.is_running:
		return

	if _has_heat():
		return

	# Pobeda kad je heat 0 (nema aktivne potere). Cinematic zove reach_base.
	var cine := get_tree().get_first_node_in_group("win_cinematic")
	if cine != null and cine.has_method("play_win"):
		cine.play_win()
	else:
		GameState.reach_base()

## Da li igrac jos ima heat (policija u poteri/pretrazi)?
func _has_heat() -> bool:
	return GameState.heat_level > 0

func _draw() -> void:
	var half := zone_size * 0.5
	draw_rect(Rect2(-half, zone_size), Color(0.2, 0.75, 0.35, 0.35))
