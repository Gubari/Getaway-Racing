extends CanvasLayer
## Pause + Settings meni. Radi i dok je igra pauzirana (process_mode = ALWAYS).
## Pause: Resume / Settings / Abandon the Heist.
## Settings: SFX i Music slajderi (kontrolisu audio buseve) + Return.
## Vlasnik: D.

const SETTINGS_PATH := "user://settings.cfg"
const MIN_DB := -40.0   # ispod ovoga = potpuna tisina (mute)

@onready var _dim: ColorRect = $Dim
@onready var _pause_panel: Control = $PausePanel
@onready var _settings_panel: Control = $SettingsPanel
@onready var _pause_button: Control = $PauseButton

@onready var _resume_btn: Button = $PausePanel/Frame/VBox/ResumeBtn
@onready var _settings_btn: Button = $PausePanel/Frame/VBox/SettingsBtn
@onready var _abandon_btn: Button = $PausePanel/Frame/VBox/AbandonBtn

@onready var _sfx_slider: HSlider = $SettingsPanel/Frame/VBox/SfxRow/SfxSlider
@onready var _music_slider: HSlider = $SettingsPanel/Frame/VBox/MusicRow/MusicSlider
@onready var _return_btn: Button = $SettingsPanel/Frame/VBox/ReturnBtn

var _music_bus := -1
var _sfx_bus := -1
var _click: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_bus = AudioServer.get_bus_index("Music")
	_sfx_bus = AudioServer.get_bus_index("SFX")

	_click = AudioStreamPlayer.new()
	_click.stream = load("res://assets/audio/sfx/ui_click.wav")
	_click.bus = "SFX"
	add_child(_click)

	for b: Button in [_resume_btn, _settings_btn, _abandon_btn, _return_btn]:
		b.pressed.connect(_click.play)

	_resume_btn.pressed.connect(resume)
	_settings_btn.pressed.connect(_open_settings)
	_abandon_btn.pressed.connect(_abandon)
	_return_btn.pressed.connect(_close_settings)
	_pause_button.pressed.connect(_toggle_pause)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	_music_slider.value_changed.connect(_on_music_changed)

	GameState.game_won.connect(_force_close)
	GameState.game_over.connect(_force_close)

	_load_settings()
	_close()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _settings_panel.visible:
			_close_settings()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()

# ------------------------------------------------------------------
# Pause / resume
# ------------------------------------------------------------------
func _toggle_pause() -> void:
	if get_tree().paused:
		resume()
	elif GameState.is_running:
		_pause()

func _pause() -> void:
	get_tree().paused = true
	_dim.visible = true
	_pause_panel.visible = true
	_settings_panel.visible = false
	_pause_button.visible = false

func resume() -> void:
	get_tree().paused = false
	_close()

func _close() -> void:
	_dim.visible = false
	_pause_panel.visible = false
	_settings_panel.visible = false
	# Dugme se prikazuje po defaultu (trka jos mozda nije startovala u trenutku
	# _ready, jer dete dobije _ready pre roditelja koji zove start_run()).
	# Skrivamo ga samo kad je pauzirano ili kad je trka gotova (_force_close).
	_pause_button.visible = true

func _force_close() -> void:
	get_tree().paused = false
	_dim.visible = false
	_pause_panel.visible = false
	_settings_panel.visible = false
	_pause_button.visible = false

func _open_settings() -> void:
	_pause_panel.visible = false
	_settings_panel.visible = true

func _close_settings() -> void:
	_settings_panel.visible = false
	_pause_panel.visible = true

func _abandon() -> void:
	GameState.abandon()
	get_tree().paused = false
	get_tree().reload_current_scene()

# ------------------------------------------------------------------
# Audio: slajder (0..1) -> bus volume (dB). 0 = mute.
# ------------------------------------------------------------------
func _on_sfx_changed(value: float) -> void:
	_apply_volume(_sfx_bus, value)
	_save_settings()

func _on_music_changed(value: float) -> void:
	_apply_volume(_music_bus, value)
	_save_settings()

func _apply_volume(bus: int, value: float) -> void:
	if bus < 0:
		return
	if value <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(value))

# ------------------------------------------------------------------
# Perzistencija (user://settings.cfg)
# ------------------------------------------------------------------
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	var sfx := 0.8
	var music := 0.7
	if cfg.load(SETTINGS_PATH) == OK:
		sfx = cfg.get_value("audio", "sfx", sfx)
		music = cfg.get_value("audio", "music", music)
	_sfx_slider.set_value_no_signal(sfx)
	_music_slider.set_value_no_signal(music)
	_apply_volume(_sfx_bus, sfx)
	_apply_volume(_music_bus, music)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", _sfx_slider.value)
	cfg.set_value("audio", "music", _music_slider.value)
	cfg.save(SETTINGS_PATH)
