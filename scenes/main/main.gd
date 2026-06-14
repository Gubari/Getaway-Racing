extends Node2D
## Glavna scena - vezuje sve zajedno. Startuje trku.
## Vlasnik: zajednicki (instancira tudje scene, ne dira njihovu logiku).
##
## Spawn pozicije: pomeri markere u city.tscn (Spawns/*Spawn).

@onready var _level: Node2D = $City
@onready var _player: CharacterBody2D = $City/Spawns/PlayerSpawn/Player
@onready var _garage: Area2D = $City/Spawns/GarageSpawn/Garage

func _ready() -> void:
	await _setup_camera()
	_setup_run()

func _setup_run() -> void:
	var starting_loot := 100_000.0
	if _level.has_method("get_starting_loot"):
		starting_loot = _level.get_starting_loot()
	if _level.has_method("get_heat_tier_maxes"):
		var tiers: Vector3i = _level.get_heat_tier_maxes()
		GameState.configure_heat_tiers(tiers.x, tiers.y, tiers.z)
	else:
		GameState.configure_heat_tiers(3, 6, 9)
	GameState.start_run(starting_loot)

func _setup_camera() -> void:
	if not _level.has_method("get_arena_rect") or not _player.has_method("setup_camera_limits"):
		return
	await get_tree().process_frame
	_player.setup_camera_limits(_level.get_arena_rect())
