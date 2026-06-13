extends Node2D
## City mapa. Tile kolizije moraju biti u grupi "walls" da player skida plen.
## Podesi spawn/arena u Inspectoru dok mapa ne dobije prave markere.

@export_group("Heist")
@export var starting_loot: float = 100_000.0

@export_group("Heat")
## Max broj vozila u poteri za heat 1/2/3. Preko tier 3 -> heat 4.
@export var heat_tier_1_max_cars: int = 3
@export var heat_tier_2_max_cars: int = 6
@export var heat_tier_3_max_cars: int = 9

@export var arena_rect: Rect2 = Rect2(0, 0, 2048, 2048)
@export var player_spawn: Vector2 = Vector2(150, 450)
@export var police_spawn: Vector2 = Vector2(150, 200)
@export var garage_spawn: Vector2 = Vector2(1200, 450)

func _ready() -> void:
	for child in get_children():
		if child is TileMapLayer and child.collision_enabled:
			child.add_to_group(Constants.GROUP_WALLS)

func get_starting_loot() -> float:
	return starting_loot

func get_heat_tier_maxes() -> Vector3i:
	return Vector3i(heat_tier_1_max_cars, heat_tier_2_max_cars, heat_tier_3_max_cars)

func get_arena_rect() -> Rect2:
	return arena_rect

func get_player_spawn() -> Vector2:
	return player_spawn

func get_police_spawn() -> Vector2:
	return police_spawn

func get_garage_spawn() -> Vector2:
	return garage_spawn
