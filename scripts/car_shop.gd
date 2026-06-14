extends Node
## Car upgrades: speed, crash durability, faster heat drop-off. Owner: D.

signal upgrades_changed

const SAVE_PATH := "user://progress.cfg"
const MAX_LEVEL := 3

const SPEED_BONUS_PER_LEVEL := 0.05
const CRASH_REDUCTION_PER_LEVEL := 0.15
const PURSUIT_TIME_REDUCTION_PER_LEVEL := 0.12

const UPGRADES: Array[Dictionary] = [
	{
		"id": &"speed",
		"name": "Engine Tune",
		"description": "Increases top speed by 5% per level.",
		"prices": [4000, 6000, 9000],
	},
	{
		"id": &"durability",
		"name": "Durability",
		"description": "Reduces money lost on wall crashes by 15% per level.",
		"prices": [3500, 5500, 8000],
	},
	{
		"id": &"heat_decay",
		"name": "Low Profile",
		"description": "Cops lose sight and stop searching sooner. 12% shorter pursuit timers per level.",
		"prices": [4500, 6500, 9500],
	},
]

var _levels: Dictionary = {}

func _ready() -> void:
	_load()

func get_level(upgrade_id: StringName) -> int:
	return int(_levels.get(upgrade_id, 0))

func is_maxed(upgrade_id: StringName) -> bool:
	return get_level(upgrade_id) >= MAX_LEVEL

func get_price(upgrade_id: StringName) -> int:
	var lvl := get_level(upgrade_id)
	if lvl >= MAX_LEVEL:
		return 0
	for entry in UPGRADES:
		if entry.id == upgrade_id:
			var prices: Array = entry.prices
			return int(prices[lvl])
	return 0

func try_purchase(upgrade_id: StringName) -> bool:
	if is_maxed(upgrade_id):
		return false
	var price := get_price(upgrade_id)
	if price <= 0 or not ItemShop.try_spend(price):
		return false
	_levels[upgrade_id] = get_level(upgrade_id) + 1
	_save()
	upgrades_changed.emit()
	return true

func get_shop_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in UPGRADES:
		var id: StringName = entry.id
		var lvl := get_level(id)
		entries.append({
			"id": id,
			"name": entry.name,
			"description": entry.description,
			"level": lvl,
			"max_level": MAX_LEVEL,
			"price": get_price(id),
			"maxed": lvl >= MAX_LEVEL,
		})
	return entries

func apply_speed(base_speed: float) -> float:
	return base_speed * (1.0 + SPEED_BONUS_PER_LEVEL * get_level(&"speed"))

func apply_crash_penalty(base_penalty: float) -> float:
	var lvl := get_level(&"durability")
	return base_penalty * maxf(0.25, 1.0 - CRASH_REDUCTION_PER_LEVEL * lvl)

func get_pursuit_time_multiplier() -> float:
	var lvl := get_level(&"heat_decay")
	return maxf(0.4, 1.0 - PURSUIT_TIME_REDUCTION_PER_LEVEL * lvl)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var saved: Variant = cfg.get_value("car", "levels", {})
	if saved is Dictionary:
		for key in saved.keys():
			_levels[StringName(str(key))] = int(saved[key])

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var saved := {}
	for key in _levels.keys():
		saved[str(key)] = _levels[key]
	cfg.set_value("car", "levels", saved)
	cfg.save(SAVE_PATH)
