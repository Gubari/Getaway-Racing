extends CharacterBody2D
## POLICIJSKI AI: state masina (CHASE / SEARCHING / RETURNING) + vision cone.
## Vlasnik: B. NAJRIZICNIJI sistem - zacementirati prvi (faza 3-5h).
##
## KRETANJE: NavigationAgent2D prati navmesh -> obilazi zidove i coskove.
## ZAHTEV: scena mora imati NavigationRegion2D sa pecenom navigacijom
## (u pravom gradu to prave A/C; u test sceni se pece u runtime-u).

enum State { CHASE, SEARCHING, RETURNING }

@export var chase_speed: float = 240.0
@export var search_speed: float = 150.0
@export var return_speed: float = 120.0
@export var vision_range: float = 350.0
@export var vision_angle_deg: float = 60.0    # PUN ugao konusa
@export var close_range: float = 160.0        # unutar ovoga te OSETI bez obzira na ugao (kola su bucna)
@export var lose_sight_grace: float = 2.0     # "vruca potera" - obilazi zid ka tvojoj stvarnoj poziciji
@export var search_time: float = 6.0          # ukupno vreme pretrage pre RETURNING
@export var look_time: float = 0.8            # pauza da "osmotri" na svakoj tacki
@export var peek_distance: float = 200.0      # bazni domet "juri kuda je pobegao" (obilazi zid)
@export var patrol_radius: float = 140.0      # radijus laganog krstarenja u RETURNING
@export var catch_distance: float = 28.0      # kad te stigne izbliza -> uhvacen
@export var turn_speed: float = 9.0           # glatkoca rotacije (lerp)

@export_group("Sprite")
@export var car_anim_fps: float = 14.0

const TEX_NORMAL := preload("res://assets/sprites/police/police_car_drive.png")
const TEX_CHASING := preload("res://assets/sprites/police/police_car_chasing_drive.png")
const CAR_ANIM_FRAMES := 6

var state: State = State.CHASE                # nivo pocinje ODMAH u CHASE
var player: Node2D = null
var home_position: Vector2                    # gde se vraca u RETURNING
var last_known_pos: Vector2 = Vector2.ZERO
var last_seen_dir: Vector2 = Vector2.ZERO     # kuda je igrac isao kad je nestao
var move_target: Vector2 = Vector2.ZERO       # trenutna meta kretanja (drzi se dok ne stigne)
var search_queue: Array[Vector2] = []         # planirana mesta za proveru (redom)
var search_timer: float = 0.0
var look_timer: float = 0.0
var lose_timer: float = 0.0                    # grace dok jos "pamti" igraca u CHASE

# watchdog protiv zaglavljivanja
var _last_dist: float = INF
var _stuck_timer: float = 0.0

var _car_anim_accum: float = 0.0

@onready var los_ray: RayCast2D = $LineOfSight
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var _car_sprite: Sprite2D = $CarSprite

func _ready() -> void:
	add_to_group(Constants.GROUP_POLICE)
	player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
	los_ray.collision_mask = Constants.LAYER_WALLS   # raycast vidi SAMO zidove
	home_position = global_position
	move_target = global_position
	agent.path_desired_distance = 8.0
	agent.target_desired_distance = 16.0

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
		return

	var can_see := _can_see_player()
	match state:
		State.CHASE:     _do_chase(delta, can_see)
		State.SEARCHING: _do_searching(delta, can_see)
		State.RETURNING: _do_returning(delta, can_see)

	_update_car_sprite(delta)
	queue_redraw()   # da se vision cone iscrta

## Sprite je dete tela pa se rotira sa fizikom (nos = +X). U CHASE i SEARCHING
## state-u koristi chasing teksturu (upaljene sirene) i animira stalno; u
## RETURNING koristi normalnu teksturu koja se animira samo dok se krece.
func _update_car_sprite(delta: float) -> void:
	if _car_sprite == null:
		return

	var sirens_on := state == State.CHASE or state == State.SEARCHING
	var tex := TEX_CHASING if sirens_on else TEX_NORMAL
	if _car_sprite.texture != tex:
		_car_sprite.texture = tex

	if sirens_on or velocity.length() > 5.0:
		_car_anim_accum += delta * car_anim_fps
		_car_sprite.frame = int(_car_anim_accum) % CAR_ANIM_FRAMES

# --- VISION: ugao + domet + line-of-sight ---
func _can_see_player() -> bool:
	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist > vision_range:
		return false
	# Ugao proveravamo SAMO ako nije veoma blizu (izbliza ga oseti periferno).
	if dist > close_range:
		var facing := Vector2.RIGHT.rotated(rotation)
		if absf(rad_to_deg(facing.angle_to(to_player))) > vision_angle_deg * 0.5:
			return false
	los_ray.target_position = los_ray.to_local(player.global_position)
	los_ray.force_raycast_update()
	return not los_ray.is_colliding()   # udari zid -> NE vidi te

