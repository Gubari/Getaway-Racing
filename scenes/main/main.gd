extends Node2D
## Glavna scena - vezuje sve zajedno. Startuje trku.
## Vlasnik: zajednicki (instancira tudje scene, ne dira njihovu logiku).

@onready var _level: Node2D = $City
@onready var _player: CharacterBody2D = $Player
@onready var _police: CharacterBody2D = $Police
@onready var _garage: Area2D = $Garage

func _ready() -> void:
	_setup_spawns()
	_setup_camera()
	var starting_loot := 100_000.0
	if _level.has_method("get_starting_loot"):
		starting_loot = _level.get_starting_loot()
	GameState.start_run(starting_loot)

func _setup_spawns() -> void:
	if _level.has_method("get_player_spawn"):
		_player.global_position = _level.get_player_spawn()
	if _level.has_method("get_police_spawn"):
		_police.global_position = _level.get_police_spawn()
	if _garage and _level.has_method("get_garage_spawn"):
		_garage.global_position = _level.get_garage_spawn()

func _setup_camera() -> void:
	if _level.has_method("get_arena_rect") and _player.has_method("setup_camera_limits"):
		_player.setup_camera_limits(_level.get_arena_rect())
