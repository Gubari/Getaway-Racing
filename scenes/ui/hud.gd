extends CanvasLayer
## HUD: plen %, ruka karata, touch layout (TouchControls sub-scena).
## Vlasnik: D.

@onready var _loot_label: Label = $Control/LootLabel
@onready var _heat_label: Label = $Control/HeatLabel
@onready var _touch_controls: Control = $Control/TouchControls
@onready var _ability_bar: Control = $Control/AbilityBar
@onready var _base_arrow: Control = $Control/BaseArrow

var _heat_display_level: int = 0
var _heat_blink_active: bool = false
var _heat_blink_timer: float = 0.0

const _HEAT_BLINK_INTERVAL := 0.35

func _ready() -> void:
	GameState.loot_changed.connect(_on_loot_changed)
	GameState.heat_changed.connect(_on_heat_changed)
	GameState.heat_blink_changed.connect(_on_heat_blink_changed)
	GameState.game_won.connect(_block_gameplay_ui_input)
	GameState.game_over.connect(_block_gameplay_ui_input)
	_on_loot_changed(GameState.loot_amount)
	_on_heat_changed(GameState.heat_level)
	_on_heat_blink_changed(GameState.heat_blink_active)

func _process(delta: float) -> void:
	if _heat_blink_active and GameState.is_running:
		_heat_blink_timer += delta
		var blink_on := int(_heat_blink_timer / _HEAT_BLINK_INTERVAL) % 2 == 0
		_heat_label.modulate = Color(1.0, 1.0, 1.0, 1.0 if blink_on else 0.2)
	else:
		_heat_blink_timer = 0.0
		if _heat_label.modulate.a != 1.0:
			_heat_label.modulate = Color.WHITE

func _on_loot_changed(value: float) -> void:
	_loot_label.text = "Plen: %s" % GameState.format_loot(value)

func _on_heat_changed(level: int) -> void:
	_heat_display_level = level
	_heat_label.text = "Heat: %d" % _heat_display_level

func _on_heat_blink_changed(active: bool) -> void:
	_heat_blink_active = active
	if not active:
		_heat_label.modulate = Color.WHITE

func hide_ability_bar() -> void:
	_ability_bar.visible = false

func _block_gameplay_ui_input() -> void:
	_touch_controls.visible = false
	_ability_bar.visible = false
	_base_arrow.visible = false
