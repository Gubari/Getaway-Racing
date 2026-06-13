extends CharacterBody2D
## VOZILO IGRACA: top-down fizika, kolizije, plen-curi logika.
## Vlasnik: A.

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

@export_group("Nitro")
@export var nitro_multiplier: float = 1.8
@export var nitro_duration: float = 0.75
@export var nitro_impulse: float = 280.0

@export_group("Crash")
@export var wall_penalty_rearm_sec: float = 0.75
@export var crash_min_impact_speed: float = 70.0
@export var crash_stun_sec: float = 0.3
@export var crash_loot_penalty: float = 15.0
@export var crash_knockback_min: float = 16.0
@export var crash_knockback_impact_scale: float = 0.035
@export var crash_steer_lock_sec: float = 0.3
@export var crash_shake_strength: float = 14.0
@export var crash_shake_duration: float = 0.24
@export var crash_zoom_punch: float = 0.07
@export var crash_wobble_max_deg: float = 10.0
@export var crash_squash_amount: float = 0.18

@export_group("Sharp Turn")
@export var sharp_turn_loot_penalty: float = 1.5
@export var sharp_turn_cooldown: float = 0.35
@export var sharp_turn_min_speed: float = 110.0
@export var sharp_turn_angular_speed_deg: float = 210.0
@export var sharp_turn_steer_threshold: float = 0.4

var _forward_speed: float = 0.0
var _steer_smoothed: float = 0.0
var _nitro_time_left: float = 0.0
var _sharp_turn_cooldown_left: float = 0.0
var _prev_rotation: float = 0.0
var _crash_stun_until_ms: int = 0
var _crash_steer_lock_until_ms: int = 0
var _wall_penalty_rearm_until_ms: Dictionary = {}
var _shake_time_left: float = 0.0
var _shake_normal: Vector2 = Vector2.ZERO
var _crash_juice_time_left: float = 0.0
var _crash_juice_intensity: float = 0.0
var _crash_wobble: float = 0.0
var _camera_base_zoom: Vector2 = Vector2.ONE

@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group(Constants.GROUP_PLAYER)
	GameState.card_played.connect(_on_card_played)
	_prev_rotation = rotation
	_camera_base_zoom = _camera.zoom
	_camera.make_current()
	queue_redraw()

func setup_camera_limits(arena: Rect2) -> void:
	_camera.limit_left = int(arena.position.x)
	_camera.limit_top = int(arena.position.y)
	_camera.limit_right = int(arena.position.x + arena.size.x)
	_camera.limit_bottom = int(arena.position.y + arena.size.y)
	_camera.limit_smoothed = true

func _physics_process(delta: float) -> void:
	if not GameState.is_running:
		_forward_speed = 0.0
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var throttle := _get_throttle()
	var steer_input := _get_steer_input()
	var steer_locked := Time.get_ticks_msec() < _crash_steer_lock_until_ms
	if steer_locked:
		steer_input = 0.0
		_steer_smoothed = 0.0
	else:
		_steer_smoothed = lerpf(_steer_smoothed, steer_input, steering_smoothing * delta)

	_update_forward_speed(throttle, delta)
	if not steer_locked:
		_apply_steering(delta)

	velocity = Vector2.from_angle(rotation) * _forward_speed
	var pre_move_velocity := velocity
	move_and_slide()
	_detect_wall_crash(pre_move_velocity)
	_detect_sharp_turn(delta)
	_prev_rotation = rotation

func _process(delta: float) -> void:
	if _nitro_time_left > 0.0:
		_nitro_time_left = maxf(0.0, _nitro_time_left - delta)
	if _sharp_turn_cooldown_left > 0.0:
		_sharp_turn_cooldown_left = maxf(0.0, _sharp_turn_cooldown_left - delta)
	if _crash_juice_time_left > 0.0:
		_crash_juice_time_left = maxf(0.0, _crash_juice_time_left - delta)
		queue_redraw()
	_update_camera_shake(delta)

func _update_camera_shake(delta: float) -> void:
	if _shake_time_left <= 0.0:
		_camera.offset = Vector2.ZERO
		_camera.zoom = _camera_base_zoom
		return

	_shake_time_left = maxf(0.0, _shake_time_left - delta)
	var t := _shake_time_left / crash_shake_duration if crash_shake_duration > 0.0 else 0.0
	var impulse := _shake_normal * crash_shake_strength * t
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * crash_shake_strength * 0.25 * t
	_camera.offset = impulse + jitter
	_camera.zoom = _camera_base_zoom * (1.0 + crash_zoom_punch * t)

func _get_throttle() -> float:
	var throttle := (
		Input.get_action_strength(Constants.INPUT_GAS)
		- Input.get_action_strength(Constants.INPUT_BRAKE)
	)
	if throttle > 0.0 and Time.get_ticks_msec() < _crash_stun_until_ms:
		return 0.0
	return throttle

func _get_steer_input() -> float:
	return (
		Input.get_action_strength(Constants.INPUT_STEER_RIGHT)
		- Input.get_action_strength(Constants.INPUT_STEER_LEFT)
	)

