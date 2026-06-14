extends StaticBody2D
## BARIKADA: fizicka prepreka na walls layeru. Kad padne, nav region isece
## navmesh oko nje (re-bake) pa je policija OBILAZI; ako je vec blizu, zakuca se.
## NIJE u grupi walls (da igrac ne dobije crash penalty na svoju barikadu).
## Vlasnik: B.

@export var lifetime: float = 6.0

func _ready() -> void:
	collision_layer = Constants.LAYER_WALLS   # policija (mask=walls) se sudara
	collision_mask = 0
	_mark_nav_dirty()                          # iseci navmesh oko barikade
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(_expire)

func _expire() -> void:
	queue_free()
	_mark_nav_dirty()                          # vrati navmesh kad nestane

## Pozove je policija kad je probije pri velikoj brzini (puca).
func smash() -> void:
	queue_free()
	_mark_nav_dirty()

func _mark_nav_dirty() -> void:
	get_tree().call_group("nav_region", "rebake")
