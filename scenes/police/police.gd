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
@export var patrol_radius: float = 220.0      # radijus krstarenja u RETURNING (vece = duze deonice)
@export var catch_distance: float = 28.0      # kad te stigne izbliza -> uhvacen
@export var skid_spin: float = 7.0            # brzina vrtnje dok je bez kontrole (ulje)
@export var skid_friction: float = 160.0      # koliko brzo klizanje usporava
@export var barricade_smash_speed: float = 170.0   # iznad ove brzine PROBIJE barikadu (umesto da skrene)
@export var barricade_smash_slowdown: float = 0.25 # koliko ostane brzine posle probijanja
@export var corner_min_speed: float = 0.35    # min mnozilac brzine u najostrijem zaokretu (koci za zaokret)
@export var approach_distance: float = 120.0  # u roamu: u ovom dometu od mete pocinje da usporava (da stane, ne kruzi)

@export_group("Formacija (vise auta)")
@export var lane_spacing: float = 55.0        # bocni razmak po slotu (trake)
@export var row_spacing: float = 50.0         # pomeraj u dubinu (flankeri idu pozadi -> klin/V)
@export var formation_range: float = 250.0    # blize od ovoga -> konvergiraju ka igracu (za hvatanje)

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

@export_group("Siren")
@export var siren_volume_db: float = 0.0
@export var siren_max_distance: float = 4000.0
@export var siren_attenuation: float = 0.65

const TEX_NORMAL := preload("res://assets/sprites/police/police_car_drive.png")
const TEX_CHASING := preload("res://assets/sprites/police/police_car_chasing_drive.png")
const CAR_ANIM_FRAMES := 6
const SIREN := preload("res://assets/audio/sfx/police_siren.wav")

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

# watchdog protiv zaglavljivanja + spin (donut) detekcija
var _last_dist: float = INF
var _stuck_timer: float = 0.0
var _heading_accum: float = 0.0     # ukupno okretanje ka trenutnoj meti
var _prev_heading: float = 0.0

var _drive := TopDownCarDriving.new()
var _car_anim_accum: float = 0.0
var _siren: AudioStreamPlayer2D
var _siren_on: bool = false

@onready var los_ray: RayCast2D = $LineOfSight
@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var _car_sprite: Sprite2D = $CarSprite

func _ready() -> void:
	add_to_group(Constants.GROUP_POLICE)
	player = get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
	los_ray.collision_mask = Constants.LAYER_WALLS   # raycast vidi SAMO zidove
	collision_mask = Constants.LAYER_WALLS | Constants.LAYER_POLICE   # sudara se sa zidovima I drugim policajcima (ne preklapaju se)
	home_position = global_position
	# Na startu krece ka igracu (alarm zna gde si), NE ka (0,0) = cosak mape.
	last_known_pos = player.global_position if player != null else global_position
	move_target = last_known_pos
	agent.path_desired_distance = 8.0
	agent.target_desired_distance = 24.0   # veci prag "stigao" -> ne trazi pikselsku preciznost (manje kruzenja)
	_sync_drive_params()
	_setup_siren()

func _setup_siren() -> void:
	_siren = AudioStreamPlayer2D.new()
	_siren.stream = Audio.prepare_wav_loop(SIREN)
	_siren.bus = Audio.sfx_bus()
	_siren.volume_db = siren_volume_db
	_siren.max_distance = siren_max_distance
	_siren.attenuation = siren_attenuation
	_siren.panning_strength = 0.85
	add_child(_siren)

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
		_update_siren(false)
		return

	if not GameState.is_running:
		_drive.stop()
		velocity = Vector2.ZERO
		move_and_slide()
		_update_siren(false)
		return

	if _control_lost_timer > 0.0:
		_control_lost_timer -= delta

	var can_see := _can_see_player()
	match state:
		State.CHASE:     _do_chase(delta, can_see)
		State.SEARCHING: _do_searching(delta, can_see)
		State.RETURNING: _do_returning(delta, can_see)

	_update_siren(state == State.CHASE or state == State.SEARCHING)
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

func _update_siren(on: bool) -> void:
	_siren_on = on and GameState.is_running
	if _siren_on:
		if not _siren.playing:
			_siren.play()
	elif _siren.playing:
		_siren.stop()

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
		move_target = _formation_target(player.global_position)
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
			move_target = _formation_target(last_known_pos)
			agent.target_position = move_target
			_move(delta, chase_speed)
		else:
			_enter_searching()

## Pomeri metu u FORMACIJU po slotu (indeks medju policajcima): bocno + u dubinu
## (klin/V -> flankeri idu pozadi). Blizu igraca pomeraj nestaje pa konvergiraju.
func _formation_target(base: Vector2) -> Vector2:
	var cops := get_tree().get_nodes_in_group(Constants.GROUP_POLICE)
	var total := cops.size()
	if total <= 1:
		return base
	var to_base := base - global_position
	var dist := to_base.length()
	if dist < 1.0:
		return base
	var dir := to_base / dist
	var perp := Vector2(-dir.y, dir.x)
	var rank := float(cops.find(self)) - float(total - 1) * 0.5
	var factor := clampf(dist / formation_range, 0.0, 1.0)   # blizu -> konvergira (hvatanje)
	var offset := perp * (rank * lane_spacing) - dir * (absf(rank) * row_spacing)
	return base + offset * factor

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

	# stigao na metu ILI zaglavljen -> STANI i osmotri (ne kruzi), pa sledeca tacka
	if _arrived() or _is_stuck(delta):
		_idle(delta)
		look_timer -= delta
		if look_timer <= 0.0:
			_next_search_point()
			look_timer = look_time
	else:
		_move(delta, search_speed, true)

