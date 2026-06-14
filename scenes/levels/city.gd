extends Node2D
## City mapa. Tile kolizije moraju biti u grupi "walls" da player skida plen.
## Spawn: u editoru pomeri Spawns/*Spawn markere (Player/Garage/PoliceSpawner su deca).
## Policija dolazi iskljucivo iz PoliceSpawnerSpawn (PoliceSpawner).

## Layeri sa fizickom kolizijom + grupa "walls" (player skida plen na sudar).
const WALL_LAYER_NAMES: Array[StringName] = [&"Outline", &"Sidewalk", &"Buildings"]
## Dekorativni delovi zgrada koji visi preko puta — bez kolizije, ali ispred auta.
const CANOPY_LAYER_NAMES: Array[StringName] = [&"BuildingNonColide"]

@export_group("Heist")
@export var starting_loot: float = 100_000.0

@export_group("Heat")
## Max broj vozila u poteri za heat 1/2/3. Preko tier 3 -> heat 4.
@export var heat_tier_1_max_cars: int = 3
@export var heat_tier_2_max_cars: int = 6
@export var heat_tier_3_max_cars: int = 9

@export_group("Camera / Map Bounds")
## Granice kamere — kamera ne vidi van ovog pravougaonika.
## Auto: spaja Road/Sidewalk/Buildings (Outline ima off-map tile-ove van igre).
@export var camera_bounds_from_outline: bool = true
@export var camera_bounds_padding: Vector2 = Vector2.ZERO
## Rucno ako auto nije ukljucen ili Outline nije popunjen.
@export var arena_rect: Rect2 = Rect2(0, 0, 4480, 1536)

func _ready() -> void:
	_setup_wall_layers()
	_setup_canopy_depth()

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

func get_starting_loot() -> float:
	return starting_loot

func get_heat_tier_maxes() -> Vector3i:
	return Vector3i(heat_tier_1_max_cars, heat_tier_2_max_cars, heat_tier_3_max_cars)

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
