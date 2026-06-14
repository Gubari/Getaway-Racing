extends Control
## Splash / loading ekran. Prikazuje Gubari logo + progress bar dok se glavni
## meni ucitava u pozadini, pa onda prelazi na njega.

const NEXT_SCENE := "res://scenes/main_menu/main_menu.tscn"
const LOGO_PATH := "res://assets/sprites/ui/logo_gubari.png"
## Minimalno vreme prikaza (s) da splash ne "bljesne" kod brzog ucitavanja.
const MIN_DISPLAY := 1.4

@onready var _logo: TextureRect = $Center/VBox/Logo
@onready var _bar: ProgressBar = $Center/VBox/Bar

var _elapsed: float = 0.0
var _progress: Array = []

func _ready() -> void:
	if ResourceLoader.exists(LOGO_PATH):
		_logo.texture = load(LOGO_PATH)
	ResourceLoader.load_threaded_request(NEXT_SCENE)

func _process(delta: float) -> void:
	_elapsed += delta
	var status := ResourceLoader.load_threaded_get_status(NEXT_SCENE, _progress)
	# Bar prati i stvarno ucitavanje i minimalno vreme prikaza (sporije od dvoje).
	var load_ratio: float = _progress[0] if not _progress.is_empty() else 0.0
	var time_ratio: float = clampf(_elapsed / MIN_DISPLAY, 0.0, 1.0)
	_bar.value = minf(load_ratio, time_ratio) * 100.0

	if status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("Loading failed: %s" % NEXT_SCENE)
		set_process(false)
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= MIN_DISPLAY:
		var packed: PackedScene = ResourceLoader.load_threaded_get(NEXT_SCENE)
		set_process(false)
		get_tree().change_scene_to_packed(packed)
