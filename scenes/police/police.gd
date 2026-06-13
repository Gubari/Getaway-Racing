extends CharacterBody2D
## POLICIJSKI AI: state masina (CHASE / SEARCHING / RETURNING) + vision cone.
## Vlasnik: B. NAJRIZICNIJI sistem - zacementirati prvi (faza 3-5h).
##
## KRETANJE: NavigationAgent2D bira put, ista top-down fizika kao player
## (ubrzavanje, drag, skretanje zavisi od brzine). Ulje i dalje pali _skid().

enum State { CHASE, SEARCHING, RETURNING }

@export var chase_speed: float = 420.0
@export var search_speed: float = 300.0
@export var return_speed: float = 180.0
@export var vision_range: float = 350.0
@export var vision_angle_deg: float = 60.0    # PUN ugao konusa
@export var close_range: float = 160.0        # unutar ovoga te OSETI bez obzira na ugao (kola su bucna)
@export var lose_sight_grace: float = 2.0     # "vruca potera" - obilazi zid ka tvojoj stvarnoj poziciji
@export var search_time: float = 6.0          # ukupno vreme pretrage pre RETURNING
@export var look_time: float = 0.8            # pauza da "osmotri" na svakoj tacki
@export var peek_distance: float = 200.0      # bazni domet "juri kuda je pobegao" (obilazi zid)
@export var patrol_radius: float = 140.0      # radijus laganog krstarenja u RETURNING
@export var catch_distance: float = 28.0      # kad te stigne izbliza -> uhvacen
@export var skid_spin: float = 7.0            # brzina vrtnje dok je bez kontrole (ulje)
@export var skid_friction: float = 160.0      # koliko brzo klizanje usporava

@export_group("Driving")
@export var acceleration: float = 480.0
@export var max_speed: float = 420.0
@export var reverse_max_speed: float = 160.0
@export var drag: float = 3.2
@export var brake_force: float = 1100.0
@export var steer_speed: float = 3.1
@export var steering_smoothing: float = 12.0
@export var min_speed_to_steer: float = 35.0
@export var high_speed_accel_factor: float = 0.45
@export var ai_steer_angle_deg: float = 45.0

@export_group("Crash")
@export var wall_crash_enabled: bool = true
@export var wall_penalty_rearm_sec: float = 0.75
@export var crash_min_impact_speed: float = 70.0
@export var crash_stun_sec: float = 0.3
@export var crash_knockback_min: float = 16.0
@export var crash_knockback_impact_scale: float = 0.035
@export var crash_steer_lock_sec: float = 0.3

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

# gubitak kontrole od ulja (klizanje + vrtnja)
var _control_lost_timer: float = 0.0
var _spin_dir: float = 1.0

# watchdog protiv zaglavljivanja
var _last_dist: float = INF
var _stuck_timer: float = 0.0

var _drive := TopDownCarDriving.new()
var _car_anim_accum: float = 0.0

@onready var los_ray: RayCast2D = $LineOfSight
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var _car_sprite: Sprite2D = $CarSprite

func _ready() -> void:
	add_to_group(Constants.GROUP_POLICE)
	player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
	los_ray.collision_mask = Constants.LAYER_WALLS   # raycast vidi SAMO zidove
	home_position = global_position
	# Na startu krece ka igracu (alarm zna gde si), NE ka (0,0) = cosak mape.
	last_known_pos = player.global_position if player != null else global_position
	move_target = last_known_pos
	agent.path_desired_distance = 8.0
	agent.target_desired_distance = 16.0
	_sync_drive_params()

func _sync_drive_params() -> void:
	_drive.acceleration = acceleration
	_drive.max_speed = max_speed
	_drive.reverse_max_speed = reverse_max_speed
	_drive.drag = drag
	_drive.brake_force = brake_force
	_drive.steer_speed = steer_speed
	_drive.steering_smoothing = steering_smoothing
	_drive.min_speed_to_steer = min_speed_to_steer
	_drive.high_speed_accel_factor = high_speed_accel_factor
	_drive.wall_penalty_rearm_sec = wall_penalty_rearm_sec
	_drive.crash_min_impact_speed = crash_min_impact_speed
	_drive.crash_stun_sec = crash_stun_sec
	_drive.crash_knockback_min = crash_knockback_min
	_drive.crash_knockback_impact_scale = crash_knockback_impact_scale
	_drive.crash_steer_lock_sec = crash_steer_lock_sec

func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
		if player != null:
			last_known_pos = player.global_position
		return

	if not GameState.is_running:
		_drive.stop()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _control_lost_timer > 0.0:
		_control_lost_timer -= delta

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

	if sirens_on or absf(_drive.get_forward_speed()) > 5.0:
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

func _move(delta: float, speed_cap: float) -> void:
	if _control_lost_timer > 0.0:
		_skid(delta)
		return

	var throttle := 0.0
	var steer_input := 0.0

	if not agent.is_navigation_finished():
		var next_point := agent.get_next_path_position()
		var to_next := next_point - global_position
		if to_next.length_squared() >= 16.0:
			var angle_diff := wrapf(to_next.angle() - rotation, -PI, PI)
			steer_input = clampf(
				angle_diff / deg_to_rad(ai_steer_angle_deg),
				-1.0,
				1.0
			)
			throttle = 1.0

	var pre_move_velocity := _drive.physics_step(self, delta, throttle, steer_input, speed_cap)
	if wall_crash_enabled:
		_drive.move_and_handle_walls(self, pre_move_velocity, 0.0)
	else:
		move_and_slide()

## Poziva je ULJE: policija gubi kontrolu (klizi po inerciji + vrti se) `duration` sek.
func lose_control(duration: float) -> void:
	if _control_lost_timer <= 0.0:
		_spin_dir = 1.0 if randf() < 0.5 else -1.0
		velocity = Vector2.from_angle(rotation) * _drive.get_forward_speed()
	_control_lost_timer = maxf(_control_lost_timer, duration)

func _skid(delta: float) -> void:
	rotation += _spin_dir * skid_spin * delta
	velocity = velocity.move_toward(Vector2.ZERO, skid_friction * delta)
	_drive.forward_speed = velocity.dot(Vector2.from_angle(rotation))
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

func is_returning() -> bool:
	return state == State.RETURNING

func is_searching() -> bool:
	return state == State.SEARCHING

func is_actively_pursuing() -> bool:
	return state == State.CHASE or state == State.SEARCHING

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
