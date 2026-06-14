extends Node
## Meta shop: money, unlocked abilities, heist loadout. Owner: D.

signal cash_changed(amount: int)
signal unlocks_changed
signal equipped_changed

const SAVE_PATH := "user://progress.cfg"
const STARTING_CASH := 15000
const MAX_EQUIPPED := 3
const DEFAULT_EQUIPPED: Array[StringName] = [&"oil", &"nitro", &"barricade"]

const SHOP_ITEMS: Array[Dictionary] = [
	{
		"id": &"oil",
		"resource": "res://resources/cards/ulje.tres",
		"price": 0,
		"default_unlocked": true,
	},
	{
		"id": &"nitro",
		"resource": "res://resources/cards/nitro.tres",
		"price": 0,
		"default_unlocked": true,
	},
	{
		"id": &"barricade",
		"resource": "res://resources/cards/barikada.tres",
		"price": 0,
		"default_unlocked": true,
	},
	{
		"id": &"spikes",
		"resource": "res://resources/cards/spikes.tres",
		"price": 5000,
		"default_unlocked": false,
	},
	{
		"id": &"wild_card",
		"resource": "res://resources/cards/wild_card.tres",
		"price": 8000,
		"default_unlocked": false,
	},
]

const WILD_POOL: Array[int] = [
	Card.Type.OIL,
	Card.Type.BARRICADE,
	Card.Type.NITRO,
	Card.Type.SPIKES,
]

var cash: int = STARTING_CASH
var _unlocked: Dictionary = {}
var _equipped: Array[StringName] = []

func _ready() -> void:
	_load()
	for item in SHOP_ITEMS:
		if item.get("default_unlocked", false):
			_unlocked[item.id] = true
	_ensure_default_equipped()

func is_unlocked(item_id: StringName) -> bool:
	return _unlocked.get(item_id, false)

func can_afford(price: int) -> bool:
	return cash >= price

func try_purchase(item_id: StringName) -> bool:
	if is_unlocked(item_id):
		return false
	var price := _price_for(item_id)
	if price <= 0 or not try_spend(price):
		return false
	_unlocked[item_id] = true
	if _equipped.size() < MAX_EQUIPPED and not is_equipped(item_id):
		_equipped.append(item_id)
	_save()
	unlocks_changed.emit()
	equipped_changed.emit()
	return true

func try_spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	cash -= amount
	_save()
	cash_changed.emit(cash)
	return true

func add_earnings(amount: int) -> void:
	if amount <= 0:
		return
	cash += amount
	_save()
	cash_changed.emit(cash)

func is_equipped(item_id: StringName) -> bool:
	return item_id in _equipped

func equipped_count() -> int:
	_prune_equipped()
	return _equipped.size()

func can_equip_more() -> bool:
	return equipped_count() < MAX_EQUIPPED

func try_toggle_equip(item_id: StringName) -> bool:
	if not is_unlocked(item_id):
		return false
	_prune_equipped()
	if is_equipped(item_id):
		_equipped.erase(item_id)
		_save()
		equipped_changed.emit()
		return true
	if _equipped.size() >= MAX_EQUIPPED:
		return false
	_equipped.append(item_id)
	_save()
	equipped_changed.emit()
	return true

func get_loadout() -> Array[Card]:
	_prune_equipped()
	var result: Array[Card] = []
	for item_id in _equipped:
		if result.size() >= MAX_EQUIPPED:
			break
		if not is_unlocked(item_id):
			continue
		var card := _card_for_id(item_id)
		if card != null:
			result.append(card)
	return result

func get_card_by_type(card_type: int) -> Card:
	for item in SHOP_ITEMS:
		var card := load(item.resource) as Card
		if card != null and card.type == card_type:
			return card
	return null

func get_wild_pool() -> Array[int]:
	var pool: Array[int] = []
	for card_type in WILD_POOL:
		var card := get_card_by_type(card_type)
		if card != null and _is_type_unlocked(card_type):
			pool.append(card_type)
	return pool

func get_shop_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for item in SHOP_ITEMS:
		var card := load(item.resource) as Card
		entries.append({
			"id": item.id,
			"card": card,
			"price": int(item.get("price", 0)),
			"owned": is_unlocked(item.id),
			"equipped": is_equipped(item.id),
		})
	return entries

func _is_type_unlocked(card_type: int) -> bool:
	for item in SHOP_ITEMS:
		var card := load(item.resource) as Card
		if card != null and card.type == card_type:
			return is_unlocked(item.id)
	return false

func _price_for(item_id: StringName) -> int:
	for item in SHOP_ITEMS:
		if item.id == item_id:
			return int(item.get("price", 0))
	return 0

func _card_for_id(item_id: StringName) -> Card:
	for item in SHOP_ITEMS:
		if item.id == item_id:
			return load(item.resource) as Card
	return null

func _ensure_default_equipped() -> void:
	_prune_equipped()
	if not _equipped.is_empty():
		return
	for item_id in DEFAULT_EQUIPPED:
		if is_unlocked(item_id) and _equipped.size() < MAX_EQUIPPED:
			_equipped.append(item_id)
	if not _equipped.is_empty():
		_save()

func _prune_equipped() -> void:
	var kept: Array[StringName] = []
	for item_id in _equipped:
		if kept.size() >= MAX_EQUIPPED:
			break
		if is_unlocked(item_id) and item_id not in kept:
			kept.append(item_id)
	_equipped = kept

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	cash = int(cfg.get_value("shop", "cash", cfg.get_value("shop", "scrap", STARTING_CASH)))
	var saved: Variant = cfg.get_value("shop", "unlocked", {})
	if saved is Dictionary:
		for key in saved.keys():
			_unlocked[StringName(str(key))] = bool(saved[key])
	var equipped: Variant = cfg.get_value("shop", "equipped", [])
	if equipped is Array:
		_equipped.clear()
		for entry in equipped:
			_equipped.append(StringName(str(entry)))

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("shop", "cash", cash)
	var saved := {}
	for key in _unlocked.keys():
		saved[str(key)] = _unlocked[key]
	cfg.set_value("shop", "unlocked", saved)
	var equipped: Array = []
	for item_id in _equipped:
		equipped.append(str(item_id))
	cfg.set_value("shop", "equipped", equipped)
	cfg.save(SAVE_PATH)
