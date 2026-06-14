extends Node
## Otkljucavanje pljacki redom. Cuva se u user://progress.cfg. Vlasnik: D.

signal heists_changed

const SAVE_PATH := "user://progress.cfg"

## Red otkljucavanja — mora da se poklapa sa redosledom u main_menu.gd.
const HEIST_ORDER: Array[String] = ["downtown", "port", "industrial"]

var _unlocked: Dictionary = {}
var _completed: Dictionary = {}

func _ready() -> void:
	_load()
	_ensure_first_unlocked()
	GameState.game_won.connect(_on_heist_won)

func is_unlocked(heist_id: String) -> bool:
	return _unlocked.get(heist_id, false)

func is_completed(heist_id: String) -> bool:
	return _completed.get(heist_id, false)

func get_prerequisite_id(heist_id: String) -> String:
	var idx := HEIST_ORDER.find(heist_id)
	if idx <= 0:
		return ""
	return HEIST_ORDER[idx - 1]

func _on_heist_won() -> void:
	var heist_id := GameState.selected_heist_id
	if heist_id.is_empty() or not is_unlocked(heist_id):
		return
	if _completed.get(heist_id, false):
		return
	_completed[heist_id] = true
	var idx := HEIST_ORDER.find(heist_id)
	if idx >= 0 and idx + 1 < HEIST_ORDER.size():
		_unlocked[HEIST_ORDER[idx + 1]] = true
	_save()
	heists_changed.emit()

func _ensure_first_unlocked() -> void:
	if HEIST_ORDER.is_empty():
		return
	if _unlocked.is_empty() and _completed.is_empty():
		_unlocked[HEIST_ORDER[0]] = true
		_save()
	elif not _unlocked.get(HEIST_ORDER[0], false):
		_unlocked[HEIST_ORDER[0]] = true
		_save()

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var unlocked: Variant = cfg.get_value("heists", "unlocked", {})
	if unlocked is Dictionary:
		for key in unlocked.keys():
			_unlocked[str(key)] = bool(unlocked[key])
	var completed: Variant = cfg.get_value("heists", "completed", {})
	if completed is Dictionary:
		for key in completed.keys():
			_completed[str(key)] = bool(completed[key])

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var unlocked := {}
	for key in _unlocked.keys():
		unlocked[key] = _unlocked[key]
	var completed := {}
	for key in _completed.keys():
		completed[key] = _completed[key]
	cfg.set_value("heists", "unlocked", unlocked)
	cfg.set_value("heists", "completed", completed)
	cfg.save(SAVE_PATH)
