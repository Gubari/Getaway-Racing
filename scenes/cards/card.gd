class_name Card
extends Resource
## Definicija JEDNE MOCI (ability). Pravi .tres fajlove u res://resources/cards/
## (desni klik -> New Resource -> Card). Vlasnik: B.
## NB: zove se "Card" zbog ugovora sa A (player.gd koristi Card.Type.NITRO),
## ali UX je "ability dugme", ne klasicna karta.

enum Type { SPIKES, OIL, BARRICADE, NITRO, FAKE_MONEY, JOKER }

@export var type: Type = Type.SPIKES
@export var display_name: String = ""
@export var icon: Texture2D                  # ikonica moci (od C)
@export_multiline var description: String = ""

# Prepreka koja se spawn-uje IZA auta (ulje / barikada).
# Moci koje diraju vozilo (nitro) NEMAJU effect_scene - one idu preko signala.
@export var effect_scene: PackedScene

# --- MODEL AKTIVACIJE ---
# cooldown > 0  -> moc se puni na vreme (npr. nitro)
# max_charges >= 0 -> ogranicen broj upotreba po trci (npr. ulje, barikada)
# moze i oboje; max_charges = -1 znaci neograniceno (cisti cooldown model)
@export var cooldown: float = 0.0
@export var max_charges: int = -1
