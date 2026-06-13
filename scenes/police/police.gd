extends CharacterBody2D
## POLICIJSKI AI: state masina (CHASE / SEARCHING / RETURNING) + vision cone.
## Vlasnik: B. NAJRIZICNIJI sistem - zacementirati prvi (faza 3-5h).

enum State { CHASE, SEARCHING, RETURNING }

@export var speed: float = 220.0
@export var vision_range: float = 350.0
@export var vision_angle_deg: float = 60.0   # PUN ugao konusa
@export var search_time: float = 5.0         # sek pretrage pre RETURNING

var state: State = State.CHASE                # nivo pocinje ODMAH u CHASE
var player: Node2D = null
var last_known_pos: Vector2 = Vector2.ZERO
var search_timer: float = 0.0

@onready var los_ray: RayCast2D = $LineOfSight

func _ready() -> void:
	add_to_group(Constants.GROUP_POLICE)
	player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
	los_ray.collision_mask = Constants.LAYER_WALLS   # raycast vidi SAMO zidove
	queue_redraw()

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
		return

	var can_see := _can_see_player()
	match state:
		State.CHASE:     _do_chase(can_see)
		State.SEARCHING: _do_searching(delta, can_see)
		State.RETURNING: _do_returning(can_see)

	move_and_slide()
	queue_redraw()   # da se vision cone iscrta

# --- VISION: ugao + domet + line-of-sight ---
func _can_see_player() -> bool:
	var to_player := player.global_position - global_position
	if to_player.length() > vision_range:
		return false
	var facing := Vector2.RIGHT.rotated(rotation)   # TODO: pravac kretanja umesto rotacije po zelji
	if absf(rad_to_deg(facing.angle_to(to_player))) > vision_angle_deg * 0.5:
		return false
	los_ray.target_position = los_ray.to_local(player.global_position)
	los_ray.force_raycast_update()
	return not los_ray.is_colliding()   # udari zid -> NE vidi te

# --- STATE PONASANJA ---
func _do_chase(can_see: bool) -> void:
	if can_see:
		last_known_pos = player.global_position
		_move_toward(player.global_position)
	else:
		state = State.SEARCHING
		search_timer = search_time

func _do_searching(delta: float, can_see: bool) -> void:
	if can_see:
		state = State.CHASE
		return
	search_timer -= delta
	_move_toward(last_known_pos)
	if global_position.distance_to(last_known_pos) < 20.0:
		last_known_pos = _random_nearby_point()   # pretrazuj okolne ulice
	if search_timer <= 0.0:
		state = State.RETURNING

func _do_returning(can_see: bool) -> void:
	if can_see:
		state = State.CHASE   # cim te spaze -> instant CHASE
	# TODO (B): vrati se na rasporedjenu tacku, heat opada

# --- HELPERI ---
func _move_toward(target: Vector2) -> void:
	var dir := (target - global_position).normalized()
	velocity = dir * speed
	if dir != Vector2.ZERO:
		rotation = dir.angle()

func _random_nearby_point() -> Vector2:
	return global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))

# --- VIZUELNI KONUS (ziri mora da vidi "kad me vide") ---
func _draw() -> void:
	draw_colored_polygon(
		PackedVector2Array([Vector2(-16, -24), Vector2(16, -24), Vector2(16, 24), Vector2(-16, 24)]),
		Color(0.9, 0.25, 0.2)
	)
	var col := Color.RED
	if state == State.SEARCHING: col = Color.YELLOW
	elif state == State.RETURNING: col = Color.GRAY
	col.a = 0.22
	var pts := PackedVector2Array([Vector2.ZERO])
	var half := deg_to_rad(vision_angle_deg * 0.5)
	for i in range(13):
		var a := lerpf(-half, half, i / 12.0)
		pts.append(Vector2.RIGHT.rotated(a) * vision_range)
	draw_colored_polygon(pts, col)
