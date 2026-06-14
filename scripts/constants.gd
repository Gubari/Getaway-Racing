class_name Constants
## Zajednicki recnik za CEO tim: grupe cvorova + collision layeri.
## Ne treba autoload (class_name = globalno dostupno: Constants.GROUP_PLAYER ...).
## Dogovoreno sa A. Ne menjati bez dogovora tima.

# --- GRUPE ---
# Koristi: add_to_group(...) i get_tree().get_first_node_in_group(...)
# Tako policija nalazi igraca BEZ tvrdog puta do cvora -> radimo u odvojenim scenama.
const GROUP_PLAYER := "player"
const GROUP_POLICE := "police"
const GROUP_WALLS := "walls"
const GROUP_GARAGE := "garage"

# --- RENDER DUBINA (top-down Y sort + krov/senice iznad vozila) ---
## TileMapLayer bez kolizije (krov, nadstrešnica) — uvek iznad vozila.
const DEPTH_CANOPY_Z_INDEX := 4096

# --- COLLISION LAYER VREDNOSTI (bitmask) ---
# Project Settings -> Layer Names -> 2D Physics mora da se poklapa:
#   layer 1 = player, layer 2 = police, layer 3 = walls, layer 4 = card_effects
const LAYER_PLAYER := 1   # layer 1
const LAYER_POLICE := 2   # layer 2
const LAYER_WALLS := 4    # layer 3  <- line-of-sight raycast gleda SAMO ovo
const LAYER_CARD_FX := 8  # layer 4

# --- INPUT AKCIJE (Project Settings -> Input Map, vlasnik: A) ---
# D povezuje TouchScreenButton.action na ove stringove.
const INPUT_GAS := "gas"
const INPUT_BRAKE := "brake"
const INPUT_STEER_LEFT := "steer_left"
const INPUT_STEER_RIGHT := "steer_right"
