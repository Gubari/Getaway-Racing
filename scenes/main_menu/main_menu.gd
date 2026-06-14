extends CanvasLayer
## Glavni meni na startu igre. Skelet za meta ekrane (mapa, shopovi, settings).
## Vlasnik: D.

enum Screen { MAIN, HEIST_MAP, CAR_SHOP, ITEM_SHOP, SETTINGS }

const _AudioSettings := preload("res://scripts/audio_settings.gd")

const HEIST_SCENE := "res://scenes/main/main.tscn"
## Gradska scena se reciklira kao dekorativna pozadina menija (bez gameplay-a).
const CITY_SCENE := preload("res://scenes/levels/city.tscn")
## Granke iz city.tscn koje su cisto gameplay i ne smeju da se pokrenu u meniju.
const CITY_GAMEPLAY_BRANCHES: Array[String] = ["Spawns", "HeistProfiles"]
const ITEM_SHOP_HINT_DEFAULT := "Select an item for details."
const CAR_SHOP_HINT_DEFAULT := "Select an upgrade for details."
## Atlas sa UI ikonicama (Modern UI Style 2, 32x32 grid) za car shop upgrade-ove.
const UI_ICONS := preload("res://assets/sprites/ui/Modern_UI_Style_2_32x32.png")

## Redosled pljacki + fallback pozicija. Stvarne pozicije markera se citaju iz
## city.tscn (HeistProfiles/<id>/PlayerSpawn), pa ne moras rucno da ih odrzavas;
## Vector2 ispod se koristi samo ako marker ne postoji u nivou.
const HEIST_MAP_UI: Array[Dictionary] = [
	{"id": "downtown", "position": Vector2(1160, 997)},
	{"id": "port", "position": Vector2(2060, 2003)},
	{"id": "industrial", "position": Vector2(3591, 1370)},
]
## Pocetni zoom kamere na mapi pljacki + granice i korak zoom-a.
const HEIST_MAP_ZOOM := Vector2(0.45, 0.45)
const HEIST_MAP_ZOOM_MIN := 0.15  # maksimalno odzumirano (vidi se ceo grad)
const HEIST_MAP_ZOOM_MAX := 1.5   # maksimalno zumirano
const HEIST_MAP_ZOOM_STEP := 1.12 # mnozilac po jednom "tiku" scroll-a

@onready var _city_viewport: SubViewport = $Backdrop/CityViewport
@onready var _main_panel: Control = $MainPanel
@onready var _heist_map_panel: Control = $HeistMapPanel
@onready var _car_shop_panel: Control = $CarShopPanel
@onready var _item_shop_panel: Control = $ItemShopPanel
@onready var _settings_panel: Control = $SettingsPanel

@onready var _plan_btn: Button = $MainPanel/PlanHeistBtn
@onready var _car_shop_btn: Button = $MainPanel/CarShopBtn
@onready var _item_shop_btn: Button = $MainPanel/ItemShopBtn
@onready var _settings_btn: Button = $MainPanel/SettingsBtn

@onready var _heist_back_btn: Button = $HeistMapPanel/Frame/VBox/ButtonRow/BackBtn
@onready var _heist_start_btn: Button = $HeistMapPanel/Frame/VBox/ButtonRow/StartHeistBtn
@onready var _heist_hint: Label = $HeistMapPanel/Frame/VBox/HintLabel
@onready var _map_viewport: SubViewport = $HeistMapPanel/Frame/VBox/MapFrame/MapView/MapViewport
@onready var _map_camera: Camera2D = $HeistMapPanel/Frame/VBox/MapFrame/MapView/MapViewport/MapCamera
@onready var _marker_layer: Control = $HeistMapPanel/Frame/VBox/MapFrame/MarkerLayer

