extends CanvasLayer
## HUD: plen %, ruka karata, touch layout (TouchControls sub-scena).
## Vlasnik: D.

@onready var _loot_label: Label = $Control/LootLabel
@onready var _heat_label: Label = $Control/HeatLabel
@onready var _win_panel: PanelContainer = $Control/WinPanel
@onready var _win_label: Label = $Control/WinPanel/MarginContainer/WinLabel
@onready var _game_over_panel: PanelContainer = $Control/GameOverPanel
@onready var _game_over_label: Label = $Control/GameOverPanel/MarginContainer/GameOverLabel
@onready var _blocked_panel: PanelContainer = $Control/BlockedPanel
@onready var _blocked_label: Label = $Control/BlockedPanel/MarginContainer/BlockedLabel

var _blocked_hide_left: float = 0.0

func _ready() -> void:
	GameState.loot_changed.connect(_on_loot_changed)
	GameState.heat_changed.connect(_on_heat_changed)
	GameState.game_won.connect(_on_game_won)
	GameState.game_over.connect(_on_game_over)
	GameState.garage_blocked.connect(_on_garage_blocked)
	_on_loot_changed(GameState.loot_amount)
	_on_heat_changed(GameState.heat)
	_win_panel.visible = false
	_game_over_panel.visible = false
	_blocked_panel.visible = false

func _process(delta: float) -> void:
	if _blocked_hide_left <= 0.0:
		return
	_blocked_hide_left = maxf(0.0, _blocked_hide_left - delta)
	if _blocked_hide_left <= 0.0:
		_blocked_panel.visible = false

func _on_loot_changed(value: float) -> void:
	_loot_label.text = "Plen: %s" % GameState.format_loot(value)

func _on_heat_changed(value: float) -> void:
	_heat_label.text = "Heat: %d" % roundi(value)

func _on_game_won() -> void:
	_win_label.text = "Pobeda!\nPlen: %s" % GameState.format_loot(GameState.loot_amount)
	_win_panel.visible = true

func _on_game_over() -> void:
	_game_over_label.text = "Uhvacen!\nPlen: %s" % GameState.format_loot(GameState.loot_amount)
	_game_over_panel.visible = true

func _on_garage_blocked(message: String) -> void:
	_blocked_label.text = message
	_blocked_panel.visible = true
	_blocked_hide_left = 2.5
