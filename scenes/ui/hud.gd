extends CanvasLayer
## HUD: plen %, ruka karata, touch layout (TouchControls sub-scena).
## Vlasnik: D.

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

@onready var _loot_label: Label = $Control/LootLabel
@onready var _heat_label: Label = $Control/HeatLabel
@onready var _win_overlay: VBoxContainer = $Control/WinOverlay
@onready var _win_label: Label = $Control/WinOverlay/WinPanel/MarginContainer/WinLabel
@onready var _back_to_garage_btn: Button = $Control/WinOverlay/BackToGarageBtn
@onready var _game_over_panel: PanelContainer = $Control/GameOverPanel
@onready var _game_over_label: Label = $Control/GameOverPanel/MarginContainer/GameOverLabel
@onready var _blocked_panel: PanelContainer = $Control/BlockedPanel
@onready var _blocked_label: Label = $Control/BlockedPanel/MarginContainer/BlockedLabel
@onready var _touch_controls: Control = $Control/TouchControls
@onready var _ability_bar: Control = $Control/AbilityBar

var _blocked_hide_left: float = 0.0
var _heat_display_level: int = 0
var _heat_blink_active: bool = false
var _heat_blink_timer: float = 0.0
var _reward_banked: bool = false

const _HEAT_BLINK_INTERVAL := 0.35

func _ready() -> void:
	GameState.loot_changed.connect(_on_loot_changed)
	GameState.heat_changed.connect(_on_heat_changed)
	GameState.heat_blink_changed.connect(_on_heat_blink_changed)
	GameState.game_won.connect(_on_game_won)
	GameState.game_over.connect(_on_game_over)
	GameState.garage_blocked.connect(_on_garage_blocked)
	_back_to_garage_btn.pressed.connect(_on_back_to_garage)
	_on_loot_changed(GameState.loot_amount)
	_on_heat_changed(GameState.heat_level)
	_on_heat_blink_changed(GameState.heat_blink_active)
	_win_overlay.visible = false
	_game_over_panel.visible = false
	_blocked_panel.visible = false

func _process(delta: float) -> void:
	if _heat_blink_active and GameState.is_running:
		_heat_blink_timer += delta
		var blink_on := int(_heat_blink_timer / _HEAT_BLINK_INTERVAL) % 2 == 0
		_heat_label.modulate = Color(1.0, 1.0, 1.0, 1.0 if blink_on else 0.2)
	else:
		_heat_blink_timer = 0.0
		if _heat_label.modulate.a != 1.0:
			_heat_label.modulate = Color.WHITE

	if _blocked_hide_left <= 0.0:
		return
	_blocked_hide_left = maxf(0.0, _blocked_hide_left - delta)
	if _blocked_hide_left <= 0.0:
		_blocked_panel.visible = false

func _on_loot_changed(value: float) -> void:
	_loot_label.text = "Plen: %s" % GameState.format_loot(value)

func _on_heat_changed(level: int) -> void:
	_heat_display_level = level
	_heat_label.text = "Heat: %d" % _heat_display_level

func _on_heat_blink_changed(active: bool) -> void:
	_heat_blink_active = active
	if not active:
		_heat_label.modulate = Color.WHITE

func _on_game_won() -> void:
	_reward_banked = false
	_win_label.text = "Pobeda!\nPlen: %s" % GameState.format_loot(GameState.loot_amount)
	_back_to_garage_btn.disabled = false
	_block_gameplay_ui_input()
	_win_overlay.visible = true
	_win_overlay.move_to_front()

func _on_back_to_garage() -> void:
	if _reward_banked:
		return
	_reward_banked = true
	_back_to_garage_btn.disabled = true
	ItemShop.add_earnings(roundi(GameState.loot_amount))
	Audio.play_ui_click()
	Audio.play_main_menu_music()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_game_over() -> void:
	_game_over_label.text = "Uhvacen!\nPlen: %s" % GameState.format_loot(GameState.loot_amount)
	_game_over_panel.visible = true

func _on_garage_blocked(message: String) -> void:
	_blocked_label.text = message
	_blocked_panel.visible = true
	_blocked_hide_left = 2.5

func _block_gameplay_ui_input() -> void:
	_touch_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
