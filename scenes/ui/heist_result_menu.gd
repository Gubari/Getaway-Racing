extends CanvasLayer
## End-of-heist menus: success and arrested. Same visual style as pause/main menu.
## Vlasnik: D.

const MAIN_MENU_SCENE := "res://scenes/main_menu/main_menu.tscn"

@onready var _dim: ColorRect = $Dim
@onready var _success_panel: Control = $SuccessPanel
@onready var _arrested_panel: Control = $ArrestedPanel

@onready var _success_loot_label: Label = $SuccessPanel/Frame/VBox/LootLabel
@onready var _success_continue_btn: Button = $SuccessPanel/Frame/VBox/ContinueBtn

@onready var _arrested_loot_label: Label = $ArrestedPanel/Frame/VBox/LootLabel
@onready var _arrested_continue_btn: Button = $ArrestedPanel/Frame/VBox/ContinueBtn

var _reward_banked: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_success_continue_btn.pressed.connect(_on_success_continue)
	_arrested_continue_btn.pressed.connect(_on_arrested_continue)
	GameState.game_won.connect(_show_success)
	GameState.game_over.connect(_show_arrested)
	_hide_all()

func _show_success() -> void:
	_reward_banked = false
	_success_loot_label.text = "Loot secured: %s" % GameState.format_loot(GameState.loot_amount)
	_success_continue_btn.disabled = false
	_present(_success_panel)

func _show_arrested() -> void:
	_arrested_loot_label.text = "Loot recovered: %s" % GameState.format_loot(0.0)
	_arrested_continue_btn.disabled = false
	_present(_arrested_panel)

func _present(panel: Control) -> void:
	get_tree().paused = false
	_dim.visible = true
	_success_panel.visible = panel == _success_panel
	_arrested_panel.visible = panel == _arrested_panel

func _hide_all() -> void:
	_dim.visible = false
	_success_panel.visible = false
	_arrested_panel.visible = false

func _on_success_continue() -> void:
	if _reward_banked:
		return
	_reward_banked = true
	_success_continue_btn.disabled = true
	ItemShop.add_earnings(roundi(GameState.loot_amount))
	_go_to_main_menu()

func _on_arrested_continue() -> void:
	if _arrested_continue_btn.disabled:
		return
	_arrested_continue_btn.disabled = true
	_go_to_main_menu()

func _go_to_main_menu() -> void:
	Audio.play_ui_click()
	Audio.stop_heist_audio()
	Audio.play_main_menu_music()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
