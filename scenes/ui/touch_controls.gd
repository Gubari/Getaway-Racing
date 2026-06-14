extends Control
## Touch layout: strelice dole levo (bez pozadine), gas+kocnica dole desno kao auto-pedale.
## Vlasnik: D. TouchScreenButton je Node2D — pozicije se racunaju iz velicine ovog Control cvora.
##
## SKALIRANJE:
##  - Cela igra se skalira preko Project Settings -> Display -> Window -> Stretch
##    (mode = canvas_items, aspect = expand). Bazna rezolucija je 1280x720.
##  - Dimenzije dugmadi su @export polja (u baznim px) -> menjaj ih u Inspectoru.
##  - ui_scale je globalni mnozilac za sve kontrole (1.0 = bazno, 1.5 = vece).

@export_group("Skaliranje")
## Globalni mnozilac velicine svih kontrola. Povecaj ako su dugmad sitna na telefonu.
@export_range(0.5, 3.0, 0.05) var ui_scale: float = 1.0

@export_group("Dimenzije (bazni px)")
@export var steer_btn_size: Vector2 = Vector2(140.0, 140.0)
@export var steer_gap: float = 40.0
## Kocnica je sira, gas uzi (kao u stvarnom autu) — poravnati po istoj donjoj ravni.
@export var brake_pedal_size: Vector2 = Vector2(116.0, 124.0)
@export var gas_pedal_size: Vector2 = Vector2(90.0, 190.0)
@export var pedal_gap: float = 40.0
@export var bottom_margin: float = 18.0
@export var card_strip_h: float = 110.0

@export_group("Debug")
@export var show_input_debug: bool = true

const STEER_ARROW := Color(0.95, 0.96, 1.0, 0.96)
const STEER_ARROW_PRESSED := Color(0.55, 0.78, 1.0, 1.0)
const STEER_OUTLINE := Color(0.0, 0.0, 0.0, 0.55)

const PEDAL_PAD := Color(0.82, 0.82, 0.85)
const PEDAL_PAD_PRESSED := Color(0.66, 0.66, 0.7)
const PEDAL_BORDER := Color(0.32, 0.32, 0.37)
const PEDAL_GRIP := Color(0.46, 0.46, 0.52)
const PEDAL_BASE := Color(0.24, 0.24, 0.29)

@onready var _steer_left: TouchScreenButton = $SteerLeftZone
@onready var _steer_right: TouchScreenButton = $SteerRightZone
@onready var _brake: TouchScreenButton = $BrakeButton
@onready var _gas: TouchScreenButton = $GasButton
@onready var _labels_layer: Control = $LabelsLayer

var _debug_label: Label

func _ready() -> void:
	_steer_left.action = Constants.INPUT_STEER_LEFT
	_steer_right.action = Constants.INPUT_STEER_RIGHT
	_brake.action = Constants.INPUT_BRAKE
	_gas.action = Constants.INPUT_GAS

	for button in [_steer_left, _steer_right, _brake, _gas]:
		button.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
		button.passby_press = false

	if show_input_debug:
		_setup_debug_label()

	resized.connect(_layout_buttons)
	call_deferred("_layout_buttons")

	GameState.game_won.connect(_disable_controls)
	GameState.game_over.connect(_disable_controls)

func _process(_delta: float) -> void:
	if _debug_label == null:
		return
	_debug_label.text = (
		"Input | G:%.1f B:%.1f L:%.1f R:%.1f"
		% [
			Input.get_action_strength(Constants.INPUT_GAS),
			Input.get_action_strength(Constants.INPUT_BRAKE),
			Input.get_action_strength(Constants.INPUT_STEER_LEFT),
			Input.get_action_strength(Constants.INPUT_STEER_RIGHT),
		]
	)

