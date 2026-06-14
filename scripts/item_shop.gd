extends Node
## Meta shop: money, unlocked abilities, heist loadout. Owner: D.

signal cash_changed(amount: int)
signal unlocks_changed

const SAVE_PATH := "user://progress.cfg"
const STARTING_CASH := 15000

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

func _ready() -> void:
	_load()
	for item in SHOP_ITEMS:
		if item.get("default_unlocked", false):
			_unlocked[item.id] = true

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
	_save()
	unlocks_changed.emit()
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

func get_loadout() -> Array[Card]:
	var result: Array[Card] = []
	for item in SHOP_ITEMS:
		if is_unlocked(item.id):
			result.append(load(item.resource) as Card)
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

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	cash = int(cfg.get_value("shop", "cash", cfg.get_value("shop", "scrap", STARTING_CASH)))
	var saved: Variant = cfg.get_value("shop", "unlocked", {})
	if saved is Dictionary:
		for key in saved.keys():
			_unlocked[StringName(str(key))] = bool(saved[key])

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("shop", "cash", cash)
	var saved := {}
	for key in _unlocked.keys():
		saved[str(key)] = _unlocked[key]
	cfg.set_value("shop", "unlocked", saved)
	cfg.save(SAVE_PATH)
