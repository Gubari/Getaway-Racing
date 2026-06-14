extends Control
## HUD strelica ka bazi (direktan pravac). Skriva se blizu garaže, treperi kad ima heat.
## Vlasnik: D.

@export var hide_distance: float = 150.0
@export var edge_margin: float = 78.0
@export var arrow_length: float = 42.0
@export var arrow_width: float = 30.8

const _COLOR_SAFE := Color(0.35, 0.92, 0.55, 0.95)
const _COLOR_HEAT := Color(0.95, 0.35, 0.32, 0.95)
const _COLOR_OUTLINE := Color(0.0, 0.0, 0.0, 0.55)
const _BLINK_INTERVAL := 0.35

var _blink_timer: float = 0.0
var _arrow_color: Color = _COLOR_SAFE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(arrow_length * 2.2, arrow_length * 2.2)
	pivot_offset = custom_minimum_size * 0.5
	GameState.game_won.connect(_hide)
	GameState.game_over.connect(_hide)
	visible = false

func _process(delta: float) -> void:
	if not GameState.is_running or get_tree().paused:
		visible = false
		return

	var player := get_tree().get_first_node_in_group(Constants.GROUP_PLAYER) as Node2D
	var garage := get_tree().get_first_node_in_group(Constants.GROUP_GARAGE) as Node2D
	if player == null or garage == null:
		visible = false
		return

	var to_base := garage.global_position - player.global_position
	if to_base.length() <= hide_distance:
		visible = false
		return

	visible = true
	_update_indicator(garage)
	_update_color(delta)
	queue_redraw()

func _update_indicator(garage: Node2D) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var world_offset := garage.global_position - cam.global_position
	var screen_offset := Vector2(world_offset.x * cam.zoom.x, world_offset.y * cam.zoom.y)
	var edge_pos := _edge_position(screen_center, screen_offset, edge_margin)
	position = edge_pos - pivot_offset
	rotation = screen_offset.angle()

func _edge_position(center: Vector2, offset: Vector2, margin: float) -> Vector2:
	if offset.length_squared() < 1.0:
		return center
	var dir := offset.normalized()
	var half := center - Vector2(margin, margin)
	var scale_x := half.x / absf(dir.x) if absf(dir.x) > 0.0001 else INF
	var scale_y := half.y / absf(dir.y) if absf(dir.y) > 0.0001 else INF
	return center + dir * minf(scale_x, scale_y)

func _update_color(delta: float) -> void:
	if GameState.heat_level <= 0:
		_blink_timer = 0.0
		_arrow_color = _COLOR_SAFE
		modulate = Color.WHITE
		return

	_blink_timer += delta
	var blink_on := int(_blink_timer / _BLINK_INTERVAL) % 2 == 0
	_arrow_color = _COLOR_HEAT
	modulate = Color(1.0, 1.0, 1.0, 1.0 if blink_on else 0.4)

func _draw() -> void:
	var center := pivot_offset
	var tip := center + Vector2(arrow_length, 0.0)
	var back_top := center + Vector2(-arrow_length * 0.55, -arrow_width * 0.5)
	var back_bot := center + Vector2(-arrow_length * 0.55, arrow_width * 0.5)
	var pts := PackedVector2Array([tip, back_top, back_bot])
	draw_colored_polygon(pts, _arrow_color)
	draw_polyline(pts + PackedVector2Array([tip]), _COLOR_OUTLINE, 2.8, true)

func _hide() -> void:
	visible = false