func _update_forward_speed(throttle: float, delta: float) -> void:
	if throttle > 0.0:
		var speed_ratio := clampf(absf(_forward_speed) / max_speed, 0.0, 1.0)
		var accel_mult := lerpf(1.0, high_speed_accel_factor, speed_ratio)
		_forward_speed += throttle * acceleration * accel_mult * delta
	elif throttle < 0.0:
		if _forward_speed > 0.0:
			_forward_speed -= brake_force * absf(throttle) * delta
		else:
			_forward_speed += throttle * acceleration * 0.55 * delta
	else:
		var decay := drag * maxf(absf(_forward_speed), 60.0) * delta
		_forward_speed = move_toward(_forward_speed, 0.0, decay)

	var cap := max_speed
	if _nitro_time_left > 0.0:
		cap = max_speed * nitro_multiplier
	_forward_speed = clampf(_forward_speed, -reverse_max_speed, cap)

func _apply_steering(delta: float) -> void:
	if absf(_forward_speed) < min_speed_to_steer:
		return

	var speed_factor := clampf(absf(_forward_speed) / max_speed, 0.25, 1.0)
	var direction_sign := 1.0 if _forward_speed >= 0.0 else -1.0
	rotation += _steer_smoothed * steer_speed * speed_factor * direction_sign * delta

func _on_card_played(card_type: int) -> void:
	if card_type == Card.Type.NITRO:
		_nitro_time_left = nitro_duration
		_forward_speed = minf(_forward_speed + nitro_impulse, max_speed * nitro_multiplier)
		GameState.nitro_used.emit()

func get_rear_spawn_point() -> Vector2:
	return global_position - Vector2.from_angle(rotation) * 48.0

func _detect_wall_crash(pre_move_velocity: Vector2) -> void:
	var now_ms := Time.get_ticks_msec()

	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if not collider is StaticBody2D:
			continue
		if not collider.is_in_group(Constants.GROUP_WALLS):
			continue

		var wall_id: int = collider.get_instance_id()
		if now_ms < int(_wall_penalty_rearm_until_ms.get(wall_id, 0)):
			continue

		var impact_speed := -pre_move_velocity.dot(collision.get_normal())
		if impact_speed < crash_min_impact_speed:
			continue

		_wall_penalty_rearm_until_ms[wall_id] = now_ms + int(wall_penalty_rearm_sec * 1000.0)
		GameState.crash_detected.emit(crash_loot_penalty)
		_apply_wall_crash(collision, impact_speed)
		return

func _apply_wall_crash(collision: KinematicCollision2D, impact_speed: float) -> void:
	var normal := collision.get_normal()
	var intensity := clampf(impact_speed / max_speed, 0.35, 1.25)
	var now_ms := Time.get_ticks_msec()

	_crash_stun_until_ms = now_ms + int(crash_stun_sec * 1000.0)
	_crash_steer_lock_until_ms = now_ms + int(crash_steer_lock_sec * 1000.0)
	_shake_time_left = crash_shake_duration
	_shake_normal = normal
	_crash_juice_time_left = crash_shake_duration
	_crash_juice_intensity = intensity
	_crash_wobble = deg_to_rad(crash_wobble_max_deg) * intensity * (1.0 if randf() > 0.5 else -1.0)
	_steer_smoothed = 0.0

	var knockback := crash_knockback_min + impact_speed * crash_knockback_impact_scale
	global_position += normal * knockback
	_forward_speed = 0.0
	velocity = Vector2.ZERO
	queue_redraw()

func _detect_sharp_turn(delta: float) -> void:
	if _sharp_turn_cooldown_left > 0.0:
		return
	if absf(_forward_speed) < sharp_turn_min_speed:
		return
	if absf(_steer_smoothed) < sharp_turn_steer_threshold:
		return

	var angular_speed_deg := absf(
		rad_to_deg(wrapf(rotation - _prev_rotation, -PI, PI)) / delta
	)
	if angular_speed_deg < sharp_turn_angular_speed_deg:
		return

	GameState.sharp_turn.emit(sharp_turn_loot_penalty)
	_sharp_turn_cooldown_left = sharp_turn_cooldown

func _draw() -> void:
	var squash := 1.0
	var stretch := 1.0
	var wobble_angle := 0.0
	if _crash_juice_time_left > 0.0 and crash_shake_duration > 0.0:
		var t := _crash_juice_time_left / crash_shake_duration
		squash = 1.0 + crash_squash_amount * t
		stretch = 1.0 - crash_squash_amount * 0.75 * t
		wobble_angle = _crash_wobble * t

	# Lokalni prostor: nos auta je uvek +X (rotation cvora vec okrece sprite).
	var forward := Vector2.RIGHT.rotated(wobble_angle)
	var right := forward.orthogonal()

	var body := PackedVector2Array([
		-right * 16.0 * squash + forward * -24.0 * stretch,
		right * 16.0 * squash + forward * -24.0 * stretch,
		right * 16.0 * squash + forward * 24.0 * stretch,
		-right * 16.0 * squash + forward * 24.0 * stretch,
	])
	var nose := PackedVector2Array([
		right * 16.0 * squash + forward * 24.0 * stretch,
		right * 8.0 * squash + forward * 32.0 * stretch,
		-right * 8.0 * squash + forward * 32.0 * stretch,
	])

	var body_color := Color(0.25, 0.65, 1.0)
	if _crash_juice_time_left > 0.0:
		var flash := clampf(_crash_juice_intensity, 0.0, 1.0)
		body_color = body_color.lerp(Color(1.0, 0.35, 0.25), flash * 0.65)

	draw_colored_polygon(body, body_color)
	draw_colored_polygon(nose, body_color.darkened(0.15))
