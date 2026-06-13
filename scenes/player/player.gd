extends CharacterBody2D
## VOZILO IGRACA: top-down fizika, kolizije, plen-curi logika.
## Vlasnik: A. (Skelet - A popunjava fiziku. Ugovor sa B je vec povezan.)

@export var acceleration: float = 600.0
@export var max_speed: float = 500.0
@export var drag: float = 2.5
@export var nitro_multiplier: float = 1.8

func _ready() -> void:
	add_to_group(Constants.GROUP_PLAYER)   # policija (B) nas nalazi preko grupe
	GameState.card_played.connect(_on_card_played)

func _physics_process(_delta: float) -> void:
	# TODO (A): gas/kocnica/skretanje -> velocity sa akceleracijom + drag.
	#           Rotacija zavisi od brzine (ne moze okret u mestu). Lerp na steering.
	#           TOUCH input od prvog sata (dugmad/tap-zone).
	move_and_slide()

	# TODO (A): detekcija dogadjaja -> samo EMITUJ, GameState skida plen:
	#   sudar sa zidom/barikadom  ->  GameState.crash_detected.emit()
	#   ostar zaokret             ->  GameState.sharp_turn.emit()
	# Primer detekcije sudara preko move_and_slide:
	#   if get_slide_collision_count() > 0: GameState.crash_detected.emit()

func _on_card_played(card_type: int) -> void:
	if card_type == Card.Type.NITRO:
		# TODO (A): burst brzine (npr. privremeno povecaj max_speed)
		GameState.nitro_used.emit()   # nitro trese plen (mala kazna)
