extends Node2D
## Placeholder test mapa sa zidovima i bazom. Vlasnik: A.
## C zamenjuje tile-ovima kasnije; zidovi ostaju StaticBody2D na layer 3.

const ARENA := Rect2(50, 50, 1300, 800)

const WALL_RECTS: Array[Rect2] = [
	Rect2(50, 50, 1300, 40),
	Rect2(50, 810, 1300, 40),
	Rect2(50, 50, 40, 800),
	Rect2(1310, 50, 40, 800),
	Rect2(250, 180, 220, 50),
	Rect2(500, 320, 50, 180),
	Rect2(750, 480, 200, 50),
	Rect2(950, 250, 50, 200),
	Rect2(600, 620, 140, 50),
]

@onready var _walls: Node2D = $Walls

func _ready() -> void:
	for rect in WALL_RECTS:
		_walls.add_child(_make_wall(rect))
	queue_redraw()

func get_arena_rect() -> Rect2:
	return ARENA

func get_player_spawn() -> Vector2:
	return Vector2(150, 450)

func get_police_spawn() -> Vector2:
	return Vector2(150, 200)

func get_garage_spawn() -> Vector2:
	return Vector2(1200, 450)

func _make_wall(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = Constants.LAYER_WALLS
	body.collision_mask = 0
	body.add_to_group(Constants.GROUP_WALLS)
	body.position = rect.position + rect.size * 0.5

	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	body.add_child(shape_node)

	var visual := Polygon2D.new()
	visual.color = Color(0.28, 0.28, 0.34)
	var half := rect.size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	body.add_child(visual)
	return body

func _on_base_body_entered(body: Node2D) -> void:
	if body.is_in_group(Constants.GROUP_PLAYER):
		GameState.reach_base()

func _draw() -> void:
	draw_rect(ARENA, Color(0.12, 0.14, 0.18))
