extends Node2D
## City mapa. Tile kolizije moraju biti u grupi "walls" da player skida plen.
## Pljacke: HeistProfiles/* (podesi markere + loot/heat). GameState.selected_heist_id bira profil.

## Layeri sa fizickom kolizijom + grupa "walls" (player skida plen na sudar).
const WALL_LAYER_NAMES: Array[StringName] = [&"Outline", &"Sidewalk", &"Buildings"]
## Dekorativni delovi zgrada koji visi preko puta — bez kolizije, ali ispred auta.
const CANOPY_LAYER_NAMES: Array[StringName] = [&"BuildingNonColide"]

const DEFAULT_HEIST_ID := &"downtown"

@export_group("Camera / Map Bounds")
@export var camera_bounds_from_outline: bool = true
@export var camera_bounds_padding: Vector2 = Vector2.ZERO
@export var arena_rect: Rect2 = Rect2(0, 0, 4480, 1536)

var _active_profile: HeistProfile

@onready var _player_spawn: Marker2D = $Spawns/PlayerSpawn
@onready var _police_spawn: Marker2D = $Spawns/PoliceSpawnerSpawn
@onready var _garage_spawn: Marker2D = $Spawns/GarageSpawn
@onready var _police_spawner: Node2D = $Spawns/PoliceSpawnerSpawn/PoliceSpawner
@onready var _heist_profiles: Node2D = $HeistProfiles

func _ready() -> void:
	_setup_wall_layers()
	_setup_canopy_depth()
	_apply_selected_heist()

func _apply_selected_heist() -> void:
	var heist_id := StringName(GameState.selected_heist_id)
	if heist_id.is_empty():
		heist_id = DEFAULT_HEIST_ID
	_active_profile = _find_profile(heist_id)
	if _active_profile == null:
		push_warning("City: unknown heist '%s', using first profile." % heist_id)
		for child in _heist_profiles.get_children():
			if child is HeistProfile:
				_active_profile = child as HeistProfile
				break
	if _active_profile == null:
		return
	_player_spawn.position = _active_profile.get_player_spawn_position()
	_police_spawn.position = _active_profile.get_police_spawner_position()
	_garage_spawn.position = _active_profile.get_garage_spawn_position()
	_police_spawner.first_spawn_delay = _active_profile.first_spawn_delay
	_police_spawner.spawn_interval = _active_profile.spawn_interval

func _find_profile(heist_id: StringName) -> HeistProfile:
	for child in _heist_profiles.get_children():
		if child is HeistProfile and StringName(child.heist_id) == heist_id:
			return child as HeistProfile
	return null

func get_active_heist_id() -> String:
	return _active_profile.heist_id if _active_profile != null else String(DEFAULT_HEIST_ID)

func get_starting_loot() -> float:
	if _active_profile != null:
		return _active_profile.starting_loot
	return 100_000.0

func get_heat_tier_maxes() -> Vector3i:
	if _active_profile != null:
		return _active_profile.get_heat_tier_maxes()
	return Vector3i(2, 3, 5)

func get_max_police() -> int:
	if _active_profile != null:
		return _active_profile.max_police
	return 5

func _setup_wall_layers() -> void:
	for child in get_children():
		if child is TileMapLayer:
			if child.name not in WALL_LAYER_NAMES:
				child.collision_enabled = false
				continue
			child.collision_enabled = true
			child.add_to_group(Constants.GROUP_WALLS)

func _setup_canopy_depth() -> void:
	for child in get_children():
		if child is TileMapLayer:
			if child.name not in CANOPY_LAYER_NAMES:
				continue
			child.z_as_relative = false
			child.z_index = Constants.DEPTH_CANOPY_Z_INDEX
			child.y_sort_enabled = true

const CAMERA_BOUNDS_LAYERS: Array[StringName] = [
	&"Road", &"Sidewalk", &"Buildings",
]

func get_arena_rect() -> Rect2:
	var bounds := arena_rect
	if camera_bounds_from_outline:
		var from_map := _map_camera_bounds()
		if from_map.size != Vector2.ZERO:
			bounds = from_map
	return _apply_camera_padding(bounds)

func _map_camera_bounds() -> Rect2:
	var merged := Rect2()
	var has_any := false
	for layer_name in CAMERA_BOUNDS_LAYERS:
		var layer := get_node_or_null(String(layer_name)) as TileMapLayer
		if layer == null:
			continue
		var layer_bounds := _tile_layer_world_bounds(layer)
		if layer_bounds.size == Vector2.ZERO:
			continue
		if not has_any:
			merged = layer_bounds
			has_any = true
		else:
			merged = merged.merge(layer_bounds)
	return merged if has_any else Rect2()

func _tile_layer_world_bounds(layer: TileMapLayer) -> Rect2:
	var used := layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return Rect2()
	var tile_size := Vector2(layer.tile_set.tile_size)
	var half := tile_size * 0.5
	var first_center := layer.map_to_local(used.position)
	var last_center := layer.map_to_local(used.position + used.size - Vector2i.ONE)
	var top_left := layer.to_global(first_center - half)
	var bottom_right := layer.to_global(last_center + half)
	return Rect2(top_left, bottom_right - top_left)

func _apply_camera_padding(rect: Rect2) -> Rect2:
	return Rect2(rect.position + camera_bounds_padding, rect.size - camera_bounds_padding * 2.0)
