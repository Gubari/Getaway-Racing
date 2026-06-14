extends Control
## UI: ability dugmad (custom-crtana kruzna, dno-centar). Vlasnik: B.
## Cita stanje iz "ability_manager" (CardManager). Crtanje/tap je u AbilityButton.

var _manager: Node

@onready var _row: HBoxContainer = $Row

func _ready() -> void:
	_manager = get_tree().get_first_node_in_group("ability_manager")
	if _manager == null:
		push_warning("AbilityBar: nema ability_manager u sceni")
		return
	_row.add_theme_constant_override("separation", 18)
	for i in _manager.abilities.size():
		var b := AbilityButton.new()
		b.setup(_manager, i)
		_row.add_child(b)
