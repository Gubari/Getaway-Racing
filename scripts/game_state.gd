extends Node
## CENTRALNI state + signal bus. SVI sistemi komuniciraju preko ovoga.
## Registrovan kao AUTOLOAD pod imenom "GameState" (vidi project.godot).
## Vlasnik: B (dogovor sa A). Ne menjati signale bez dogovora tima.
##
## Princip: plen zivi NA JEDNOM mestu (ovde). A samo emituje DOGADJAJE,
## a GameState skida plen -> nema dva mesta koja menjaju isti stat -> nema bagova.

# ------------------------------------------------------------------
# STATOVI
# ------------------------------------------------------------------
var loot_percent: float = 100.0   # % plena koji je ostao (start 100)
var heat: float = 0.0             # nivo uzbune (za balans heat ritma)
var is_running: bool = false      # da li trka trenutno traje

# ------------------------------------------------------------------
# SIGNALI: dogadjaji vozila        (EMITUJE: A)
# ------------------------------------------------------------------
signal crash_detected(penalty: float)   # A salje koliko % plena gubi na udar
signal sharp_turn(penalty: float)         # A salje koliko % plena gubi na zaokret
signal nitro_used                 # nitro aktiviran -> trese plen (malo)

# ------------------------------------------------------------------
# SIGNALI: karte                   (EMITUJE: B / CardManager)
# ------------------------------------------------------------------
signal card_played(card_type: int)   # A slusa (npr. nitro = burst brzine)

# ------------------------------------------------------------------
# SIGNALI: garaža / level          (EMITUJE: Garage -> A)
# ------------------------------------------------------------------
signal garage_blocked(message: String)   # D slusa za HUD poruku

# ------------------------------------------------------------------
# SIGNALI: stanje igre / statovi   (EMITUJE: GameState)
# ------------------------------------------------------------------
signal loot_changed(value: float)    # D slusa za HUD
signal heat_changed(value: float)
signal game_won
signal game_over

# ------------------------------------------------------------------
# KAZNE PLENA (balans - B steluje u fazi 20-26h)
# Pravilo iz dizajna: nezno na zaokret, VELIKO samo na sudar.
# ------------------------------------------------------------------
const LOOT_PENALTY_CRASH := 15.0
const LOOT_PENALTY_SHARP_TURN := 1.5
const LOOT_PENALTY_NITRO := 3.0

func _ready() -> void:
	# GameState sam slusa dogadjaje vozila i skida plen (jedno mesto).
	crash_detected.connect(func(penalty: float): lose_loot(penalty))
	sharp_turn.connect(func(penalty: float): lose_loot(penalty))
	nitro_used.connect(func(): lose_loot(LOOT_PENALTY_NITRO))

func start_run() -> void:
	loot_percent = 100.0
	heat = 0.0
	is_running = true
	loot_changed.emit(loot_percent)
	heat_changed.emit(heat)

func lose_loot(amount: float) -> void:
	if not is_running:
		return
	loot_percent = maxf(0.0, loot_percent - amount)
	loot_changed.emit(loot_percent)

func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, 100.0)
	heat_changed.emit(heat)

func reach_base() -> void:   # pozovi kad igrac stigne do baze
	is_running = false
	game_won.emit()

func caught() -> void:       # pozovi kad policija uhvati igraca
	is_running = false
	game_over.emit()
