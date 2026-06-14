extends Node
## Win cinematic: kamera zumira na garazu, vrata se otvaraju, auto uvozi unutra,
## vrata se zatvaraju -> pobeda. Pokrece je garaza (kad NIKO ne juri). Vlasnik: B.
## Koristi ZASEBNU cinematic kameru (bez limita/pracenja) za garantovan kadar.

@export var zoom_target: Vector2 = Vector2(2.4, 2.4)
@export var zoom_time: float = 0.8
@export var door_open_time: float = 0.8
@export var drive_in_time: float = 1.8   # sporiji, deliberatan ulazak
@export var turn_time: float = 0.7       # koliko traje okret nosa ka vratima (vece = prirodniji luk)
@export var door_close_time: float = 0.8

var _played := false

func _ready() -> void:
	add_to_group("win_cinematic")

## Pozove je garaza. Pokrece sekvencu (samo jednom).
func play_win() -> void:
	if _played:
		return
	_played = true
	_run()

func _run() -> void:
	var player := get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
	var door := get_tree().current_scene.find_child("GarageDoor", true, false) as AnimatedSprite2D

	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud != null and hud.has_method("hide_ability_bar"):
		hud.hide_ability_bar()

	# 1) zamrzni igraca + policiju
	var start_zoom := Vector2.ONE
	if player != null:
		var pc := player.get_node_or_null("Camera2D") as Camera2D
		if pc != null:
			start_zoom = pc.zoom
		player.set_physics_process(false)
		player.set_process(false)
	for cop in get_tree().get_nodes_in_group(Constants.GROUP_POLICE):
		cop.set_physics_process(false)

	# 2) focus = sredina izmedju auta i vrata
	var focus: Vector2 = player.global_position if player != null else Vector2.ZERO
	if player != null and door != null:
		focus = (player.global_position + door.global_position) * 0.5

	# 3) ZASEBNA cinematic kamera, postavljena tacno na garazu (bez limita/pracenja)
	var cam := Camera2D.new()
	get_tree().current_scene.add_child(cam)
	cam.global_position = focus
	cam.zoom = start_zoom
	cam.make_current()
	var tw := create_tween()
	tw.tween_property(cam, "zoom", zoom_target, zoom_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

	# 4) vrata se otvaraju
	if door != null and door.sprite_frames != null:
		door.sprite_frames.set_animation_loop(&"default", false)
		door.frame = 0
		door.play(&"default")
	await get_tree().create_timer(door_open_time).timeout

	# 5) auto se OKRENE ka vratima (nos napred, najkraci put) pa uvozi unutra + fade
	if player != null and door != null:
		var to_door: Vector2 = door.global_position - player.global_position
		var face: float = player.rotation + wrapf(to_door.angle() - player.rotation, -PI, PI)
		var tw2 := create_tween().set_parallel(true)
		tw2.tween_property(player, "rotation", face, turn_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw2.tween_property(player, "global_position", door.global_position, drive_in_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw2.tween_property(player, "modulate:a", 0.0, drive_in_time)
		await tw2.finished

	# 6) vrata se zatvaraju
	if door != null and door.sprite_frames != null:
		door.play_backwards(&"default")
	await get_tree().create_timer(door_close_time).timeout

	# 7) pobeda
	GameState.reach_base()
