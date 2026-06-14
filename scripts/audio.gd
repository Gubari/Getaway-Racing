extends Node
## Globalni audio sistem: UI klik, heist muzika, gameplay SFX.
## Autoload "Audio" (vidi project.godot). Vlasnik: D.

const UI_CLICK := preload("res://assets/audio/sfx/ui_click.wav")
const ENGINE := preload("res://assets/audio/sfx/player_engine.wav")
const MUSIC_CHASING := preload("res://assets/audio/music/music_chasing.ogg")
const MUSIC_SEARCHING := preload("res://assets/audio/music/music_searching.ogg")
const MUSIC_RETURNING := preload("res://assets/audio/music/music_returning.ogg")

const SFX_COLLISION := preload("res://assets/audio/sfx/collision_car.wav")
const SFX_MONEY := preload("res://assets/audio/sfx/money.wav")
const SFX_TIRE_SCREECH := preload("res://assets/audio/sfx/tire_screech.wav")
const SFX_NITRO := preload("res://assets/audio/sfx/nitro.wav")
const SFX_WILD_CARD := preload("res://assets/audio/sfx/wild_card.wav")

const WILD_CARD_TYPES: Array[int] = [
	Card.Type.SPIKES,
	Card.Type.FAKE_MONEY,
	Card.Type.JOKER,
]

var _ui: AudioStreamPlayer
var _music: AudioStreamPlayer
var _engine: AudioStreamPlayer
var _music_mode := -1
var _last_loot: float = -1.0
var _skip_loot_sfx_once := false
var _engine_active := false
var _engine_pitch := 0.72

var _sfx_collision: AudioStreamPlayer
var _sfx_money: AudioStreamPlayer
var _sfx_nitro: AudioStreamPlayer
var _sfx_wild_card: AudioStreamPlayer
var _pause_saved_music_mute := false
var _pause_saved_sfx_mute := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_ui = _new_player(UI_CLICK, _bus(&"SFX"), Node.PROCESS_MODE_ALWAYS)
	add_child(_ui)

	_music = _new_player(null, _bus(&"Music"))
	_music.volume_db = -8.0
	_music.finished.connect(_on_music_finished)
	add_child(_music)

	var engine_stream := _prepare_engine_stream()
	_engine = _new_player(engine_stream, sfx_bus())
	_engine.volume_db = -10.0
	add_child(_engine)

	_sfx_collision = _new_player(SFX_COLLISION, _bus(&"SFX"))
	_sfx_money = _new_player(SFX_MONEY, _bus(&"SFX"))
	_sfx_nitro = _new_player(SFX_NITRO, _bus(&"SFX"))
	_sfx_wild_card = _new_player(SFX_WILD_CARD, _bus(&"SFX"))
	add_child(_sfx_collision)
	add_child(_sfx_money)
	add_child(_sfx_nitro)
	add_child(_sfx_wild_card)

	get_tree().node_added.connect(_on_node_added)
	_connect_existing(get_tree().root)

	GameState.pursuit_music_changed.connect(_on_pursuit_music_changed)
	GameState.game_won.connect(stop_heist_audio)
	GameState.game_over.connect(stop_heist_audio)
	GameState.crash_detected.connect(_on_crash_detected)
	GameState.loot_changed.connect(_on_loot_changed)
	GameState.nitro_used.connect(func(): _sfx_nitro.play())
	GameState.card_played.connect(_on_card_played)

	call_deferred("_sync_heist_audio")

func _sync_heist_audio() -> void:
	if not GameState.is_running:
		return
	_on_pursuit_music_changed(GameState.pursuit_music)

func _bus(name: StringName) -> StringName:
	return name if AudioServer.get_bus_index(name) >= 0 else &"Master"

func sfx_bus() -> StringName:
	return _bus(&"SFX")

func prepare_wav_loop(source: AudioStreamWAV) -> AudioStreamWAV:
	var stream := source.duplicate() as AudioStreamWAV
	var bytes_per_sample := 1 if stream.format == AudioStreamWAV.FORMAT_8_BITS else 2
	var channels := 2 if stream.stereo else 1
	var sample_count := stream.data.size() / (bytes_per_sample * channels)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = maxi(sample_count - 1, 0)
	return stream

func _prepare_engine_stream() -> AudioStreamWAV:
	return prepare_wav_loop(ENGINE)

