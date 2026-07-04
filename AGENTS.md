# AGENTS.md — Ghost-Only Mode

Guide for AI agents and contributors working on this Factorio mod repository.

## Overview

**Ghost-Only Mode** (`ghost-only-mode`) restricts player (and optionally robot) building to positions where a matching ghost entity already exists. Toggle with **Ctrl+G** or the GUI button. Designed for blueprint-based construction where you want to prevent accidental off-ghost placement.

## Repository structure

```
ghost-only-mode/
├── info.json           # Mod manifest (name, version, Factorio version, dependencies)
├── data.lua            # Data stage: prototypes (custom-input, gui-style)
├── control.lua         # Control stage: all runtime logic
├── locale/
│   └── en/
│       └── locale.cfg  # English strings for GUI, messages, hotkey name
├── changelog.txt       # Player-facing version history (Factorio format)
└── AUDIT.md            # Cleanup audit record (reference only)
```

There are no `data-updates.lua`, `data-final-fixes.lua`, `settings.lua`, `prototypes/`, `graphics/`, or `migrations/` directories in the current mod. Logic is self-contained in the root Lua files.

## Factorio load stages and order

| Stage | Files | When it runs |
|-------|-------|--------------|
| **Data** | `data.lua` | During mod load / sync; registers prototypes |
| **Control** | `control.lua` | After data stage; registers events and handlers |
| **Locale** | `locale/en/locale.cfg` | Loaded with mod; keys referenced as `{"gom.key-name"}` |

Standard Factorio data-stage order (`data.lua` → `data-updates.lua` → `data-final-fixes.lua`) applies only when those extra files exist. This mod uses `data.lua` only.

### Runtime event flow (simplified)

```
Player places entity
  → on_built_entity / on_robot_built_entity
  → handle_placement()
      → skip if mode off, blacklisted, or not a buildable type
      → find_ghost() within configured radius
      → refund items + destroy entity + feedback if no ghost
      → align rotation if enabled
```

## Prototype naming conventions

| Category | Pattern | Example |
|----------|---------|---------|
| Custom input | `ghost-only-toggle` | Hotkey prototype in `data.lua` |
| GUI elements | `gom_*` prefix | `gom_flow`, `gom_toggle`, `gom_frame` |
| GUI style | `gom_*` prefix | `gom_wide_textfield` |
| Locale keys | `gom.*` | `gom.build-only-on-ghosts` |
| Persistent state table | `storage.gom` | Never use bare globals outside this table |

**Do not** reintroduce old draft names (`ghostPlacementToggle`, `ghost_only_mode_*`, `global.mod_data`) without an explicit migration plan.

## Dependencies

From `info.json`:

```json
"dependencies": ["base >= 2.0.0"]
```

- **base** — Required. Provides vanilla entities, ghosts, GUI styles, sprites, and the Factorio 2.0 APIs used (`player.gui.top`, `action = "lua"` on custom-input, etc.).

No other mod dependencies.

## How to test / load the mod

1. Clone or symlink this repo folder into Factorio's mod directory:
   - **Windows:** `%APPDATA%\Factorio\mods\`
   - **Linux:** `~/.factorio/mods/`
   - **macOS:** `~/Library/Application Support/factorio/mods/`

   The folder must be named `ghost-only-mode_2.3.6` (or zip it as `ghost-only-mode_2.3.6.zip`).

2. Launch Factorio 2.0+, enable **Ghost-Only Mode** in the mod list.

3. Start or load a save. Verify:
   - No errors in Factorio log (`factorio-current.log`)
   - Ctrl+G toggles the top-right status GUI
   - Settings button opens the settings window (blacklist textfield renders correctly)
   - Placing off-ghost with mode ON refunds the item(s) and shows feedback
   - Placing on a ghost succeeds; rotation aligns when enabled

4. Check log for prototype or locale errors on load.

## Known issues / open questions

- **No automated tests** — validation is manual in-game only.
- **`script.on_load` not defined** — acceptable; no mutable upvalues need restoring across loads.
- **Rejected placement refunds** — player builds use `event.consumed_items`; robot builds spill `event.stack` at the robot position for logistics recovery (robots do not expose carried items in inventory at event time).
- **Robot attribution** — uses `robot.last_user` when available; otherwise the first player on the force with `enforce_robots` enabled is used (known simplification for shared forces).
- **`enabled_players_by_force` stores `LuaPlayer` refs** — works after load today; storing `player_index` only would be more defensive (future cleanup).
- **Ghost placement cache** — capped at 300 entries (`CACHE_SIZE_LIMIT`); evicted on a tick interval. QoL-scale bound, not a full LRU.
- **`rendering.draw_sprite` feedback** — wrapped in `pcall`; failure is silent.
- **Tile-ghost enforcement** — deliberately deferred. Common floor tiles are blacklisted by default; full support would need `on_player_built_tile` / `on_robot_built_tile` handlers.
- **Status GUI after save/load** — `player.gui.top` elements persist in saves; `ensure_all_player_guis()` runs on tick 1 after load as a safety net (see Conventions). `on_singleplayer_init` / `on_multiplayer_init` only fire when `is_multiplayer` changes, not on every SP reload.
- **No README** — `info.json` description and this file serve as documentation.

## Conventions for future edits

1. **Minimal scope** — fix or extend one concern per change; no drive-by refactors.
2. **Preserve behavior** unless fixing a confirmed bug or the user requests a change.
3. **Keep one canonical `control.lua`** — do not add parallel `.txt` draft files.
4. **Locale all player-visible strings** — add keys to `locale/en/locale.cfg` under `[gui]`, `[message]`, or `[custom-input-name]`.
5. **Prototype names are API** — renaming `ghost-only-toggle` or `gom_*` elements breaks saves/GUI; add migrations if renaming.
6. **Match Factorio version in `info.json`** to APIs used in code.
7. **New prototypes go in `data.lua`** (or `prototypes/` if the mod grows).
8. **Update `changelog.txt`** for every released version change.
9. **Persistent state lives in `storage.gom` only** — initialize in `on_init`, clean up in `on_player_removed`.
10. **Session GUI bootstrap** — `script.on_nth_tick(1, …)` calls `ensure_all_player_guis()` once per control-stage load (covers ordinary SP save reload). Do not rely on `on_singleplayer_init` alone for that case.
11. **Commit messages** — describe what changed and why in plain language.

## Historical note

Prior to cleanup (2026-07-04), the repo contained nine `.txt` draft copies of control logic (`toggles_*.txt`, `control3_DS.txt`, `control4_GPT.txt`) from iterative AI-assisted development. These were removed; content remains in git history. See `AUDIT.md` for the full audit.
