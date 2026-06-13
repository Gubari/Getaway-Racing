extends Node
## SPIL + RUKA. Vucem nasumicne karte, tap-to-play (TOUCH od prvog sata).
## Vlasnik: B.

@export var deck: Array[Card] = []     # popuni iz inspektora .tres karticama
@export var hand_size: int = 4

var hand: Array[Card] = []
var draw_pile: Array[Card] = []

signal hand_changed(hand: Array)        # CardUI (D) slusa za prikaz ruke

func _ready() -> void:
	_build_draw_pile()
	for i in hand_size:
		_draw_card()

func _build_draw_pile() -> void:
	draw_pile = deck.duplicate()
	draw_pile.shuffle()

func _draw_card() -> void:
	if draw_pile.is_empty():
		_build_draw_pile()
	if draw_pile.is_empty():
		return   # spil prazan (npr. nije popunjen)
	hand.append(draw_pile.pop_back())
	hand_changed.emit(hand)

## Pozovi iz UI-ja na tap na kartu.
func play_card(index: int) -> void:
	if index < 0 or index >= hand.size():
		return
	var card: Card = hand[index]
	hand.remove_at(index)
	_apply_card(card)
	_draw_card()
	hand_changed.emit(hand)

func _apply_card(card: Card) -> void:
	# 1) javi vozilu (A) preko signala - npr. nitro
	GameState.card_played.emit(card.type)
	# 2) ako karta spawn-uje prepreku iza auta (ekseri/ulje/barikada)
	if card.effect_scene:
		_spawn_effect(card)

func _spawn_effect(card: Card) -> void:
	var player := get_tree().get_first_node_in_group(Constants.GROUP_PLAYER)
	if player == null:
		return
	var fx := card.effect_scene.instantiate()
	# spawn iza auta (offset suprotno od pravca kretanja)
	var behind := -Vector2.RIGHT.rotated(player.rotation) * 48.0
	fx.global_position = player.global_position + behind
	get_tree().current_scene.add_child(fx)