@onready var _car_back_btn: Button = $CarShopPanel/Frame/VBox/BackBtn
@onready var _car_cash_label: Label = $CarShopPanel/Frame/VBox/CashLabel
@onready var _car_hint: Label = $CarShopPanel/Frame/VBox/HintLabel
@onready var _car_row: HBoxContainer = $CarShopPanel/Frame/VBox/UpgradeRow
@onready var _item_back_btn: Button = $ItemShopPanel/Frame/VBox/BackBtn
@onready var _item_cash_label: Label = $ItemShopPanel/Frame/VBox/CashLabel
@onready var _item_subtitle: Label = $ItemShopPanel/Frame/VBox/SubtitleLabel
@onready var _item_hint: Label = $ItemShopPanel/Frame/VBox/HintLabel
@onready var _item_row: HBoxContainer = $ItemShopPanel/Frame/VBox/ItemRow
@onready var _settings_back_btn: Button = $SettingsPanel/Frame/VBox/BackBtn
@onready var _sfx_slider: HSlider = $SettingsPanel/Frame/VBox/SfxRow/SfxSlider
@onready var _music_slider: HSlider = $SettingsPanel/Frame/VBox/MusicRow/MusicSlider

var _screen: Screen = Screen.MAIN
var _marker_buttons: Array[Button] = []
var _selected_shop_item_id: StringName = &""
var _selected_car_upgrade_id: StringName = &""
var _map_bounds: Rect2 = Rect2()
var _map_dragging: bool = false
var _map_city_ready: bool = false
var _heist_positions: Dictionary = {} # id(String) -> Vector2 (svetska pozicija markera)
var _touch_points: Dictionary = {}
var _pinch_last_dist: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_city_backdrop()
	_build_heist_map_city()
	_marker_layer.gui_input.connect(_on_map_input)
	_plan_btn.pressed.connect(func(): _show_screen(Screen.HEIST_MAP))
	_car_shop_btn.pressed.connect(func(): _show_screen(Screen.CAR_SHOP))
	_item_shop_btn.pressed.connect(func(): _show_screen(Screen.ITEM_SHOP))
	_settings_btn.pressed.connect(func(): _show_screen(Screen.SETTINGS))
	_heist_back_btn.pressed.connect(func(): _show_screen(Screen.MAIN))
	_car_back_btn.pressed.connect(func(): _show_screen(Screen.MAIN))
	_item_back_btn.pressed.connect(func(): _show_screen(Screen.MAIN))
	_settings_back_btn.pressed.connect(func(): _show_screen(Screen.MAIN))
	_heist_start_btn.pressed.connect(_start_heist)
	_AudioSettings.bind_sliders(_sfx_slider, _music_slider)
	# Outline na hint tekstu da "iskace" kao tekst na karticama u shopovima.
	_heist_hint.add_theme_constant_override("outline_size", 5)
	_heist_hint.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1))
	_build_heist_markers()
	_refresh_heist_selection()
	_build_item_shop()
	_build_car_shop()
	ItemShop.cash_changed.connect(_on_shop_money_changed)
	ItemShop.unlocks_changed.connect(_refresh_item_shop)
	ItemShop.equipped_changed.connect(_refresh_item_shop)
	HeistProgress.heists_changed.connect(_refresh_heist_selection)
	CarShop.upgrades_changed.connect(_refresh_car_shop)
	_refresh_shop_money()
	_show_screen(Screen.MAIN)
	Audio.play_main_menu_music()

func _refresh_shop_money() -> void:
	_item_cash_label.text = "Money: %s" % GameState.format_loot(float(ItemShop.cash))
	_car_cash_label.text = "Money: %s" % GameState.format_loot(float(ItemShop.cash))

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _screen == Screen.MAIN:
		return
	_show_screen(Screen.MAIN)
	get_viewport().set_input_as_handled()

## Instancira grad bez gameplay-a. Skripta i gameplay granke se uklanjaju
## PRE ulaska u stablo, pa _ready playera/policije/garaze nikad ne okine.
func _instance_menu_city() -> Node:
	var city := CITY_SCENE.instantiate()
	city.set_script(null)
	for branch in CITY_GAMEPLAY_BRANCHES:
		var node := city.get_node_or_null(branch)
		if node != null:
			node.free()
	return city

