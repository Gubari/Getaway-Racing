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
var starting_loot: float = 100_000.0  # postavlja level pre start_run()
var loot_amount: float = 100_000.0    # trenutni plen u novcu
var heat: float = 0.0             # nivo uzbune (za balans heat ritma)
var is_running: bool = false      # da li trka trenutno traje

# ------------------------------------------------------------------
# SIGNALI: dogadjaji vozila        (EMITUJE: A)
# ------------------------------------------------------------------
signal crash_detected(penalty: float)   # A salje % plena (od starting_loot)
signal sharp_turn(penalty: float)         # A salje % plena (od starting_loot)
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
signal loot_changed(value: float)    # D slusa za HUD (apsolutni iznos)
signal heat_changed(value: float)
signal game_won
signal game_over

# ------------------------------------------------------------------
# KAZNE PLENA (balans - B steluje u fazi 20-26h)
# Pravilo iz dizajna: nezno na zaokret, VELIKO samo na sudar.
# ------------------------------------------------------------------
# Kazne su % od starting_loot (15 = 15k pri startu 100k).
const LOOT_PENALTY_CRASH := 15.0
const LOOT_PENALTY_SHARP_TURN := 1.5
const LOOT_PENALTY_NITRO := 3.0

func _ready() -> void:
	# GameState sam slusa dogadjaje vozila i skida plen (jedno mesto).
	crash_detected.connect(func(penalty: float): lose_loot_percent(penalty))
	sharp_turn.connect(func(penalty: float): lose_loot_percent(penalty))
	nitro_used.connect(func(): lose_loot_percent(LOOT_PENALTY_NITRO))

func start_run(heist_starting_loot: float = 100_000.0) -> void:
	starting_loot = maxf(0.0, heist_starting_loot)
	loot_amount = starting_loot
	heat = 0.0
	is_running = true
	loot_changed.emit(loot_amount)
	heat_changed.emit(heat)

func lose_loot_percent(percent: float) -> void:
	lose_loot(starting_loot * percent / 100.0)

func lose_loot(amount: float) -> void:
	if not is_running:
		return
	loot_amount = maxf(0.0, loot_amount - amount)
	loot_changed.emit(loot_amount)

static func format_loot(amount: float) -> String:
	var rounded := roundi(amount)
	if rounded >= 1_000_000:
		var millions := float(rounded) / 1_000_000.0
		if absf(millions - roundi(millions)) < 0.05:
			return "%dM" % int(millions)
		return "%.1fM" % millions
	if rounded >= 1_000:
		var thousands := float(rounded) / 1_000.0
		if absf(thousands - roundi(thousands)) < 0.05:
			return "%dk" % int(thousands)
		return "%.1fk" % thousands
	return str(rounded)

func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, 100.0)
	heat_changed.emit(heat)

func reach_base() -> void:   # pozovi kad igrac stigne do baze
	is_running = false
	game_won.emit()

func caught() -> void:       # pozovi kad policija uhvati igraca
	is_running = false
	game_over.emit()

func abandon() -> void:      # igrac odustao od pljacke (pause meni)
	is_running = false
