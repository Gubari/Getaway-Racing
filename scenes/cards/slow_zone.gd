extends Area2D
## Prepreka koja USPORAVA policiju dok je u zoni (ulje = blago, barikada = jako).
## Na card_effects layeru, detektuje police layer. Nestaje posle lifetime sek.
## Vlasnik: B.

@export var slow_factor: float = 0.5      # 0.5 = pola brzine; manje = jace usporenje
@export var slow_duration: float = 1.2    # koliko ostane spora POSLE izlaska iz zone
@export var lifetime: float = 7.0         # koliko prepreka traje na podu (0 = zauvek)

func _ready() -> void:
	collision_layer = Constants.LAYER_CARD_FX
	collision_mask = Constants.LAYER_POLICE   # reaguje samo na policiju
	if lifetime > 0.0:
		var t := get_tree().create_timer(lifetime)
		t.timeout.connect(queue_free)

func _physics_process(_delta: float) -> void:
	# Dok je policija u zoni, drzi je usporenom (re-apply svaki frame).
	for body in get_overlapping_bodies():
		if body.has_method("apply_slow"):
			body.apply_slow(slow_factor, slow_duration)
