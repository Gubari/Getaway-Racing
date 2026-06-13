class_name Card
extends Resource
## Definicija JEDNE karte. Pravi .tres fajlove u res://resources/cards/
## (desni klik -> New Resource -> Card). Vlasnik: B.

enum Type { SPIKES, OIL, BARRICADE, NITRO, FAKE_MONEY, JOKER }

@export var type: Type = Type.SPIKES
@export var display_name: String = ""
@export var icon: Texture2D                  # ikonica karte (od C)
@export_multiline var description: String = ""

# Prepreka koja se spawn-uje IZA auta (ekseri / ulje / barikada).
# Karte koje diraju vozilo (nitro) NEMAJU effect_scene - one idu preko signala.
@export var effect_scene: PackedScene
