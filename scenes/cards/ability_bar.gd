extends Control
## UI: ability dugmad (dno-centar, izmedju strelica i pedala). Vlasnik: B.
## Cita stanje iz "ability_manager" (CardManager) i poziva activate() na tap.
## Finalni placement uskladiti sa D (touch_controls rezervise card_strip dole).

var _manager: Node
var _buttons: Array[Button] = []

@onready var _row: HBoxContainer = $Row

func _ready() -> void:
	_manager = get_tree().get_first_node_in_group("ability_manager")
	if _manager == null:
		push_warning("AbilityBar: nema ability_manager u sceni")
		return
	for i in _manager.abilities.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(104, 80)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(_manager.activate.bind(i))
		_row.add_child(b)
		_buttons.append(b)

func _process(_delta: float) -> void:
	if _manager == null:
		return
	for i in _buttons.size():
		var ab: Card = _manager.get_ability(i)
		if ab == null:
			continue
		var avail: bool = _manager.is_ready(i)
		var txt := ab.display_name
		var charges: int = _manager.get_charges(i)
		if charges >= 0:
			txt += "\n×%d" % charges          # moc na ogranicen broj (ulje/barikada)
		elif not avail:
			txt += "\n%d%%" % int(round(_manager.get_cooldown_ratio(i) * 100.0))  # cooldown (nitro)
		else:
			txt += "\n•"
		_buttons[i].text = txt
		_buttons[i].disabled = not avail
