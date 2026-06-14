class_name TopDownCarDriving
extends RefCounted
## Deljena top-down fizika vozila (player + policija).

var acceleration: float = 480.0
var max_speed: float = 420.0
var reverse_max_speed: float = 160.0
var drag: float = 3.2
var brake_force: float = 1100.0
var steer_speed: float = 3.1
var steering_smoothing: float = 12.0
var min_speed_to_steer: float = 35.0
var high_speed_accel_factor: float = 0.45

var wall_penalty_rearm_sec: float = 0.75
var crash_min_impact_speed: float = 70.0
var crash_stun_sec: float = 0.3
var crash_knockback_min: float = 16.0
var crash_knockback_impact_scale: float = 0.035
var crash_steer_lock_sec: float = 0.3

var forward_speed: float = 0.0
var steer_smoothed: float = 0.0

var _crash_stun_until_ms: int = 0
var _crash_steer_lock_until_ms: int = 0
var _wall_penalty_rearm_until_ms: Dictionary = {}


func stop() -> void:
	forward_speed = 0.0
	steer_smoothed = 0.0


func is_gas_stunned(now_ms: int = Time.get_ticks_msec()) -> bool:
	return now_ms < _crash_stun_until_ms


func is_steer_locked(now_ms: int = Time.get_ticks_msec()) -> bool:
	return now_ms < _crash_steer_lock_until_ms


func physics_step(
	body: CharacterBody2D,
	delta: float,
	throttle: float,
	steer_input: float,
	speed_cap: float = -1.0,
) -> Vector2:
	var cap := max_speed if speed_cap < 0.0 else speed_cap
	var now_ms := Time.get_ticks_msec()

	if throttle > 0.0 and is_gas_stunned(now_ms):
		throttle = 0.0

	if is_steer_locked(now_ms):
		steer_input = 0.0
		steer_smoothed = 0.0
	else:
		steer_smoothed = lerpf(steer_smoothed, steer_input, steering_smoothing * delta)

	_update_forward_speed(throttle, delta, cap)
	if not is_steer_locked(now_ms):
		_apply_steering(body, delta, cap)

	body.velocity = Vector2.from_angle(body.rotation) * forward_speed
	return body.velocity


func move_and_handle_walls(
	body: CharacterBody2D,
	pre_move_velocity: Vector2,
	loot_penalty: float = 0.0,
) -> Dictionary:
	body.move_and_slide()
	return _detect_wall_crash(body, pre_move_velocity, loot_penalty)


func _update_forward_speed(throttle: float, delta: float, cap: float) -> void:
	if throttle > 0.0:
		var speed_ratio := clampf(absf(forward_speed) / cap, 0.0, 1.0)
		var accel_mult := lerpf(1.0, high_speed_accel_factor, speed_ratio)
		forward_speed += throttle * acceleration * accel_mult * delta
	elif throttle < 0.0:
		if forward_speed > 0.0:
			forward_speed -= brake_force * absf(throttle) * delta
		else:
			forward_speed += throttle * acceleration * 0.55 * delta
	else:
		var decay := drag * maxf(absf(forward_speed), 60.0) * delta
		forward_speed = move_toward(forward_speed, 0.0, decay)

	forward_speed = clampf(forward_speed, -reverse_max_speed, cap)


func _apply_steering(body: CharacterBody2D, delta: float, cap: float) -> void:
	if absf(forward_speed) < min_speed_to_steer:
		return

	var speed_factor := clampf(absf(forward_speed) / cap, 0.25, 1.0)
	var direction_sign := 1.0 if forward_speed >= 0.0 else -1.0
	body.rotation += steer_smoothed * steer_speed * speed_factor * direction_sign * delta


func _is_wall_collider(collider: Object) -> bool:
	if collider is StaticBody2D or collider is TileMapLayer:
		return collider.is_in_group(Constants.GROUP_WALLS)
	return false


func _detect_wall_crash(
	body: CharacterBody2D,
	pre_move_velocity: Vector2,
	loot_penalty: float,
) -> Dictionary:
	var now_ms := Time.get_ticks_msec()

	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		var collider := collision.get_collider()
		if not _is_wall_collider(collider):
			continue

		var wall_id: int = collider.get_instance_id()
		if now_ms < int(_wall_penalty_rearm_until_ms.get(wall_id, 0)):
			continue

		var impact_speed := -pre_move_velocity.dot(collision.get_normal())
		if impact_speed < crash_min_impact_speed:
			continue

		_wall_penalty_rearm_until_ms[wall_id] = now_ms + int(wall_penalty_rearm_sec * 1000.0)
		if loot_penalty > 0.0:
			GameState.crash_detected.emit(loot_penalty)
		var normal := collision.get_normal()
		_apply_wall_crash(body, collision, impact_speed)
		return {"crashed": true, "impact_speed": impact_speed, "normal": normal}

	return {"crashed": false}


func _apply_wall_crash(
	body: CharacterBody2D,
	collision: KinematicCollision2D,
	impact_speed: float,
) -> void:
	var normal := collision.get_normal()
	var now_ms := Time.get_ticks_msec()

	_crash_stun_until_ms = now_ms + int(crash_stun_sec * 1000.0)
	_crash_steer_lock_until_ms = now_ms + int(crash_steer_lock_sec * 1000.0)
	steer_smoothed = 0.0

	var knockback := crash_knockback_min + impact_speed * crash_knockback_impact_scale
	body.global_position += normal * knockback
	forward_speed = 0.0
	body.velocity = Vector2.ZERO


func get_forward_speed() -> float:
	return forward_speed
