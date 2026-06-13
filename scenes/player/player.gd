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

var _forward_speed: float = 0.0
var _steer_smoothed: float = 0.0
var _nitro_time_left: float = 0.0

func _ready() -> void:
	add_to_group(Constants.GROUP_PLAYER)
	GameState.card_played.connect(_on_card_played)
	queue_redraw()

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
	move_and_slide()

	# TODO (A): sudar / ostar zaokret kad bude test mape sa zidovima

func _process(delta: float) -> void:
	if _nitro_time_left > 0.0:
		_nitro_time_left = maxf(0.0, _nitro_time_left - delta)

func _get_throttle() -> float:
	return (
		Input.get_action_strength(Constants.INPUT_GAS)
		- Input.get_action_strength(Constants.INPUT_BRAKE)
	)

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
