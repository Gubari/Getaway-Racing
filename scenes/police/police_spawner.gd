@tool
extends Node2D
## Policijska stanica: spawn point + eskalacija policajaca do cap-a (heat config nivoa).
## Usput broji policajce u poteri i hrani GameState heat (HUD).
## Vlasnik: B. Pomeri Spawns/PoliceSpawnerSpawn (Marker2D) u city.tscn.

@export var police_scene: PackedScene
@export var first_spawn_delay: float = 1.0   # prvi patrol (nema vise statickog #1)
@export var spawn_interval: float = 12.0     # sek izmedju pojacanja
@export var spawn_spread: float = 60.0       # nasumican razmak oko stanice (da se ne preklapaju)
@export var fallback_max: int = 5            # cap ako nivo ne da heat config
@export var snap_spawn_to_nav: bool = true   # blago pomeri na put samo ako je blizu markera
@export var nav_snap_max_distance: float = 96.0

@export_group("Spawned police tuning")
@export var spawn_rotation: float = -1.5730485
@export var chase_speed: float = 300.0
@export var search_speed: float = 250.0
@export var return_speed: float = 150.0
@export var lose_sight_grace: float = 4.0
@export var wall_crash_enabled: bool = false

# Ostala polja kopiraju se iz police_scene pri startu (formacija, sirena, vision...).
const COPY_PROPS: Array[String] = [
	"vision_range",
	"lane_spacing", "row_spacing", "formation_range",
	"siren_volume_db", "siren_max_distance", "siren_attenuation",
]

var _cap: int = 5
var _timer: float = 0.0
var _template: Dictionary = {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_timer = first_spawn_delay
	var level := _find_level()
	if level != null:
		var maxes: Vector3i = level.get_heat_tier_maxes()
		GameState.configure_heat_tiers(maxes.x, maxes.y, maxes.z)
		_cap = maxes.z
	else:
		_cap = fallback_max
	_build_template()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not GameState.is_running:
		return
	_report_heat()
	if _police_count() >= _cap:
		return
	_timer -= delta
	if _timer <= 0.0:
		_spawn_one()
		_timer = spawn_interval

func _build_template() -> void:
	_template.clear()
	if police_scene == null:
		return
	var preview := police_scene.instantiate()
	for p in COPY_PROPS:
		_template[p] = preview.get(p)
	preview.free()
	_template["chase_speed"] = chase_speed
	_template["search_speed"] = search_speed
	_template["return_speed"] = return_speed
	_template["lose_sight_grace"] = lose_sight_grace
	_template["wall_crash_enabled"] = wall_crash_enabled

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
		cop.set(p, _template[p])
	var pos := _spawn_pos()
	get_tree().current_scene.add_child(cop)
	cop.global_position = pos
	cop.rotation = spawn_rotation
	cop.home_position = pos

## Pozicija markera (PoliceSpawnerSpawn) + mali nasumican razmak.
func _spawn_pos() -> Vector2:
	var offset := Vector2(randf_range(-spawn_spread, spawn_spread), randf_range(-spawn_spread, spawn_spread))
	var desired := _spawn_anchor() + offset
	if not snap_spawn_to_nav:
		return desired
	var nav_map := get_world_2d().navigation_map
	if nav_map == RID():
		return desired
	var snapped := NavigationServer2D.map_get_closest_point(nav_map, desired)
	if snapped.distance_to(desired) <= nav_snap_max_distance:
		return snapped
	return desired

func _spawn_anchor() -> Vector2:
	var parent := get_parent()
	if parent is Marker2D:
		return parent.global_position
	return global_position

func _find_level() -> Node:
	for child in get_tree().current_scene.get_children():
		if child.has_method("get_heat_tier_maxes"):
			return child
	return null

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, spawn_spread, Color(1.0, 0.35, 0.2, 0.22))
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 24, Color(1.0, 0.35, 0.2, 0.85), 2.0)
