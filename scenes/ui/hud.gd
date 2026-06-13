extends CanvasLayer
## HUD: plen %, ruka karata, gas/kocnica dugmad, touch layout.
## Vlasnik: D. (Skelet - ugovor sa GameState i CardManager vec povezan.)

func _ready() -> void:
	GameState.loot_changed.connect(_on_loot_changed)
	GameState.heat_changed.connect(_on_heat_changed)
	GameState.game_won.connect(_on_game_won)
	GameState.game_over.connect(_on_game_over)
	# TODO (D): kad CardManager postoji, povezi:
	#   $"../CardManager".hand_changed.connect(_on_hand_changed)

func _on_loot_changed(value: float) -> void:
	pass # TODO (D): prikazi plen % (npr. Label/ProgressBar)

func _on_heat_changed(value: float) -> void:
	pass # TODO (D): prikazi heat

func _on_game_won() -> void:
	pass # TODO (D): ekran pobede + skor = plen %

func _on_game_over() -> void:
	pass # TODO (D): ekran poraza
