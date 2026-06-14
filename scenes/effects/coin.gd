extends Node2D
## Novcic ($ iz UI sheet-a) koji ISPADNE iz auta na sudar: skok (parabola) + drift
## + senka + fade. Cisto vizuelni juice. Vlasnik: B. Pozovi launch() posle spawn-a.

const SHEET := preload("res://assets/sprites/ui/Modern_UI_Style_2_32x32.png")
const COIN_REGION := Rect2(294, 776, 48, 48)   # veliki $ novcic, prikazan malen

@export var size_px: float = 18.0
@export var lifetime: float = 1.2
@export var gravity: float = 1000.0

var _vel: Vector2 = Vector2.ZERO   # horizontalni drift
var _h: float = 0.0                # fake visina (skok)
var _vh: float = 0.0               # brzina po visini
var _age: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Izbaci novcic: skok nagore + nasumican drift u stranu.
func launch() -> void:
	_vel = Vector2.from_angle(randf() * TAU) * randf_range(40.0, 140.0)
	_vh = randf_range(240.0, 380.0)
	_h = 1.0

func _process(delta: float) -> void:
	_age += delta
	_vh -= gravity * delta
	_h += _vh * delta
	if _h <= 0.0:
		_h = 0.0
		_vh = -_vh * 0.4 if _vh < -60.0 else 0.0   # mali odskok pa miruje
	position += _vel * delta
	_vel = _vel.move_toward(Vector2.ZERO, 260.0 * delta)
	queue_redraw()
	if _age >= lifetime:
		queue_free()

func _draw() -> void:
	var a := 1.0
	var fade := lifetime * 0.35
	if _age > lifetime - fade:
		a = clampf((lifetime - _age) / fade, 0.0, 1.0)
	# senka na tlu (veca kad je novcic nize)
	var shadow := size_px * (0.42 - 0.12 * clampf(_h / 30.0, 0.0, 1.0))
	draw_circle(Vector2(0, 1), shadow, Color(0, 0, 0, 0.22 * a))
	# novcic podignut za _h (skok)
	var dest := Rect2(-size_px * 0.5, -size_px * 0.5 - _h, size_px, size_px)
	draw_texture_rect_region(SHEET, dest, COIN_REGION, Color(1, 1, 1, a))
