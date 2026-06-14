extends Node2D
## Na sudar IGRACA (GameState.crash_detected) izbaci nekoliko novcica iz auta.
## Cisto vizuelni juice (plen "ispada"). Vlasnik: B.

@export var coin_scene: PackedScene
@export var coins_per_hit: int = 6

func _ready() -> void:
	GameState.crash_detected.connect(_on_crash)

func _on_crash(_penalty: float) -> void:
	var player := get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
	if player == null or coin_scene == null:
		return
	for i in coins_per_hit:
		var coin := coin_scene.instantiate()
		get_tree().current_scene.add_child(coin)
		coin.global_position = player.global_position
		coin.launch()
