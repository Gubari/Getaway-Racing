extends Node
## ABILITY BAR LOGIKA: moci iz Item Shop loadout-a. Svaka radi na cooldown ILI na
## ogranicen broj upotreba (charges) - ili oboje. Vlasnik: B.
## UI (ability_bar) cita stanje odavde i poziva activate(index).
## Cvor se zove "CardManager" zbog instance u main.tscn - ne preimenovati.

@export var abilities: Array[Card] = []   # fallback; runtime koristi ItemShop loadout

var _cooldown_left: Array[float] = []
var _charges_left: Array[int] = []

func _ready() -> void:
	add_to_group("ability_manager")
	if ItemShop:
		abilities = ItemShop.get_loadout()
	_init_runtime_state()

func _init_runtime_state() -> void:
	_cooldown_left.resize(abilities.size())
	_charges_left.resize(abilities.size())
	for i in abilities.size():
		_cooldown_left[i] = 0.0
		_charges_left[i] = abilities[i].max_charges   # -1 ostaje -1 (neograniceno)

func _process(delta: float) -> void:
	for i in _cooldown_left.size():
		if _cooldown_left[i] > 0.0:
			_cooldown_left[i] = maxf(0.0, _cooldown_left[i] - delta)

# --- JAVNI API (koristi ability_bar UI) ---
func is_ready(index: int) -> bool:
	if index < 0 or index >= abilities.size():
		return false
	if not GameState.is_running:
		return false
	if _cooldown_left[index] > 0.0:
		return false
	var mc := abilities[index].max_charges
	if mc >= 0 and _charges_left[index] <= 0:
		return false
	return true

func activate(index: int) -> bool:
	if not is_ready(index):
		return false
	var ab := abilities[index]
	if ab.type == Card.Type.JOKER:
		return _activate_wild_card(index, ab)
	return _activate_card(ab, index)

func get_ability(index: int) -> Card:
	return abilities[index] if index >= 0 and index < abilities.size() else null

func get_charges(index: int) -> int:
	return _charges_left[index] if index >= 0 and index < _charges_left.size() else 0

func get_cooldown_ratio(index: int) -> float:
	# 1.0 = spremno, 0.0 = tek aktivirano
	var cd := abilities[index].cooldown
	if cd <= 0.0:
		return 1.0
	return 1.0 - _cooldown_left[index] / cd

func _activate_wild_card(index: int, ab: Card) -> bool:
	var pool := ItemShop.get_wild_pool() if ItemShop else []
	if pool.is_empty():
		return false
	_consume_slot(index, ab)
	GameState.card_played.emit(Card.Type.JOKER)
	var picked: int = pool[randi() % pool.size()]
	_execute_card_type(picked)
	return true

func _activate_card(ab: Card, index: int) -> bool:
	_execute_card_type(ab.type)
	_consume_slot(index, ab)
	return true

func _execute_card_type(card_type: int) -> void:
	GameState.card_played.emit(card_type)
	var card := ItemShop.get_card_by_type(card_type) if ItemShop else null
	if card != null and card.effect_scene:
		_spawn_effect(card)

func _consume_slot(index: int, ab: Card) -> void:
	if ab.max_charges >= 0:
		_charges_left[index] -= 1
	if ab.cooldown > 0.0:
		_cooldown_left[index] = ab.cooldown

func _spawn_effect(ab: Card) -> void:
	var player := get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
	if player == null:
		return
	var fx := ab.effect_scene.instantiate()
	if player.has_method("get_rear_spawn_point"):
		fx.global_position = player.get_rear_spawn_point()   # A-jev helper
	else:
		fx.global_position = player.global_position - Vector2.RIGHT.rotated(player.rotation) * 48.0
	# Okreni POPRECNO na pravac voznje (barikada preprecuje put po sirini).
	fx.rotation = player.rotation + PI / 2.0
	get_tree().current_scene.add_child(fx)