func _build_city_backdrop() -> void:
	_city_viewport.add_child(_instance_menu_city())

## Mapa pljacki: pravi grad u SubViewport-u sa kamerom koju igrac moze da prevlaci.
func _build_heist_map_city() -> void:
	var city := CITY_SCENE.instantiate()
	city.set_script(null)
	_read_heist_positions_from(city) # procitaj PlayerSpawn pre nego sto skinemo gameplay
	for branch in CITY_GAMEPLAY_BRANCHES:
		var node := city.get_node_or_null(branch)
		if node != null:
			node.free()
	_map_viewport.add_child(city)
	_map_bounds = _compute_city_bounds(city)
	_map_camera.zoom = HEIST_MAP_ZOOM
	_map_camera.position = _map_bounds.get_center() if _map_bounds.size != Vector2.ZERO else _heist_world_pos(HEIST_MAP_UI[0]["id"])
	_map_city_ready = true
	_clamp_map_camera()

## Pozicije markera = PlayerSpawn svake pljacke iz city.tscn (auto-sync sa nivoom).
## Ako marker fali, koristi se fallback iz HEIST_MAP_UI.
func _read_heist_positions_from(city: Node) -> void:
	for data in HEIST_MAP_UI:
		_heist_positions[data["id"]] = data["position"]
	var profiles := city.get_node_or_null("HeistProfiles") as Node2D
	if profiles == null:
		return
	for data in HEIST_MAP_UI:
		var profile := profiles.get_node_or_null(String(data["id"])) as Node2D
		if profile == null:
			continue
		var spawn := profile.get_node_or_null("PlayerSpawn") as Node2D
		if spawn == null:
			continue
		_heist_positions[data["id"]] = profiles.position + profile.position + spawn.position

func _heist_world_pos(heist_id: String) -> Vector2:
	return _heist_positions.get(heist_id, Vector2.ZERO)

