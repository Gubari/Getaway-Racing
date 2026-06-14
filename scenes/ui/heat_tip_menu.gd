extends CanvasLayer
## Base-return tip in menu style. Shown once at heist start.
## Vlasnik: D.

const MESSAGE := "Lose the heat before going back to base."

@onready var _dim: ColorRect = $Dim
@onready var _panel: Control = $Panel
@onready var _message_label: Label = $Panel/Frame/VBox/MessageLabel
@onready var _ok_btn: Button = $Panel/Frame/VBox/OkBtn

var _pause_on_dismiss: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ok_btn.pressed.connect(_dismiss)
	GameState.game_won.connect(_force_hide)
	GameState.game_over.connect(_force_hide)
	_hide()

func show_intro() -> void:
	_message_label.text = MESSAGE
	_pause_on_dismiss = true
	_dim.visible = true
	_panel.visible = true
	get_tree().paused = true

func _dismiss() -> void:
	if _pause_on_dismiss and get_tree().paused:
		get_tree().paused = false
	Audio.play_ui_click()
	_force_hide()

func _force_hide() -> void:
	_pause_on_dismiss = false
	_hide()

func _hide() -> void:
	_dim.visible = false
	_panel.visible = false
