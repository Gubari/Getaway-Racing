extends CharacterBody2D
## VOZILO IGRACA: top-down fizika, kolizije, plen-curi logika.
## Vlasnik: A.

@export var acceleration: float = 600.0
@export var max_speed: float = 500.0
@export var reverse_max_speed: float = 200.0
@export var drag: float = 2.5
@export var brake_force: float = 900.0
@export var steer_speed: float = 2.8
@export var steering_smoothing: float = 10.0
@export var min_speed_to_steer: float = 40.0
@export var nitro_multiplier: float = 1.8
@export var nitro_duration: float = 0.75
@export var nitro_impulse: float = 280.0
@export var wall_penalty_rearm_sec: float = 0.75
@export var crash_min_impact_speed: float = 80.0
@export var crash_stun_sec: float = 0.25
@export var crash_knockback_distance: float = 12.0
@export var crash_loot_penalty: float = 15.0
@export var sharp_turn_loot_penalty: float = 1.5
@export var crash_shake_strength: float = 6.0
@export var crash_shake_duration: float = 0.15
@export var sharp_turn_cooldown: float = 0.35
@export var sharp_turn_min_speed: float = 120.0
@export var sharp_turn_angular_speed_deg: float = 220.0
@export var sharp_turn_steer_threshold: float = 0.4

var _forward_speed: float = 0.0
var _steer_smoothed: float = 0.0
var _nitro_time_left: float = 0.0
var _sharp_turn_cooldown_left: float = 0.0
var _prev_rotation: float = 0.0
var _crash_stun_until_ms: int = 0
var _wall_penalty_rearm_until_ms: Dictionary = {}
var _shake_time_left: float = 0.0

@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	add_to_group(Constants.GROUP_PLAYER)
	GameState.card_played.connect(_on_card_played)
	_prev_rotation = rotation
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
	_steer_smoothed = lerpf(_steer_smoothed, steer_input, steering_smoothing * delta)

	_update_forward_speed(throttle, delta)
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
	_update_camera_shake(delta)

func _update_camera_shake(delta: float) -> void:
	if _shake_time_left <= 0.0:
		_camera.offset = Vector2.ZERO
		return
	_shake_time_left = maxf(0.0, _shake_time_left - delta)
	var t := _shake_time_left / crash_shake_duration if crash_shake_duration > 0.0 else 0.0
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * crash_shake_strength * t

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
		_forward_speed += throttle * acceleration * delta
	elif throttle < 0.0:
		if _forward_speed > 0.0:
			_forward_speed -= brake_force * absf(throttle) * delta
		else:
			_forward_speed += throttle * acceleration * 0.6 * delta
	else:
		var decay := drag * maxf(absf(_forward_speed), 80.0) * delta
		_forward_speed = move_toward(_forward_speed, 0.0, decay)

	var cap := max_speed
	if _nitro_time_left > 0.0:
		cap = max_speed * nitro_multiplier
	_forward_speed = clampf(_forward_speed, -reverse_max_speed, cap)

func _apply_steering(delta: float) -> void:
	if absf(_forward_speed) < min_speed_to_steer:
		return

	var speed_factor := clampf(absf(_forward_speed) / max_speed, 0.2, 1.0)
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

		# Brzina PRE move_and_slide() — posle slide-a Godot ukloni komponentu u zid (≈0).
		var impact_speed := -pre_move_velocity.dot(collision.get_normal())
		if impact_speed < crash_min_impact_speed:
			continue

		_wall_penalty_rearm_until_ms[wall_id] = now_ms + int(wall_penalty_rearm_sec * 1000.0)
		GameState.crash_detected.emit(crash_loot_penalty)
		_apply_wall_crash(collision)

func _apply_wall_crash(collision: KinematicCollision2D) -> void:
	var normal := collision.get_normal()
	_crash_stun_until_ms = Time.get_ticks_msec() + int(crash_stun_sec * 1000.0)
	_shake_time_left = crash_shake_duration
	_forward_speed = 0.0
	global_position += normal * crash_knockback_distance
	velocity = Vector2.from_angle(rotation) * _forward_speed

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
	# Placeholder dok C ne doda sprite.
	draw_colored_polygon(
		PackedVector2Array([Vector2(-16, -24), Vector2(16, -24), Vector2(16, 24), Vector2(-16, 24)]),
		Color(0.25, 0.65, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([Vector2(16, -8), Vector2(24, 0), Vector2(16, 8)]),
		Color(0.15, 0.45, 0.85)
	)
