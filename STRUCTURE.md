# Scrap Heist — Struktura projekta

Godot 4.6, 2D top-down, mobile-first. **Svi rade po ovoj strukturi od starta.**

## Folderi
```
assets/
  sprites/   vehicles/ police/ tiles/ cards/ ui/   <- C ubacuje art ovde
  audio/     music/ sfx/                            <- D ubacuje audio ovde
  fonts/
scenes/
  main/      main.tscn        glavna scena (vezuje sve)        [zajednicki]
  player/    player.tscn/.gd  vozilo + fizika + kolizije       [A]
  police/    police.tscn/.gd  AI state masina + vision cone    [B]
  cards/     card.gd, card_manager.tscn/.gd                    [B]
  ui/        hud.tscn/.gd     HUD, touch dugmad                [D]
  levels/                     staza/tile mape                  [C/A]
scripts/
  constants.gd   zajednicki recnik: grupe + collision layeri   [zajednicki]
  game_state.gd  AUTOLOAD "GameState": statovi + signal bus     [B, dogovor s A]
resources/
  cards/         .tres definicije 6 karata                     [B]
```

## UGOVOR (ne menjati bez dogovora tima)

### GameState (autoload) — sve ide preko ovoga
- **Statovi:** `loot_percent` (start 100), `heat`, `is_running`
- **Dogadjaji vozila (EMITUJE A):** `crash_detected`, `sharp_turn`, `nitro_used`
  → GameState sam skida plen. A samo emituje, ne dira loot direktno.
- **Karte (EMITUJE B):** `card_played(card_type)` → A slusa (npr. nitro)
- **Stanje/statovi (EMITUJE GameState, slusa D):** `loot_changed`, `heat_changed`, `game_won`, `game_over`

### Grupe (Constants.gd)
- Vozilo je u grupi `player`. Policija i karte ga nalaze preko
  `get_tree().get_first_node_in_group("player")` — NIKAD tvrdi put `$Player`.

### Collision layeri (Constants.gd + Project Settings)
| layer | namena |
|-------|--------|
| 1 | player |
| 2 | police |
| 3 | walls  ← line-of-sight raycast gleda samo ovo |
| 4 | card_effects (ekseri/ulje/barikada) |

## Pravila rada
- **Svako radi u svojoj sceni** — `.tscn` merge je pakao. `main.tscn` instancira tudje scene.
- **Touch od prvog sata** (D postavlja dugmad/tap-zone; karte se igraju tapom).
- **Input akcije** (gas/kocnica/skretanje) definise A u Project Settings → Input Map.
- Pokreni `main.tscn` (F5) — sve je vec povezano sa placeholder cvorovima.

## Sledeci koraci po osobi
- **A:** popuni fiziku u `player.gd` (gas/kocnica/skretanje, drag), emituj `crash_detected`/`sharp_turn`.
- **B:** zacementiraj `police.gd` (vision cone radi), napravi 3 `.tres` karte (Ekseri/Ulje/Nitro) u `resources/cards/`, povezi ih u CardManager `deck`.
- **C:** ubaci sprite-ove u `assets/sprites/`, dodeli ih na `Sprite2D` cvorove.
- **D:** napuni `hud.gd`/`hud.tscn` (plen %, ruka karata, touch dugmad), web/mobile build.