## Spaja used_rect svih TileMapLayer-a u svetske granice (za clamp kamere).
func _compute_city_bounds(city: Node) -> Rect2:
	var merged := Rect2()
	var has_any := false
	for child in city.get_children():
		if not (child is TileMapLayer):
			continue
		var layer := child as TileMapLayer
		if layer.tile_set == null:
			continue
		var used := layer.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var ts := Vector2(layer.tile_set.tile_size)
		var rect := Rect2(Vector2(used.position) * ts, Vector2(used.size) * ts)
		if not has_any:
			merged = rect
			has_any = true
		else:
			merged = merged.merge(rect)
	return merged

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_map_dragging = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_map_at(HEIST_MAP_ZOOM_STEP, event.position)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_map_at(1.0 / HEIST_MAP_ZOOM_STEP, event.position)
	elif event is InputEventMouseMotion and _map_dragging:
		_pan_map(event.relative)
	elif event is InputEventMagnifyGesture: # trackpad pinch (desktop)
		_zoom_map_at(event.factor, event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
		if _touch_points.size() < 2:
			_pinch_last_dist = 0.0
	elif event is InputEventScreenDrag:
		_touch_points[event.index] = event.position
		if _touch_points.size() >= 2:
			_handle_pinch()
		else:
			_pan_map(event.relative)

func _pan_map(relative: Vector2) -> void:
	_map_camera.position -= relative / _map_camera.zoom
	_clamp_map_camera()
	_update_marker_positions()

## Pinch zoom (mobilni): meri promenu rastojanja izmedju dva prsta.
func _handle_pinch() -> void:
	var keys := _touch_points.keys()
	var p0: Vector2 = _touch_points[keys[0]]
	var p1: Vector2 = _touch_points[keys[1]]
	var dist := p0.distance_to(p1)
	if _pinch_last_dist > 0.0 and dist > 0.0:
		_zoom_map_at(dist / _pinch_last_dist, (p0 + p1) * 0.5)
	_pinch_last_dist = dist

## Zumira ka tacki `local_pos` (u koordinatama map viewporta), pa svet pod
## kursorom/prstima ostaje na istom mestu na ekranu.
func _zoom_map_at(factor: float, local_pos: Vector2) -> void:
	var vp := Vector2(_map_viewport.size)
	var old_zoom := _map_camera.zoom.x
	var new_zoom := clampf(old_zoom * factor, HEIST_MAP_ZOOM_MIN, HEIST_MAP_ZOOM_MAX)
	if is_equal_approx(new_zoom, old_zoom):
		return
	var world_under := _map_camera.position + (local_pos - vp * 0.5) / old_zoom
	_map_camera.zoom = Vector2(new_zoom, new_zoom)
	_map_camera.position = world_under - (local_pos - vp * 0.5) / new_zoom
	_clamp_map_camera()
	_update_marker_positions()

## Drzi kameru unutar granica mape (ili centrira ako je mapa manja od viewporta).
func _clamp_map_camera() -> void:
	if _map_bounds.size == Vector2.ZERO:
		return
	var half := Vector2(_map_viewport.size) * 0.5 / _map_camera.zoom
	var min_c := _map_bounds.position + half
	var max_c := _map_bounds.end - half
	var pos := _map_camera.position
	pos.x = clampf(pos.x, min_c.x, max_c.x) if min_c.x <= max_c.x else _map_bounds.get_center().x
	pos.y = clampf(pos.y, min_c.y, max_c.y) if min_c.y <= max_c.y else _map_bounds.get_center().y
	_map_camera.position = pos

## Prevodi svetsku poziciju svakog markera u ekranske koordinate map viewport-a.
## Markeri se skaliraju ZAJEDNO sa mapom (zoom), pa ostaju zalepljeni i
## proporcionalni gradu. HEIST_MAP_ZOOM je referentni zoom na kome je marker
## svoje "bazne" velicine (custom_minimum_size).
func _update_marker_positions() -> void:
	var vp := Vector2(_map_viewport.size)
	var center := _map_camera.position
	var label_scale := _map_camera.zoom.x / HEIST_MAP_ZOOM.x
	for i in HEIST_MAP_UI.size():
		if i >= _marker_buttons.size():
			break
		var world: Vector2 = _heist_world_pos(HEIST_MAP_UI[i]["id"])
		var screen := (world - center) * _map_camera.zoom + vp * 0.5
		var btn := _marker_buttons[i]
		# Pivot je default (0,0), pa siremo od gore-levo: pomeri za skaliranu pola velicine da ostane centriran.
		btn.scale = Vector2(label_scale, label_scale)
		btn.position = screen - btn.size * 0.5 * label_scale
		btn.visible = Rect2(Vector2.ZERO, vp).has_point(screen)

func _center_map_on_selection() -> void:
	if not _map_city_ready:
		return
	for data in HEIST_MAP_UI:
		if data["id"] == GameState.selected_heist_id:
			_map_camera.position = _heist_world_pos(data["id"])
			break
	_clamp_map_camera()
	_update_marker_positions()

func _process(_delta: float) -> void:
	if _screen == Screen.HEIST_MAP and _map_city_ready:
		_update_marker_positions()

func _show_screen(screen: Screen) -> void:
	_screen = screen
	_main_panel.visible = screen == Screen.MAIN
	_heist_map_panel.visible = screen == Screen.HEIST_MAP
	_car_shop_panel.visible = screen == Screen.CAR_SHOP
	_item_shop_panel.visible = screen == Screen.ITEM_SHOP
	_settings_panel.visible = screen == Screen.SETTINGS
	if screen == Screen.HEIST_MAP:
		_ensure_heist_selection_valid()
		_refresh_heist_selection()
		_center_map_on_selection()
	elif screen == Screen.ITEM_SHOP:
		_refresh_shop_money()
		_refresh_item_shop()
	elif screen == Screen.CAR_SHOP:
		_refresh_shop_money()
		_refresh_car_shop()

func _on_shop_money_changed(_amount: int) -> void:
	_refresh_shop_money()
	_refresh_item_shop()
	_refresh_car_shop()

func _build_heist_markers() -> void:
	for data in HEIST_MAP_UI:
		var btn := Button.new()
		var heist_id: String = data["id"]
		btn.text = HeistCatalog.get_display_name(heist_id)
		btn.custom_minimum_size = Vector2(168, 42)
		btn.size = btn.custom_minimum_size
		btn.add_theme_font_size_override("font_size", 18)
		# Outline da tekst "iskace" kao na karticama u shopovima.
		btn.add_theme_constant_override("outline_size", 6)
		btn.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.58, 1))
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func() -> void:
			if not HeistProgress.is_unlocked(heist_id):
				_heist_hint.text = _locked_heist_hint(heist_id)
				return
			GameState.selected_heist_id = heist_id
			_refresh_heist_selection()
		)
		_marker_layer.add_child(btn)
		_marker_buttons.append(btn)

