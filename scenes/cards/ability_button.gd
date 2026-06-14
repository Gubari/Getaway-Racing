extends Control
class_name AbilityButton
## Custom-crtano kruzno dugme moci: radijalni cooldown "sat", glow kad je spremno,
## proceduralna ikonica po tipu, charge-pip tackice, press efekat. Vlasnik: B.

var manager: Node
var index: int

var _color := Color(0.4, 0.4, 0.45)
var _type: int = -1
var _icon: Texture2D
var _radius := 42.0
var _time := 0.0
var _press := 0.0
var _last_tap_ms: int = -1000   # debounce za mouse+touch duplikat istog tapa

func setup(mgr: Node, idx: int) -> void:
	manager = mgr
	index = idx
	var ab: Card = manager.get_ability(idx)
	_type = ab.type if ab != null else -1
	_icon = ab.icon if ab != null else null
	_color = _color_for(_type)
	custom_minimum_size = Vector2(98, 98)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	_time += delta
	if _press > 0.0:
		_press = maxf(0.0, _press - delta * 4.0)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	# isti tap moze da okine i mouse i touch event -> ignorisi duplikat u 120ms
	var now := Time.get_ticks_msec()
	if now - _last_tap_ms < 120:
		return
	_last_tap_ms = now
	if manager != null and manager.is_ready(index) and manager.activate(index):
		_press = 1.0

func _draw() -> void:
	if manager == null:
		return
	var c := size * 0.5
	var avail: bool = manager.is_ready(index)
	var ratio: float = manager.get_cooldown_ratio(index)
	var charges: int = manager.get_charges(index)
	var r := _radius * (1.0 - _press * 0.1)

	# pulsirajuci glow prsten kad je spremno
	if avail:
		var g := 0.30 + 0.22 * sin(_time * 5.0)
		draw_arc(c, r + 6.0, 0.0, TAU, 48, Color(_color.lightened(0.4), g), 3.0, true)

	# baza + highlight + obod
	var base := _color if avail else _color.darkened(0.4)
	draw_circle(c, r, base)
	draw_circle(c - Vector2(0, r * 0.35), r * 0.55, Color(1, 1, 1, 0.06))
	draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.28), 2.0, true)

	# cooldown "sat" (tamni sektor koji se prazni kako se puni)
	if charges < 0 and ratio < 1.0:
		var start := -PI / 2.0
		_draw_sector(c, r - 1.0, start, start + (1.0 - ratio) * TAU, Color(0, 0, 0, 0.55))

	_draw_icon(c, r, avail)

	if charges >= 0:
		_draw_pips(c, r, charges)

func _draw_sector(c: Vector2, radius: float, start: float, end: float, color: Color) -> void:
	var pts := PackedVector2Array([c])
	for i in range(41):
		pts.append(c + Vector2.from_angle(lerpf(start, end, i / 40.0)) * radius)
	draw_colored_polygon(pts, color)

func _draw_icon(c: Vector2, r: float, avail: bool) -> void:
	var col := Color(1, 1, 1, 0.95 if avail else 0.45)
	if _icon != null:
		var side := r * 1.30
		var rect := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
		draw_texture_rect(_icon, rect, false, col)
		return
	var s := r * 0.52
	match _type:
		Card.Type.OIL:     # kapljica
			draw_circle(c + Vector2(0, s * 0.28), s * 0.52, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s * 0.72),
				c + Vector2(s * 0.42, s * 0.18),
				c + Vector2(-s * 0.42, s * 0.18),
			]), col)
		Card.Type.BARRICADE:   # tri horizontalne sipke (rampa)
			for k in 3:
				var yy := -s * 0.45 + k * s * 0.45
				draw_line(c + Vector2(-s * 0.75, yy), c + Vector2(s * 0.75, yy), col, 5.0)
		_:
			draw_circle(c, s * 0.4, col)

func _draw_pips(c: Vector2, r: float, charges: int) -> void:
	if charges <= 0:
		return
	var gap := 9.0
	var start_x := c.x - (charges - 1) * gap * 0.5
	var y := c.y + r * 0.66
	for k in charges:
		draw_circle(Vector2(start_x + k * gap, y), 3.2, Color(1, 1, 1, 0.9))

func _color_for(t: int) -> Color:
	match t:
		Card.Type.SPIKES: return Color(0.55, 0.56, 0.62)
		Card.Type.OIL: return Color(0.22, 0.34, 0.46)
		Card.Type.BARRICADE: return Color(0.9, 0.5, 0.12)
		Card.Type.NITRO: return Color(0.16, 0.52, 0.95)
		Card.Type.JOKER: return Color(0.72, 0.18, 0.28)
		_: return Color(0.4, 0.4, 0.45)
