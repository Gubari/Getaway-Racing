extends Node2D
## Glavna scena - vezuje sve zajedno. Startuje trku.
## Vlasnik: zajednicki (instancira tudje scene, ne dira njihovu logiku).

@onready var _test_track: Node2D = $TestTrack
@onready var _player: CharacterBody2D = $Player
@onready var _police: CharacterBody2D = $Police

func _ready() -> void:
	_setup_spawns()
	_setup_camera()
	GameState.start_run()

func _setup_spawns() -> void:
	if _test_track.has_method("get_player_spawn"):
		_player.global_position = _test_track.get_player_spawn()
	if _test_track.has_method("get_police_spawn"):
		_police.global_position = _test_track.get_police_spawn()

func _setup_camera() -> void:
	if _test_track.has_method("get_arena_rect") and _player.has_method("setup_camera_limits"):
		_player.setup_camera_limits(_test_track.get_arena_rect())