func _heist_label(heist_id: String) -> String:
	return HeistCatalog.get_display_name(heist_id)

func _locked_heist_hint(heist_id: String) -> String:
	var label := _heist_label(heist_id)
	var prereq_id := HeistProgress.get_prerequisite_id(heist_id)
	if prereq_id.is_empty():
		return "%s is locked." % label
	return "%s is locked. Complete %s first." % [label, _heist_label(prereq_id)]

func _ensure_heist_selection_valid() -> void:
	if not GameState.selected_heist_id.is_empty() \
			and HeistProgress.is_unlocked(GameState.selected_heist_id):
		return
	GameState.selected_heist_id = ""
	for data in HEIST_MAP_UI:
		if HeistProgress.is_unlocked(data["id"]):
			GameState.selected_heist_id = data["id"]
			return

func _refresh_heist_selection() -> void:
	var selected := GameState.selected_heist_id
	for i in HEIST_MAP_UI.size():
		var btn := _marker_buttons[i]
		var data: Dictionary = HEIST_MAP_UI[i]
		var heist_id: String = data["id"]
		var label := _heist_label(heist_id)
		var unlocked := HeistProgress.is_unlocked(heist_id)
		var is_selected: bool = unlocked and heist_id == selected
		btn.disabled = not unlocked
		if unlocked:
			btn.text = label
			if HeistProgress.is_completed(heist_id):
				btn.text = "%s ✓" % label
		else:
			btn.text = "%s (Locked)" % label
		# Vibrantne boje teksta po stanju (locked koristi font_disabled_color iz builda).
		var completed := unlocked and HeistProgress.is_completed(heist_id)
		if is_selected:
			btn.modulate = Color(1.18, 1.18, 0.9, 1) # topli glow na izabranom
			btn.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28, 1)) # zlatna
		elif completed:
			btn.modulate = Color.WHITE
			btn.add_theme_color_override("font_color", Color(0.45, 1.0, 0.58, 1)) # zelena
		elif unlocked:
			btn.modulate = Color.WHITE
			btn.add_theme_color_override("font_color", Color(0.62, 0.86, 1.0, 1)) # vedra plava
		else:
			btn.modulate = Color.WHITE
	_heist_start_btn.disabled = selected.is_empty() or not HeistProgress.is_unlocked(selected)
	if selected.is_empty():
		_heist_hint.text = "Tap a marker to choose a heist location."
		return
	if not HeistProgress.is_unlocked(selected):
		_heist_hint.text = _locked_heist_hint(selected)
		return
	var status := "Completed" if HeistProgress.is_completed(selected) else "Ready"
	_heist_hint.text = HeistCatalog.format_details(selected, status)

func _start_heist() -> void:
	if GameState.selected_heist_id.is_empty():
		return
	if not HeistProgress.is_unlocked(GameState.selected_heist_id):
		return
	Audio.stop_main_menu_music()
	get_tree().change_scene_to_file(HEIST_SCENE)

func _build_item_shop() -> void:
	_item_row.add_theme_constant_override("separation", 14)
	_item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_refresh_item_shop()

