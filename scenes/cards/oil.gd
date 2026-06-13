extends Area2D
## ULJE: kad policija udje u mrlju, GUBI KONTROLU (klizi i vrti se).
## Ne usporava - cilj je da preleti/zavrti se i izgubi liniju potere.
## Vlasnik: B.

@export var control_loss: float = 1.1   # sek gubitka kontrole
@export var lifetime: float = 7.0       # koliko mrlja traje na podu

func _ready() -> void:
	collision_layer = Constants.LAYER_CARD_FX
	collision_mask = Constants.LAYER_POLICE   # reaguje samo na policiju
	body_entered.connect(_on_body_entered)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
	if body.has_method("lose_control"):
		body.lose_control(control_loss)