func _new_player(
	stream: AudioStream,
	bus: StringName,
	mode: int = Node.PROCESS_MODE_PAUSABLE,
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.process_mode = mode
	return player

func set_player_engine_active(active: bool) -> void:
	_engine_active = active
	if _engine == null or _engine.stream == null:
		return
	if active and not get_tree().paused and GameState.is_running:
		if not _engine.playing:
			_engine.play()
	else:
		_engine.stop()

func update_player_engine(
	speed_ratio: float,
	gas: float,
	brake: float,
	forward_speed: float,
	delta: float,
	pitch_idle: float,
	pitch_max: float,
	volume_db: float,
	smoothing: float,
) -> void:
	if not _engine_active or _engine == null:
		return

	var load := clampf(speed_ratio * 0.62 + gas * 0.38, 0.0, 1.0)
	if brake > 0.05 and forward_speed > 20.0:
		load *= lerpf(1.0, 0.82, brake)

	var target_pitch := lerpf(pitch_idle, pitch_max, load)
	_engine_pitch = lerpf(_engine_pitch, target_pitch, smoothing * delta)
	_engine.pitch_scale = _engine_pitch

	var target_vol := volume_db + (load - 0.2) * 3.5
	_engine.volume_db = lerpf(_engine.volume_db, target_vol, smoothing * delta)

func _music_for_mode(mode: int) -> AudioStream:
	match mode:
		GameState.PursuitMusic.CHASING:
			return MUSIC_CHASING
		GameState.PursuitMusic.SEARCHING:
			return MUSIC_SEARCHING
		_:
			return MUSIC_RETURNING

func _connect_existing(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children():
		_connect_existing(child)

func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(play_ui_click):
		node.pressed.connect(play_ui_click)

func play_ui_click() -> void:
	_ui.play()

func _on_crash_detected(_penalty: float) -> void:
	_sfx_collision.play()
	_sfx_money.play()
	_skip_loot_sfx_once = true

func _on_loot_changed(value: float) -> void:
	if _skip_loot_sfx_once:
		_skip_loot_sfx_once = false
		_last_loot = value
		return
	if _last_loot >= 0.0 and value < _last_loot - 0.01 and GameState.is_running:
		_sfx_money.play()
	_last_loot = value

func _on_card_played(card_type: int) -> void:
	if card_type in WILD_CARD_TYPES:
		_sfx_wild_card.play()

func play_tire_screech(global_pos: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = SFX_TIRE_SCREECH
	player.bus = _bus(&"SFX")
	player.max_distance = 2800.0
	get_tree().root.add_child(player)
	player.global_position = global_pos
	player.finished.connect(player.queue_free)
	player.play()

func _on_pursuit_music_changed(mode: int) -> void:
	if not GameState.is_running:
		stop_heist_audio()
		return
	_play_heist_music(mode)

func _play_heist_music(mode: int) -> void:
	if _music_mode == mode and _music.playing:
		return

	var stream := _music_for_mode(mode)
	if _music.stream != stream:
		_music.stop()
		_music.stream = stream

	_music_mode = mode
	if not _music.playing:
		_music.play()

func _on_music_finished() -> void:
	if GameState.is_running and _music_mode >= 0:
		_music.play()

func stop_heist_music() -> void:
	stop_heist_audio()

func stop_heist_audio() -> void:
	set_player_engine_active(false)
	_music.stop()
	_music_mode = -1

func pause_gameplay_audio() -> void:
	set_player_engine_active(false)
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus_idx := AudioServer.get_bus_index("SFX")
	if music_bus >= 0:
		_pause_saved_music_mute = AudioServer.is_bus_mute(music_bus)
		AudioServer.set_bus_mute(music_bus, true)
	if sfx_bus_idx >= 0:
		_pause_saved_sfx_mute = AudioServer.is_bus_mute(sfx_bus_idx)
		AudioServer.set_bus_mute(sfx_bus_idx, true)

func resume_gameplay_audio() -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus_idx := AudioServer.get_bus_index("SFX")
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, _pause_saved_music_mute)
	if sfx_bus_idx >= 0:
		AudioServer.set_bus_mute(sfx_bus_idx, _pause_saved_sfx_mute)
	if GameState.is_running and _music_mode >= 0 and not _music.playing:
		_music.play()

func resume_heist_audio() -> void:
	resume_gameplay_audio()