func _refresh_item_shop() -> void:
	_item_cash_label.text = "Money: %s" % GameState.format_loot(float(ItemShop.cash))
	for child in _item_row.get_children():
		child.queue_free()
	for entry in ItemShop.get_shop_entries():
		_item_row.add_child(_make_shop_card(entry))
	_update_item_shop_hint()
	_refresh_item_shop_selection()

func _update_item_shop_hint() -> void:
	if _selected_shop_item_id.is_empty():
		_item_hint.text = ITEM_SHOP_HINT_DEFAULT
		return
	for entry in ItemShop.get_shop_entries():
		if entry["id"] == _selected_shop_item_id:
			var card: Card = entry["card"]
			_item_hint.text = card.description
			return
	_selected_shop_item_id = &""
	_item_hint.text = ITEM_SHOP_HINT_DEFAULT

func _select_shop_item(item_id: StringName, card: Card) -> void:
	_selected_shop_item_id = item_id
	_item_hint.text = card.description
	_refresh_item_shop_selection()

func _refresh_item_shop_selection() -> void:
	for panel in _item_row.get_children():
		if not panel.has_meta("shop_item_id"):
			continue
		var selected := StringName(panel.get_meta("shop_item_id")) == _selected_shop_item_id
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		style.border_color = Color(0.95, 0.82, 0.35, 1) if selected else Color(0.34, 0.36, 0.48, 0.85)
		style.set_border_width_all(3 if selected else 2)

func _make_shop_card(entry: Dictionary) -> Control:
	var card: Card = entry["card"]
	var owned: bool = entry["owned"]
	var equipped: bool = entry.get("equipped", false)
	var price: int = entry["price"]
	var item_id: StringName = entry["id"]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(118, 190)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("shop_item_id", item_id)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
		if tap:
			_select_shop_item(item_id, card)
	)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.12, 0.17, 0.95)
	panel_style.border_color = Color(0.34, 0.36, 0.48, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var icon_frame := CenterContainer.new()
	icon_frame.custom_minimum_size = Vector2(72, 72)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_frame)

	if card.icon != null:
		var icon := TextureRect.new()
		icon.texture = card.icon
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_frame.add_child(icon)

	var name_label := Label.new()
	name_label.text = card.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 56)
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	status.add_theme_constant_override("outline_size", 5)
	status.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1))
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if owned:
		if equipped:
			status.text = "Equipped"
			status.add_theme_color_override("font_color", Color(0.55, 0.92, 0.62, 1))
		else:
			status.text = "Owned"
			status.add_theme_color_override("font_color", Color(0.75, 0.78, 0.9, 1))
	elif price <= 0:
		status.text = "Included"
		status.add_theme_color_override("font_color", Color(0.75, 0.78, 0.9, 1))
	else:
		status.text = GameState.format_loot(float(price))
		status.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1))
	vbox.add_child(status)

	if not owned and price > 0:
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.custom_minimum_size = Vector2(88, 34)
		buy_btn.add_theme_font_size_override("font_size", 17)
		buy_btn.disabled = not ItemShop.can_afford(price)
		buy_btn.pressed.connect(func() -> void:
			if ItemShop.try_purchase(item_id):
				Audio.play_ui_click()
				_refresh_item_shop()
		)
		vbox.add_child(buy_btn)
	elif owned:
		var equip_btn := Button.new()
		equip_btn.text = "Unequip" if equipped else "Equip"
		equip_btn.custom_minimum_size = Vector2(88, 34)
		equip_btn.add_theme_font_size_override("font_size", 17)
		if not equipped:
			equip_btn.disabled = not ItemShop.can_equip_more()
		equip_btn.pressed.connect(func() -> void:
			if ItemShop.try_toggle_equip(item_id):
				Audio.play_ui_click()
				_refresh_item_shop()
		)
		vbox.add_child(equip_btn)
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 34)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(spacer)

	return panel

func _build_car_shop() -> void:
	_car_row.add_theme_constant_override("separation", 14)
	_car_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_refresh_car_shop()

