extends Node2D
## Glavna scena - vezuje sve zajedno. Startuje trku.
## Vlasnik: zajednicki (instancira tudje scene, ne dira njihovu logiku).

func _ready() -> void:
	GameState.start_run()   # plen na 100%, trka pocinje odmah u poteri
