extends Node2D
class_name HeistProfile
## Jedna pljacka na city mapi. Podesi markere + loot/heat u editoru (HeistProfiles/*).
## Vlasnik: D.

@export var heist_id: String = ""
@export var display_name: String = ""

@export_group("Loot")
@export var starting_loot: float = 100_000.0

@export_group("Chase")
@export var heat_tier_1_max_cars: int = 2
@export var heat_tier_2_max_cars: int = 3
@export var heat_tier_3_max_cars: int = 5
@export var max_police: int = 5

@export_group("Spawner")
@export var first_spawn_delay: float = 1.0
@export var spawn_interval: float = 12.0

func get_player_spawn_position() -> Vector2:
	return _marker_position(&"PlayerSpawn")

func get_police_spawner_position() -> Vector2:
	return _marker_position(&"PoliceSpawnerSpawn")

func get_garage_spawn_position() -> Vector2:
	return _marker_position(&"GarageSpawn")

func get_heat_tier_maxes() -> Vector3i:
	return Vector3i(heat_tier_1_max_cars, heat_tier_2_max_cars, heat_tier_3_max_cars)

func _marker_position(marker_name: StringName) -> Vector2:
	var marker := get_node_or_null(NodePath(String(marker_name))) as Node2D
	if marker == null:
		push_warning("HeistProfile '%s' missing marker %s" % [heist_id, marker_name])
		return Vector2.ZERO
	return marker.position