func _refresh_car_shop() -> void:
	_car_cash_label.text = "Money: %s" % GameState.format_loot(float(ItemShop.cash))
	for child in _car_row.get_children():
		child.queue_free()
	for entry in CarShop.get_shop_entries():
		_car_row.add_child(_make_car_shop_card(entry))
	_update_car_shop_hint()
	_refresh_car_shop_selection()

func _update_car_shop_hint() -> void:
	if _selected_car_upgrade_id.is_empty():
		_car_hint.text = CAR_SHOP_HINT_DEFAULT
		return
	for entry in CarShop.get_shop_entries():
		if entry["id"] == _selected_car_upgrade_id:
			_car_hint.text = entry["description"]
			return
	_selected_car_upgrade_id = &""
	_car_hint.text = CAR_SHOP_HINT_DEFAULT

func _select_car_upgrade(upgrade_id: StringName, description: String) -> void:
	_selected_car_upgrade_id = upgrade_id
	_car_hint.text = description
	_refresh_car_shop_selection()

func _refresh_car_shop_selection() -> void:
	for panel in _car_row.get_children():
		if not panel.has_meta("car_upgrade_id"):
			continue
		var selected := StringName(panel.get_meta("car_upgrade_id")) == _selected_car_upgrade_id
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		style.border_color = Color(0.95, 0.82, 0.35, 1) if selected else Color(0.34, 0.36, 0.48, 0.85)
		style.set_border_width_all(3 if selected else 2)

func _make_car_shop_card(entry: Dictionary) -> Control:
	var upgrade_id: StringName = entry["id"]
	var level: int = entry["level"]
	var max_level: int = entry["max_level"]
	var maxed: bool = entry["maxed"]
	var price: int = entry["price"]

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(150, 210)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("car_upgrade_id", upgrade_id)
	panel.gui_input.connect(func(event: InputEvent) -> void:
		var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
		if tap:
			_select_car_upgrade(upgrade_id, entry["description"])
	)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.12, 0.17, 0.95)
	panel_style.border_color = Color(0.34, 0.36, 0.48, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var icon_frame := CenterContainer.new()
	icon_frame.custom_minimum_size = Vector2(72, 72)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_frame)

	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = UI_ICONS
	# Tematske ikonice po upgrade-u (regije u 32x32 atlasu).
	var region := Rect2(320, 320, 32, 32) # speed -> munja
	match upgrade_id:
		&"durability":
			region = Rect2(352, 320, 32, 32) # durability -> srce
		&"heat_decay":
			region = Rect2(448, 288, 32, 32) # heat decay -> lupa
	atlas.region = region
	icon.texture = atlas
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon)

	var name_label := Label.new()
	name_label.text = entry["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(0, 56)
	name_label.add_theme_font_size_override("font_size", 21)
	name_label.add_theme_constant_override("outline_size", 5)
	name_label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "Lv %d/%d" % [level, max_level]
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 17)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if maxed:
		level_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.62, 1))
	else:
		level_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.9, 1))
	vbox.add_child(level_label)

	if maxed:
		var max_label := Label.new()
		max_label.text = "Maxed"
		max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		max_label.add_theme_font_size_override("font_size", 18)
		max_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.62, 1))
		max_label.custom_minimum_size = Vector2(0, 34)
		max_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(max_label)
	else:
		var price_label := Label.new()
		price_label.text = GameState.format_loot(float(price))
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 19)
		price_label.add_theme_constant_override("outline_size", 5)
		price_label.add_theme_color_override("font_outline_color", Color(0.04, 0.05, 0.08, 1))
		price_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.32, 1))
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(price_label)

		var buy_btn := Button.new()
		buy_btn.text = "Upgrade"
		buy_btn.custom_minimum_size = Vector2(100, 36)
		buy_btn.add_theme_font_size_override("font_size", 18)
		buy_btn.disabled = not ItemShop.can_afford(price)
		buy_btn.pressed.connect(func() -> void:
			if CarShop.try_purchase(upgrade_id):
				Audio.play_ui_click()
				_refresh_car_shop()
		)
		vbox.add_child(buy_btn)

	return panel
