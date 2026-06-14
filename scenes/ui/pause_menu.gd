extends CanvasLayer
## Pause + Settings meni. Radi i dok je igra pauzirana (process_mode = ALWAYS).
## Pause: Resume / Settings / Abandon the Heist.
## Settings: SFX i Music slajderi (kontrolisu audio buseve) + Return.
## Vlasnik: D.

const _AudioSettings := preload("res://scripts/audio_settings.gd")

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") < 0 or AudioServer.get_bus_index("SFX") < 0:
		push_warning("PauseMenu: Music/SFX audio bus nije pronadjen — proveri project.godot [audio].")

	# UI klik zvuk vise nije ovde - globalni Audio autoload ga svira na svako
	# dugme automatski (vidi scripts/audio.gd).
	_resume_btn.pressed.connect(resume)
	_settings_btn.pressed.connect(_open_settings)
	_abandon_btn.pressed.connect(_abandon)
	_return_btn.pressed.connect(_close_settings)
	_pause_button.pressed.connect(_toggle_pause)
	_AudioSettings.bind_sliders(_sfx_slider, _music_slider)

	GameState.game_won.connect(_force_close)
	GameState.game_over.connect(_force_close)

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
	Audio.pause_gameplay_audio()
	_dim.visible = true
	_pause_panel.visible = true
	_settings_panel.visible = false
	_pause_button.visible = false

func resume() -> void:
	get_tree().paused = false
	Audio.resume_gameplay_audio()
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
	Audio.stop_heist_music()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