func _layout_buttons() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return

	var s: float = maxf(ui_scale, 0.1)
	var steer_dims: Vector2 = steer_btn_size * s
	var brake_dims: Vector2 = brake_pedal_size * s
	var gas_dims: Vector2 = gas_pedal_size * s
	var margin: float = bottom_margin * s
	var s_gap: float = steer_gap * s
	var p_gap: float = pedal_gap * s

	var screen_w: float = size.x
	var screen_h: float = size.y

	# --- Strelice: dole levo, jedna pored druge ---
	var steer_center_y: float = screen_h - margin - steer_dims.y * 0.5
	var steer_left_x: float = margin + steer_dims.x * 0.5
	var steer_right_x: float = steer_left_x + steer_dims.x + s_gap
	_place_button(_steer_left, steer_dims, Vector2(steer_left_x, steer_center_y), "steer_left")
	_place_button(_steer_right, steer_dims, Vector2(steer_right_x, steer_center_y), "steer_right")

	# --- Gas + kocnica: dole desno, poravnati po DNU (ista ravan) ---
	var gas_center_x: float = screen_w - margin - gas_dims.x * 0.5
	var gas_center_y: float = screen_h - margin - gas_dims.y * 0.5
	var brake_center_x: float = screen_w - margin - gas_dims.x - p_gap - brake_dims.x * 0.5
	var brake_center_y: float = screen_h - margin - brake_dims.y * 0.5
	_place_button(_brake, brake_dims, Vector2(brake_center_x, brake_center_y), "brake")
	_place_button(_gas, gas_dims, Vector2(gas_center_x, gas_center_y), "gas")

	if _debug_label != null:
		_debug_label.position = Vector2(screen_w * 0.5 - 160.0, screen_h - card_strip_h + 8.0)
		_debug_label.size = Vector2(320.0, 24.0)

func _place_button(button: TouchScreenButton, tex_dims: Vector2, center: Vector2, kind: String) -> void:
	var tex_size: Vector2i = Vector2i(maxi(int(tex_dims.x), 8), maxi(int(tex_dims.y), 8))
	button.texture_normal = _make_button_texture(tex_size, kind, false)
	button.texture_pressed = _make_button_texture(tex_size, kind, true)
	button.position = center - tex_dims * 0.5

