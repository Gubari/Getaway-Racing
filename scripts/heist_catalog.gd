extends Node
## Cita HeistProfile podatke iz city.tscn za meni (jedan izvor istine sa editorom).
## Vlasnik: D.

const CITY_SCENE := preload("res://scenes/levels/city.tscn")

var _profiles: Dictionary = {}

func _ready() -> void:
	_reload_profiles()

func _reload_profiles() -> void:
	_profiles.clear()
	var city: Node2D = CITY_SCENE.instantiate()
	var profiles_root := city.get_node_or_null("HeistProfiles")
	if profiles_root != null:
		for child in profiles_root.get_children():
			if child is HeistProfile:
				var profile := child as HeistProfile
				if profile.heist_id.is_empty():
					continue
				_profiles[profile.heist_id] = _snapshot(profile)
	city.free()

func get_profile(heist_id: String) -> Dictionary:
	return _profiles.get(heist_id, {})

func has_profile(heist_id: String) -> bool:
	return _profiles.has(heist_id)

func get_display_name(heist_id: String) -> String:
	var profile := get_profile(heist_id)
	if profile.is_empty():
		return heist_id
	return profile.get("label", heist_id)

func format_details(heist_id: String, status: String = "") -> String:
	var profile := get_profile(heist_id)
	if profile.is_empty():
		return "Heist data missing for '%s'." % heist_id
	var status_text := status if not status.is_empty() else "Ready"
	return "%s | %s | Loot: %s | Max patrol: %d" % [
		profile.get("label", heist_id),
		status_text,
		GameState.format_loot(float(profile.get("starting_loot", 0.0))),
		int(profile.get("max_police", 0)),
	]

func _snapshot(profile: HeistProfile) -> Dictionary:
	var label := profile.display_name
	if label.is_empty():
		label = profile.heist_id
	return {
		"id": profile.heist_id,
		"label": label,
		"starting_loot": profile.starting_loot,
		"max_police": profile.max_police,
		"heat_tiers": profile.get_heat_tier_maxes(),
		"first_spawn_delay": profile.first_spawn_delay,
		"spawn_interval": profile.spawn_interval,
	}
