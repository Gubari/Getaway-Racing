extends RefCounted
class_name AudioSettings
## Deljeni SFX/Music slideri za pause i main menu. Vlasnik: D.

const SETTINGS_PATH := "user://settings.cfg"

static func load_values() -> Vector2:
	var cfg := ConfigFile.new()
	var sfx := 0.8
	var music := 0.7
	if cfg.load(SETTINGS_PATH) == OK:
		sfx = cfg.get_value("audio", "sfx", sfx)
		music = cfg.get_value("audio", "music", music)
	return Vector2(sfx, music)

static func save_values(sfx: float, music: float) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("audio", "music", music)
	cfg.save(SETTINGS_PATH)

static func apply_bus(bus_name: StringName, value: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	if value <= 0.001:
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(value))

static func apply(sfx: float, music: float) -> void:
	apply_bus(&"SFX", sfx)
	apply_bus(&"Music", music)

static func bind_sliders(sfx_slider: HSlider, music_slider: HSlider) -> void:
	var values := load_values()
	sfx_slider.set_value_no_signal(values.x)
	music_slider.set_value_no_signal(values.y)
	apply(values.x, values.y)
	sfx_slider.value_changed.connect(func(v: float) -> void:
		apply(v, music_slider.value)
		save_values(v, music_slider.value)
	)
	music_slider.value_changed.connect(func(v: float) -> void:
		apply(sfx_slider.value, v)
		save_values(sfx_slider.value, v)
	)
