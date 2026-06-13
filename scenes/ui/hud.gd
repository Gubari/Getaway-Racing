extends CanvasLayer
## HUD: plen %, ruka karata, touch layout (TouchControls sub-scena).
## Vlasnik: D.

@onready var _loot_label: Label = $Control/LootLabel
@onready var _heat_label: Label = $Control/HeatLabel
@onready var _win_panel: PanelContainer = $Control/WinPanel
@onready var _win_label: Label = $Control/WinPanel/MarginContainer/WinLabel
@onready var _game_over_panel: PanelContainer = $Control/GameOverPanel
@onready var _game_over_label: Label = $Control/GameOverPanel/MarginContainer/GameOverLabel

func _ready() -> void:
	GameState.loot_changed.connect(_on_loot_changed)
	GameState.heat_changed.connect(_on_heat_changed)
	GameState.game_won.connect(_on_game_won)
	GameState.game_over.connect(_on_game_over)
	_on_loot_changed(GameState.loot_percent)
	_on_heat_changed(GameState.heat)
	_win_panel.visible = false
	_game_over_panel.visible = false

func _on_loot_changed(value: float) -> void:
	_loot_label.text = "Plen: %d%%" % roundi(value)

func _on_heat_changed(value: float) -> void:
	_heat_label.text = "Heat: %d" % roundi(value)

func _on_game_won() -> void:
	_win_label.text = "Pobeda!\nPlen: %d%%" % roundi(GameState.loot_percent)
	_win_panel.visible = true

func _on_game_over() -> void:
	_game_over_label.text = "Uhvacen!\nPlen: %d%%" % roundi(GameState.loot_percent)
	_game_over_panel.visible = true
