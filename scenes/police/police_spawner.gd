extends Node2D
## Policijska stanica: spawn point + eskalacija policajaca. Pravi DODATNE policajce
## na SVOJOJ poziciji do cap-a (iz heat config-a nivoa). Usput broji policajce u
## poteri i hrani GameState heat (HUD). Staticki Police u main.tscn je #1.
## Vlasnik: B. Kad drug napravi stanicu -> samo pomeri ovaj cvor na nju.

@export var police_scene: PackedScene
@export var first_spawn_delay: float = 8.0  # kada dolazi prvo pojacanje
@export var spawn_interval: float = 12.0    # sek izmedju pojacanja
@export var spawn_spread: float = 60.0      # nasumican razmak oko stanice (da se ne preklapaju)
@export var fallback_max: int = 5           # cap ako nivo ne da heat config

# Podesavanja koja se kopiraju sa statickog policajca na spawnovane (da budu isti).
const COPY_PROPS: Array[String] = [
	"chase_speed", "search_speed", "return_speed",
	"lose_sight_grace", "vision_range", "wall_crash_enabled",
	"lane_spacing", "row_spacing", "formation_range",
]

var _cap: int = 5
var _timer: float = 0.0
var _template: Dictionary = {}

func _ready() -> void:
	_timer = first_spawn_delay
	var level := _find_level()
	if level != null:
		var maxes: Vector3i = level.get_heat_tier_maxes()
		GameState.configure_heat_tiers(maxes.x, maxes.y, maxes.z)
		_cap = maxes.z   # tier 3 max = max broj vozila u poteri
	else:
		_cap = fallback_max
	# zapamti stelovanje statickog #1 da spawnovani budu isti
	var ref := get_tree().get_first_node_in_group(Constants.GROUP_POLICE)
	if ref != null:
		for p in COPY_PROPS:
			_template[p] = ref.get(p)

func _physics_process(delta: float) -> void:
	if not GameState.is_running:
		return
	_report_heat()
	if _police_count() >= _cap:
		return
	_timer -= delta
	if _timer <= 0.0:
		_spawn_one()
		_timer = spawn_interval

## Broji policajce u poteri (CHASE/SEARCHING) i pretrazi (SEARCHING) -> heat HUD.
func _report_heat() -> void:
	var pursuit := 0
	var searching := 0
	for cop in get_tree().get_nodes_in_group(Constants.GROUP_POLICE):
		if cop.has_method("is_actively_pursuing") and cop.is_actively_pursuing():
			pursuit += 1
		if cop.has_method("is_searching") and cop.is_searching():
			searching += 1
	GameState.update_heat_from_police(pursuit, searching)

func _police_count() -> int:
	return get_tree().get_nodes_in_group(Constants.GROUP_POLICE).size()

func _spawn_one() -> void:
	if police_scene == null:
		return
	var cop := police_scene.instantiate()
	for p in _template:
		cop.set(p, _template[p])   # isto stelovanje kao staticki #1
	cop.global_position = _spawn_pos()
	get_tree().current_scene.add_child(cop)

## Pozicija stanice + mali nasumican razmak, snap-ovan na navmesh (na put).
func _spawn_pos() -> Vector2:
	var offset := Vector2(randf_range(-spawn_spread, spawn_spread), randf_range(-spawn_spread, spawn_spread))
	var p := global_position + offset
	return NavigationServer2D.map_get_closest_point(get_world_2d().navigation_map, p)

func _find_level() -> Node:
	for child in get_tree().current_scene.get_children():
		if child.has_method("get_heat_tier_maxes"):
			return child
	return null
