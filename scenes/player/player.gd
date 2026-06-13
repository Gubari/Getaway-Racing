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
@export var crash_loot_penalty: float = 15.0   ## % od starting_loot (15 = 15k pri 100k)
@export var crash_knockback_min: float = 16.0
@export var crash_knockback_impact_scale: float = 0.035
@export var crash_steer_lock_sec: float = 0.3
@export var crash_shake_strength: float = 14.0
@export var crash_shake_duration: float = 0.24
@export var crash_zoom_punch: float = 0.07
@export var crash_wobble_max_deg: float = 10.0
@export var crash_squash_amount: float = 0.18

@export_group("Sprite")
@export var car_anim_fps: float = 14.0
@export var car_anim_frames: int = 6

@export_group("Sharp Turn")
@export var sharp_turn_loot_penalty: float = 1.5   ## % od starting_loot
@export var sharp_turn_cooldown: float = 0.35
@export var sharp_turn_min_speed: float = 110.0
@export var sharp_turn_angular_speed_deg: float = 210.0
@export var sharp_turn_steer_threshold: float = 0.4

var _drive := TopDownCarDriving.new()
var _nitro_time_left: float = 0.0
var _sharp_turn_cooldown_left: float = 0.0
var _prev_rotation: float = 0.0
var _shake_time_left: float = 0.0
var _shake_normal: Vector2 = Vector2.ZERO
var _crash_juice_time_left: float = 0.0
var _crash_juice_intensity: float = 0.0
var _crash_wobble: float = 0.0
var _camera_base_zoom: Vector2 = Vector2.ONE
var _car_anim_accum: float = 0.0

@onready var _camera: Camera2D = $Camera2D
@onready var _car_sprite: Sprite2D = $CarSprite

func _ready() -> void:
	add_to_group(Constants.GROUP_PLAYER)
	GameState.card_played.connect(_on_card_played)
	_prev_rotation = rotation
	_camera_base_zoom = _camera.zoom
	_camera.make_current()
	_sync_drive_params()
	_update_car_sprite()

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

func setup_camera_limits(arena: Rect2) -> void:
	_camera.limit_left = int(arena.position.x)
	_camera.limit_top = int(arena.position.y)
	_camera.limit_right = int(arena.position.x + arena.size.x)
	_camera.limit_bottom = int(arena.position.y + arena.size.y)
	_camera.limit_smoothed = true

func _physics_process(delta: float) -> void:
	if not GameState.is_running:
		_drive.stop()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var throttle := _get_throttle()
	var steer_input := _get_steer_input()
	var speed_cap := max_speed
	if _nitro_time_left > 0.0:
		speed_cap = max_speed * nitro_multiplier

	var pre_move_velocity := _drive.physics_step(self, delta, throttle, steer_input, speed_cap)
	var crash := _drive.move_and_handle_walls(self, pre_move_velocity, crash_loot_penalty)
	if crash.get("crashed", false):
		_apply_wall_crash_juice(crash.impact_speed, crash.normal)

	_detect_sharp_turn(delta)
	_prev_rotation = rotation

func _process(delta: float) -> void:
	if _nitro_time_left > 0.0:
		_nitro_time_left = maxf(0.0, _nitro_time_left - delta)
	if _sharp_turn_cooldown_left > 0.0:
		_sharp_turn_cooldown_left = maxf(0.0, _sharp_turn_cooldown_left - delta)
	if _crash_juice_time_left > 0.0:
		_crash_juice_time_left = maxf(0.0, _crash_juice_time_left - delta)
	_update_car_sprite(delta)
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
	if throttle > 0.0 and _drive.is_gas_stunned():
		return 0.0
	return throttle

func _get_steer_input() -> float:
	return (
		Input.get_action_strength(Constants.INPUT_STEER_RIGHT)
		- Input.get_action_strength(Constants.INPUT_STEER_LEFT)
	)

func _on_card_played(card_type: int) -> void:
	if card_type == Card.Type.NITRO:
		_nitro_time_left = nitro_duration
		_drive.forward_speed = minf(
			_drive.forward_speed + nitro_impulse,
			max_speed * nitro_multiplier
		)
		GameState.nitro_used.emit()

func get_rear_spawn_point() -> Vector2:
	return global_position - Vector2.from_angle(rotation) * 48.0

func _apply_wall_crash_juice(impact_speed: float, normal: Vector2) -> void:
	var intensity := clampf(impact_speed / max_speed, 0.35, 1.25)
	_shake_time_left = crash_shake_duration
	_shake_normal = normal
	_crash_juice_time_left = crash_shake_duration
	_crash_juice_intensity = intensity
	_crash_wobble = deg_to_rad(crash_wobble_max_deg) * intensity * (1.0 if randf() > 0.5 else -1.0)
	_update_car_sprite()

func _detect_sharp_turn(delta: float) -> void:
	if _sharp_turn_cooldown_left > 0.0:
		return
	if absf(_drive.get_forward_speed()) < sharp_turn_min_speed:
		return
	if absf(_drive.steer_smoothed) < sharp_turn_steer_threshold:
		return

	var angular_speed_deg := absf(
		rad_to_deg(wrapf(rotation - _prev_rotation, -PI, PI)) / delta
	)
	if angular_speed_deg < sharp_turn_angular_speed_deg:
		return

	GameState.sharp_turn.emit(sharp_turn_loot_penalty)
	_sharp_turn_cooldown_left = sharp_turn_cooldown

## Top-down sprite (nos = +X). Sprite je dete tela pa se rotira zajedno sa
## fizikom. Frejmovi (6) se vrte kao vozi-animacija dok se auto krece, a
## ovde dodajemo i crash "juice": blagi wobble + crveni flash.
## Gameplay (knockback, shake) ostaje u fizici, netaknut.
func _update_car_sprite(delta: float = 0.0) -> void:
	if _car_sprite == null:
		return

	if absf(_drive.get_forward_speed()) > 5.0:
		_car_anim_accum += delta * car_anim_fps
		_car_sprite.frame = int(_car_anim_accum) % car_anim_frames

	var wobble_angle := 0.0
	var flash := 0.0
	if _crash_juice_time_left > 0.0 and crash_shake_duration > 0.0:
		var t := _crash_juice_time_left / crash_shake_duration
		wobble_angle = _crash_wobble * t
		flash = clampf(_crash_juice_intensity, 0.0, 1.0) * t

	_car_sprite.rotation = wobble_angle
	_car_sprite.modulate = Color.WHITE.lerp(Color(1.0, 0.45, 0.4), flash * 0.7)