# --- STATE PONASANJA ---
func _do_chase(delta: float, can_see: bool) -> void:
	if can_see:
		lose_timer = lose_sight_grace        # resetuj "pamcenje"
		var d := player.global_position - last_known_pos
		if d.length() > 4.0:
			last_seen_dir = d.normalized()   # zapamti kuda igrac ide
		last_known_pos = player.global_position
		move_target = player.global_position
		agent.target_position = move_target
		_move(delta, chase_speed)
		if GameState.is_running and global_position.distance_to(player.global_position) <= catch_distance:
			GameState.caught()   # uhvacen (samo dok trka traje)
	else:
		# Vruca potera: jos te "oseca" pa OBILAZI zid ka tvojoj STVARNOJ poziciji.
		# Zato te ne izgubi ako samo zadjes iza jednog zida - obici ce ga i naci.
		lose_timer -= delta
		if lose_timer > 0.0:
			var d := player.global_position - last_known_pos
			if d.length() > 4.0:
				last_seen_dir = d.normalized()
			last_known_pos = player.global_position   # prati stvarnu poziciju dok traje vruca potera
			move_target = last_known_pos
			agent.target_position = move_target
			_move(delta, chase_speed)
		else:
			_enter_searching()

func _enter_searching() -> void:
	state = State.SEARCHING
	search_timer = search_time
	look_timer = look_time
	# Plan istrage: 1) juri KUDA je pobegao (obilazi zid)  2) pa nazad na poslednju poziciju
	search_queue = [_project_escape_point(), last_known_pos]
	_next_search_point()

# Tacka u pravcu bekstva, projektovana NA navmesh (iza zida, na dostupnoj strani).
# Bira najdalju tacku duz pravca koja stvarno postoji na navigaciji - tako navmesh
# provede policiju OKO zida do mesta gde si verovatno otisao, umesto da stane ispred.
func _project_escape_point() -> Vector2:
	if last_seen_dir == Vector2.ZERO:
		return last_known_pos
	var map := agent.get_navigation_map()
	var best := last_known_pos
	for mult: float in [0.5, 1.0, 1.5, 2.0]:
		var p := last_known_pos + last_seen_dir * (peek_distance * mult)
		if NavigationServer2D.map_get_closest_point(map, p).distance_to(p) < 24.0:
			best = p   # tacka je na navmesh-u (nije u zidu) -> dostizna
	return best

func _do_searching(delta: float, can_see: bool) -> void:
	if can_see:
		state = State.CHASE
		return
	search_timer -= delta
	if search_timer <= 0.0:
		state = State.RETURNING
		look_timer = look_time
		_set_target(_patrol_point())
		return

	_move(delta, search_speed)
	# stigao na metu ILI zaglavljen -> osmotri pa sledece planirano mesto
	if _arrived() or _is_stuck(delta):
		look_timer -= delta
		if look_timer <= 0.0:
			_next_search_point()
			look_timer = look_time

func _next_search_point() -> void:
	if search_queue.is_empty():
		_set_target(_random_search_point())   # nema vise planiranih -> osmatraj okolo
	else:
		_set_target(search_queue.pop_front())

func _do_returning(delta: float, can_see: bool) -> void:
	if can_see:
		state = State.CHASE   # cim te spaze -> instant CHASE
		return
	GameState.add_heat(-15.0 * delta)   # heat opada
	_move(delta, return_speed)
	# lagano krstari po zoni - nije aktivna potera, ali nije ni mrtav
	if _arrived() or _is_stuck(delta):
		look_timer -= delta
		if look_timer <= 0.0:
			_set_target(_patrol_point())
			look_timer = look_time * 1.5   # opusteniji ritam nego u pretrazi

# --- KRETANJE (preko navmesh-a) ---
func _set_target(t: Vector2) -> void:
	move_target = t
	agent.target_position = t
	_last_dist = INF
	_stuck_timer = 0.0

func _move(delta: float, speed: float) -> void:
	if agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# Prati sledecu tacku putanje koju navmesh racuna (obilazi zidove/coskove).
	var next_point := agent.get_next_path_position()
	var desired := (next_point - global_position).normalized()
	rotation = lerp_angle(rotation, desired.angle(), turn_speed * delta)
	velocity = Vector2.RIGHT.rotated(rotation) * speed   # vozi NAPRED po nosu (car-feel)
	move_and_slide()

func _arrived() -> bool:
	return agent.is_navigation_finished()

func _is_stuck(delta: float) -> bool:
	var d := global_position.distance_to(move_target)
	if d < _last_dist - 1.0:
		_last_dist = d
		_stuck_timer = 0.0
	else:
		_stuck_timer += delta
	return _stuck_timer > 0.6   # ne napreduje 0.6s -> tretiraj kao zaglavljen

func _random_search_point() -> Vector2:
	return last_known_pos + Vector2(randf_range(-160, 160), randf_range(-160, 160))

func _patrol_point() -> Vector2:
	return last_known_pos + Vector2(randf_range(-patrol_radius, patrol_radius), randf_range(-patrol_radius, patrol_radius))

# --- VIZUELNI KONUS (ziri mora da vidi "kad me vide") ---
func _draw() -> void:
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
	# krug "osecaja iz blizine" (close_range) - radi orijentacije pri stelovanju
	draw_arc(Vector2.ZERO, close_range, 0.0, TAU, 32, Color(1, 1, 1, 0.25), 2.0)