func _next_search_point() -> void:
	if search_queue.is_empty():
		_set_target(_random_search_point())   # nema vise planiranih -> osmatraj okolo
	else:
		_set_target(search_queue.pop_front())

func _do_returning(delta: float, can_see: bool) -> void:
	if can_see:
		state = State.CHASE   # cim te spaze -> instant CHASE
		return
	# Krstari KONTINUIRANO: stigne na tacku -> ODMAH uzme novu (napred), ne staje.
	# Stane samo ako se stvarno zaglavi ili navrti (donut).
	if _is_stuck(delta):
		_idle(delta)
		look_timer -= delta
		if look_timer <= 0.0:
			_set_target(_patrol_point())
			look_timer = look_time
	else:
		if _arrived():
			_set_target(_patrol_point())   # nastavi dalje bez stajanja
		_move(delta, return_speed)

# --- KRETANJE (preko navmesh-a) ---
func _set_target(t: Vector2) -> void:
	move_target = t
	agent.target_position = t
	_last_dist = INF
	_stuck_timer = 0.0
	_heading_accum = 0.0
	_prev_heading = rotation

func _move(delta: float, speed_cap: float, slow_near_target: bool = false) -> void:
	if _control_lost_timer > 0.0:
		_skid(delta)
		return

	var throttle := 0.0
	var steer_input := 0.0
	var cap := speed_cap

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
			cap = speed_cap * _speed_factor(angle_diff, slow_near_target)

	var pre_move_velocity := _drive.physics_step(self, delta, throttle, steer_input, cap)
	if wall_crash_enabled:
		_drive.move_and_handle_walls(self, pre_move_velocity, 0.0)
	else:
		move_and_slide()

	_check_barricade_smash()

## Mnozilac brzine: ostriji zaokret (uvek) + prilazak meti (samo roam) -> sporije.
## Sporije = manji radijus okretanja -> prati put oko zgrade i STIGNE na tacku (ne kruzi).
func _speed_factor(angle_diff: float, slow_near_target: bool) -> float:
	var turn_f := lerpf(1.0, corner_min_speed, clampf(absf(angle_diff) / PI, 0.0, 1.0))
	if not slow_near_target:
		return turn_f
	var approach_f := clampf(global_position.distance_to(move_target) / approach_distance, corner_min_speed, 1.0)
	return minf(turn_f, approach_f)

## Pri velikoj brzini policija PROBIJE barikadu (ona puca) i to je uspori.
## Barikada nije u grupi walls pa je kolegin wall-crash ignorise - hvatamo je ovde.
func _check_barricade_smash() -> void:
	if absf(_drive.get_forward_speed()) < barricade_smash_speed:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c and c.has_method("smash"):
			c.smash()
			_drive.forward_speed *= barricade_smash_slowdown   # probio ali usporen
			return

## Zakoci i stoji (osmatra) dok je u "look" pauzi - bez kruzenja oko bliske tacke.
func _idle(delta: float) -> void:
	_drive.physics_step(self, delta, 0.0, 0.0, return_speed)
	move_and_slide()

## Poziva je ULJE: policija gubi kontrolu (klizi po inerciji + vrti se) `duration` sek.
func lose_control(duration: float) -> void:
	var starting_skid := _control_lost_timer <= 0.0
	if starting_skid:
		_spin_dir = 1.0 if randf() < 0.5 else -1.0
		velocity = Vector2.from_angle(rotation) * _drive.get_forward_speed()
		Audio.play_tire_screech(global_position)
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
	# spin watchdog: previse navrteo ka istoj meti (donut) -> tretiraj kao zaglavljen
	_heading_accum += absf(wrapf(rotation - _prev_heading, -PI, PI))
	_prev_heading = rotation
	return _stuck_timer > 0.6 or _heading_accum > deg_to_rad(300.0)

func _random_search_point() -> Vector2:
	return _roam_point(last_known_pos, 160.0)

func _patrol_point() -> Vector2:
	return _roam_point(last_known_pos, patrol_radius)

## Roam tacka: "opipa" zidove zracima i bira NAJOTVORENIJI pravac napred (kao kola
## koja prate ulicu) -> nema ostrih zaokreta u zid. Ako je odlutao predaleko od
## zone -> bazni smer je nazad ka njoj. Snap na navmesh.
func _roam_point(center: Vector2, radius: float) -> Vector2:
	var base := rotation                             # podrazumevano: napred
	var to_center := center - global_position
	if to_center.length() > radius * 1.3:
		base = to_center.angle()                     # odlutao -> nazad ka zoni

	var space := get_world_2d().direct_space_state
	var best_dir := base
	var best_clear := -1.0
	for offset in [0.0, -0.45, 0.45, -0.9, 0.9]:     # napred + blagi otkloni
		var clear := _clear_distance(space, base + offset, radius)
		if clear > best_clear:
			best_clear = clear
			best_dir = base + offset

	var dist := clampf(best_clear - 40.0, 60.0, radius)   # idi tamo, ali stani pre zida
	var p := global_position + Vector2.from_angle(best_dir) * dist
	return NavigationServer2D.map_get_closest_point(agent.get_navigation_map(), p)

## Cist domet do zida u datom smeru (za biranje otvorenog pravca u roamu).
func _clear_distance(space: PhysicsDirectSpaceState2D, dir: float, max_dist: float) -> float:
	var to := global_position + Vector2.from_angle(dir) * max_dist
	var q := PhysicsRayQueryParameters2D.create(global_position, to, Constants.LAYER_WALLS)
	q.exclude = [self]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return max_dist
	return global_position.distance_to(hit.position)

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