func _make_button_texture(tex_size: Vector2i, kind: String, pressed: bool) -> ImageTexture:
	var image := Image.create(tex_size.x, tex_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	if kind == "steer_left" or kind == "steer_right":
		_draw_steer_arrow(image, kind == "steer_left", pressed)
	else:
		_draw_pedal(image, pressed)

	return ImageTexture.create_from_image(image)

# --- STRELICE (bez pozadine, samo strelica + senka) ---
func _draw_steer_arrow(image: Image, is_left: bool, pressed: bool) -> void:
	var w := float(image.get_width())
	var h := float(image.get_height())
	var tri: PackedVector2Array
	if is_left:
		tri = PackedVector2Array([
			Vector2(w * 0.28, h * 0.5),
			Vector2(w * 0.66, h * 0.22),
			Vector2(w * 0.66, h * 0.78),
		])
	else:
		tri = PackedVector2Array([
			Vector2(w * 0.72, h * 0.5),
			Vector2(w * 0.34, h * 0.22),
			Vector2(w * 0.34, h * 0.78),
		])

	# Senka/outline: ista strelica malo veca, tamna
	_fill_polygon(image, _scale_polygon(tri, 1.18), STEER_OUTLINE)
	var arrow := STEER_ARROW_PRESSED if pressed else STEER_ARROW
	_fill_polygon(image, tri, arrow)

# --- AUTO-PEDALA (sivi gumeni pad + tackice + rebra) ---
func _draw_pedal(image: Image, pressed: bool) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var corner := clampi(int(round(mini(w, h) * 0.30)), 8, 34)

	# Donja metalna baza (osovina pedale)
	var base_h := maxi(int(h * 0.07), 4)
	_fill_round_rect(image, Rect2i(int(w * 0.30), h - base_h, int(w * 0.40), base_h), 2, PEDAL_BASE)

	var pad_color := PEDAL_PAD_PRESSED if pressed else PEDAL_PAD
	var top := int(h * (0.10 if pressed else 0.03))
	var pad_rect := Rect2i(2, top, w - 4, h - top - int(base_h * 0.6))

	# Ivica + pad
	_fill_round_rect(image, pad_rect, corner, PEDAL_BORDER)
	var inner := Rect2i(pad_rect.position.x + 4, pad_rect.position.y + 4, pad_rect.size.x - 8, pad_rect.size.y - 8)
	_fill_round_rect(image, inner, maxi(corner - 4, 4), pad_color)

	# Highlight na vrhu
	var hl := pad_color.lightened(0.18)
	_fill_round_rect(
		image,
		Rect2i(inner.position.x + 2, inner.position.y + 2, inner.size.x - 4, int(inner.size.y * 0.22)),
		maxi(corner - 6, 3),
		hl
	)

	# Tackice (grip) u gornje dve trecine
	var dot_r := maxf(float(w) * 0.035, 1.5)
	var cols := 4
	var rows := 3
	var area_x := inner.position.x + inner.size.x * 0.18
	var area_w := inner.size.x * 0.64
	var area_y := inner.position.y + inner.size.y * 0.16
	var area_h := inner.size.y * 0.42
	for r in range(rows):
		for c in range(cols):
			var dx := area_x + area_w * (float(c) / float(cols - 1))
			var dy := area_y + area_h * (float(r) / float(rows - 1))
			_fill_circle(image, Vector2(dx, dy), dot_r, PEDAL_GRIP)

	# Rebra (horizontalne linije) pri dnu
	var rib_count := 4
	var rib_y0 := inner.position.y + inner.size.y * 0.66
	var rib_gap := inner.size.y * 0.075
	var rib_h := maxi(int(inner.size.y * 0.03), 2)
	for i in range(rib_count):
		var ry := int(rib_y0 + rib_gap * i)
		_fill_round_rect(
			image,
			Rect2i(inner.position.x + int(inner.size.x * 0.16), ry, int(inner.size.x * 0.68), rib_h),
			int(rib_h / 2.0),
			PEDAL_GRIP
		)

func _scale_polygon(points: PackedVector2Array, factor: float) -> PackedVector2Array:
	var centroid := Vector2.ZERO
	for p in points:
		centroid += p
	centroid /= float(points.size())
	var out := PackedVector2Array()
	for p in points:
		out.append(centroid + (p - centroid) * factor)
	return out

func _fill_circle(image: Image, center: Vector2, radius: float, color: Color) -> void:
	var r := maxf(radius, 0.5)
	var x0 := maxi(0, int(floor(center.x - r)))
	var x1 := mini(image.get_width() - 1, int(ceil(center.x + r)))
	var y0 := maxi(0, int(floor(center.y - r)))
	var y1 := mini(image.get_height() - 1, int(ceil(center.y + r)))
	var r2 := r * r
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if Vector2(x + 0.5, y + 0.5).distance_squared_to(center) <= r2:
				image.set_pixel(x, y, color)

func _fill_round_rect(image: Image, rect: Rect2i, corner: int, color: Color) -> void:
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y
	var r := clampi(corner, 0, int(mini(rect.size.x, rect.size.y) / 2.0))

	var tl := Vector2(x0 + r, y0 + r)
	var c_tr := Vector2(x1 - r, y0 + r)
	var bl := Vector2(x0 + r, y1 - r)
	var br := Vector2(x1 - r, y1 - r)

	var px_y0 := maxi(0, y0)
	var px_y1 := mini(image.get_height(), y1)
	var px_x0 := maxi(0, x0)
	var px_x1 := mini(image.get_width(), x1)

	for y in range(px_y0, px_y1):
		for x in range(px_x0, px_x1):
			var p := Vector2(x + 0.5, y + 0.5)
			var inside := true
			if x < x0 + r and y < y0 + r:
				inside = p.distance_to(tl) <= r
			elif x >= x1 - r and y < y0 + r:
				inside = p.distance_to(c_tr) <= r
			elif x < x0 + r and y >= y1 - r:
				inside = p.distance_to(bl) <= r
			elif x >= x1 - r and y >= y1 - r:
				inside = p.distance_to(br) <= r
			if inside:
				image.set_pixel(x, y, color)

func _fill_polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	var min_y := points[0].y
	var max_y := points[0].y
	for point in points:
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)

	var y_start := maxi(0, int(floor(min_y)))
	var y_end := mini(image.get_height() - 1, int(ceil(max_y)))

	for y in range(y_start, y_end + 1):
		var scan_y := float(y) + 0.5
		var crossings: Array[float] = []
		var count := points.size()
		for i in range(count):
			var a := points[i]
			var b := points[(i + 1) % count]
			if (a.y <= scan_y and b.y > scan_y) or (b.y <= scan_y and a.y > scan_y):
				var t := (scan_y - a.y) / (b.y - a.y)
				crossings.append(a.x + t * (b.x - a.x))
		crossings.sort()
		var j := 0
		while j + 1 < crossings.size():
			var x_start := maxi(0, int(round(crossings[j])))
			var x_end := mini(image.get_width() - 1, int(round(crossings[j + 1])))
			for x in range(x_start, x_end + 1):
				image.set_pixel(x, y, color)
			j += 2

func _setup_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_label.add_theme_font_size_override("font_size", 13)
	_debug_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7, 0.9))
	_labels_layer.add_child(_debug_label)

func _disable_controls() -> void:
	for button in [_steer_left, _steer_right, _brake, _gas]:
		button.action = ""
		button.visible = false
