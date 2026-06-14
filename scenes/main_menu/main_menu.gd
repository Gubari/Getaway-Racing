extends CanvasLayer
## Glavni meni na startu igre. Skelet za meta ekrane (mapa, shopovi, settings).
## Vlasnik: D.

enum Screen { MAIN, HEIST_MAP, CAR_SHOP, ITEM_SHOP, SETTINGS }

const _AudioSettings := preload("res://scripts/audio_settings.gd")

const HEIST_SCENE := "res://scenes/main/main.tscn"
const ITEM_SHOP_HINT_DEFAULT := "Select an item for details."
const CAR_SHOP_HINT_DEFAULT := "Select an upgrade for details."
const CAR_ICON := preload("res://assets/sprites/vehicles/player_car_drive.png")

const HEIST_MAP_UI: Array[Dictionary] = [
	{"id": "downtown", "position": Vector2(140, 200)},
	{"id": "port", "position": Vector2(500, 280)},
	{"id": "industrial", "position": Vector2(320, 90)},
]

@onready var _main_panel: Control = $MainPanel
@onready var _heist_map_panel: Control = $HeistMapPanel
@onready var _car_shop_panel: Control = $CarShopPanel
@onready var _item_shop_panel: Control = $ItemShopPanel
@onready var _settings_panel: Control = $SettingsPanel

@onready var _plan_btn: Button = $MainPanel/Frame/VBox/PlanHeistBtn
@onready var _car_shop_btn: Button = $MainPanel/Frame/VBox/CarShopBtn
@onready var _item_shop_btn: Button = $MainPanel/Frame/VBox/ItemShopBtn
@onready var _settings_btn: Button = $MainPanel/Frame/VBox/SettingsBtn

@onready var _heist_back_btn: Button = $HeistMapPanel/Frame/VBox/BackBtn
@onready var _heist_start_btn: Button = $HeistMapPanel/Frame/VBox/StartHeistBtn
@onready var _heist_hint: Label = $HeistMapPanel/Frame/VBox/HintLabel
@onready var _map_container: Control = $HeistMapPanel/Frame/VBox/MapFrame/MapContainer

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	_build_heist_markers()
	_refresh_heist_selection()
	_build_item_shop()
	_build_car_shop()
	ItemShop.cash_changed.connect(_on_shop_money_changed)
	ItemShop.unlocks_changed.connect(_refresh_item_shop)
	HeistProgress.heists_changed.connect(_refresh_heist_selection)
	CarShop.upgrades_changed.connect(_refresh_car_shop)
	_show_screen(Screen.MAIN)
	Audio.play_main_menu_music()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _screen == Screen.MAIN:
		return
	_show_screen(Screen.MAIN)
	get_viewport().set_input_as_handled()

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
	elif screen == Screen.ITEM_SHOP:
		_refresh_item_shop()
	elif screen == Screen.CAR_SHOP:
		_refresh_car_shop()

func _on_shop_money_changed(_amount: int) -> void:
	_refresh_item_shop()
	_refresh_car_shop()

func _build_heist_markers() -> void:
	for data in HEIST_MAP_UI:
		var btn := Button.new()
		var heist_id: String = data["id"]
		btn.text = HeistCatalog.get_display_name(heist_id)
		btn.position = data["position"]
		btn.custom_minimum_size = Vector2(150, 36)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func() -> void:
			if not HeistProgress.is_unlocked(heist_id):
				_heist_hint.text = _locked_heist_hint(heist_id)
				return
			GameState.selected_heist_id = heist_id
			_refresh_heist_selection()
		)
		_map_container.add_child(btn)
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
		if not unlocked:
			btn.modulate = Color(0.42, 0.42, 0.48, 1)
		elif is_selected:
			btn.modulate = Color(1.15, 1.15, 0.85, 1)
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
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
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
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 15)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if owned:
		status.text = "Owned"
		status.add_theme_color_override("font_color", Color(0.55, 0.92, 0.62, 1))
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
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)

	var icon_frame := CenterContainer.new()
	icon_frame.custom_minimum_size = Vector2(72, 72)
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_frame)

	var icon := TextureRect.new()
	var atlas := AtlasTexture.new()
	atlas.atlas = CAR_ICON
	var frame_w := CAR_ICON.get_width() / 6.0
	atlas.region = Rect2(0, 0, frame_w, CAR_ICON.get_height())
	icon.texture = atlas
	icon.custom_minimum_size = Vector2(64, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match upgrade_id:
		&"speed":
			icon.modulate = Color(0.55, 0.85, 1.0)
		&"durability":
			icon.modulate = Color(0.55, 0.95, 0.65)
		&"heat_decay":
			icon.modulate = Color(0.85, 0.7, 1.0)
	icon_frame.add_child(icon)

	var name_label := Label.new()
	name_label.text = entry["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	var level_label := Label.new()
	level_label.text = "Lv %d/%d" % [level, max_level]
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 15)
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
		max_label.add_theme_font_size_override("font_size", 15)
		max_label.add_theme_color_override("font_color", Color(0.55, 0.92, 0.62, 1))
		max_label.custom_minimum_size = Vector2(0, 34)
		max_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(max_label)
	else:
		var price_label := Label.new()
		price_label.text = GameState.format_loot(float(price))
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 15)
		price_label.add_theme_color_override("font_color", Color(0.72, 0.58, 0.12, 1))
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(price_label)

		var buy_btn := Button.new()
		buy_btn.text = "Upgrade"
		buy_btn.custom_minimum_size = Vector2(100, 34)
		buy_btn.add_theme_font_size_override("font_size", 17)
		buy_btn.disabled = not ItemShop.can_afford(price)
		buy_btn.pressed.connect(func() -> void:
			if CarShop.try_purchase(upgrade_id):
				Audio.play_ui_click()
				_refresh_car_shop()
		)
		vbox.add_child(buy_btn)

	return panel
