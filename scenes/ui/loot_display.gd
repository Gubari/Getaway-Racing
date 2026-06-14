extends Control
## Prikaz plena: $ novcic + iznos, sa juice na GUBITAK (crveni bljesak + trzaj +
## leteci "-Xk" koji odlebdi). Sluša GameState.loot_changed. Vlasnik: B.

const SHEET := preload("res://assets/sprites/ui/Modern_UI_Style_2_32x32.png")
const COIN_REGION := Rect2(294, 776, 48, 48)
const GOLD := Color(1, 0.85, 0.2)
const FLASH := Color(1, 0.3, 0.2)

@export var icon_size: float = 34.0
@export var font_size: int = 26
@export var loss_font_size: int = 30   # velicina letecih "-Xk" brojeva

var _amount: float = 0.0
var _flash: float = 0.0
var _shake: float = 0.0

@onready var _label: Label = $Amount

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", GOLD)
	_label.position = Vector2(icon_size + 8.0, 0.0)
	_amount = GameState.loot_amount
	_label.text = GameState.format_loot(_amount)
	GameState.loot_changed.connect(_on_loot_changed)

func _on_loot_changed(value: float) -> void:
	var delta := value - _amount
	_amount = value
	_label.text = GameState.format_loot(_amount)
	if delta < -0.5:
		_flash = 1.0
		_shake = 1.0
		_spawn_floating(-delta)

func _process(delta: float) -> void:
	if _flash <= 0.0 and _shake <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta * 3.0)
	_shake = maxf(0.0, _shake - delta * 4.5)
	_label.add_theme_color_override("font_color", GOLD.lerp(FLASH, _flash))
	var base := Vector2(icon_size + 8.0, 0.0)
	_label.position = base + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 5.0

func _draw() -> void:
	draw_texture_rect_region(SHEET, Rect2(0.0, 0.0, icon_size, icon_size), COIN_REGION)

## Leteci "-Xk" koji odlebdi nagore i izbledi.
func _spawn_floating(amount_lost: float) -> void:
	var fl := Label.new()
	fl.text = "-" + GameState.format_loot(amount_lost)
	fl.add_theme_font_size_override("font_size", loss_font_size)
	fl.add_theme_color_override("font_color", FLASH)
	fl.position = Vector2(icon_size + 8.0, -2.0)
	fl.pivot_offset = Vector2(20.0, float(loss_font_size) * 0.5)
	fl.scale = Vector2(1.5, 1.5)   # pop pa se smiri
	add_child(fl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(fl, "position:y", -42.0, 0.9)
	tw.tween_property(fl, "modulate:a", 0.0, 0.9)
	tw.tween_property(fl, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(fl.queue_free)
