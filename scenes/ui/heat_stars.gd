extends Control
## Heat kao zvezdice (wanted level): broj zvezdica = GameState.heat_level.
## heat 0 = nijedna; svaka sledeca pojavljuje 1 zvezdu vise.
## Sprite: Modern_UI_Style_2_32x32.png -> red 2, kol 13 (zlatna zvezda). Vlasnik: B.

const SHEET := preload("res://assets/sprites/ui/Modern_UI_Style_2_32x32.png")
const TILE := 32
const STAR := Rect2(12 * TILE, 1 * TILE, TILE, TILE)   # red 2, kol 13 (puna zlatna zvezda)

@export var max_stars: int = 5
@export var star_size: float = 30.0
@export var gap: float = 4.0

var _heat: int = 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # ostri pikseli
	custom_minimum_size = Vector2(max_stars * (star_size + gap), star_size)
	GameState.heat_changed.connect(_on_heat_changed)
	_heat = GameState.heat_level
	queue_redraw()

func _on_heat_changed(level: int) -> void:
	_heat = level
	queue_redraw()

func _draw() -> void:
	for i in mini(_heat, max_stars):
		var dest := Rect2(Vector2(i * (star_size + gap), 0.0), Vector2(star_size, star_size))
		draw_texture_rect_region(SHEET, dest, STAR)
