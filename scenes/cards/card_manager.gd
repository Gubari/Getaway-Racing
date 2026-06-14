extends Node
## ABILITY BAR LOGIKA: 3 fiksne moci. Svaka radi na cooldown ILI na ogranicen broj
## upotreba (charges) - ili oboje. Vlasnik: B.
## UI (ability_bar) cita stanje odavde i poziva activate(index).
## Cvor se zove "CardManager" zbog instancе u main.tscn - ne preimenovati.

@export var abilities: Array[Card] = []   # 3 .tres moci (redosled = redosled dugmadi)

var _cooldown_left: Array[float] = []
var _charges_left: Array[int] = []

func _ready() -> void:
	add_to_group("ability_manager")
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
	# 1) javi vozilu (A) preko signala - npr. nitro burst
	GameState.card_played.emit(ab.type)
	# 2) spawn prepreke iza auta (ulje / barikada)
	if ab.effect_scene:
		_spawn_effect(ab)
	# 3) potrosi resurs
	if ab.max_charges >= 0:
		_charges_left[index] -= 1
	if ab.cooldown > 0.0:
		_cooldown_left[index] = ab.cooldown
	return true

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
