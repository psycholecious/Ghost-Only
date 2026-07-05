# Ghost-Only — Factorio 2.0 API Reference & Porting Notes

**For Cursor: read this before writing or altering ANY Factorio API call.**

The recurring source of bugs in this repo has been 1.1-era APIs recalled from
memory. Target Factorio 2.0 (machine-readable API version 6, introduced with
game 2.0.7). When in doubt, look it up in the machine-readable JSON below — do
not guess a signature.

---

## 1. Ground-truth sources (in priority order)

| What | Where | Use it for |
|------|-------|------------|
| **Runtime API (the data)** | `https://lua-api.factorio.com/latest/runtime-api.json` | Exact signatures of every class/method/event/attribute + their params |
| Runtime API (the schema) | `https://lua-api.factorio.com/latest/auxiliary/json-docs.html` | How the JSON above is *structured* (NOT the data itself) |
| Prototype API (the data) | `prototype-api.json` in the same directory | Prototype *types & properties* (e.g. what a style prototype accepts) |
| HTML docs | `https://lua-api.factorio.com/latest/` | Human-readable browsing |
| Base prototype data (Wube) | `github.com/wube/factorio-data` → `core/prototypes/…` | Concrete NAMES: sprites, styles, items, etc. |

**Recommended:** commit `runtime-api.json` into the repo (e.g. `/reference/`)
and grep it for the exact method before touching an API call. It's large —
reference it, don't paste it wholesale into context. Confirm `application_version`
at the top of the file matches the game version being targeted.

---

## 2. Verified 2.0 signatures this mod depends on

All checked against the current live docs.

- **Persistent state:** `storage`, not `global` (renamed in 2.0). All saved
  data goes through the `storage` table.

- **`LuaSurface.spill_item_stack` — TABLE form only:**
  ```lua
  surface.spill_item_stack{
      position = pos,
      stack = { name = ..., count = ..., quality = ... },  -- key is `stack` (was `items` in 1.1)
      enable_looted = false, force = force, allow_belts = false,
      -- optional 2.0 additions: max_radius, use_start_position_on_failure, drop_full_stack
  }
  ```
  A positional call `spill_item_stack(pos, items, ...)` is a 1.1 signature and
  will error in 2.0.

- **`on_built_entity` event:** provides `consumed_items` (a modifiable inventory
  of the items used to build), NOT `stack`/`item` (removed in 2.0). Iterate it
  as an inventory (`#event.consumed_items`, `event.consumed_items[i]`).

- **Ghost search:** `find_entities_filtered{ type = "entity-ghost", ghost_name = <name> }`
  — filter on `ghost_name`, and read `g.ghost_name` on results (not `g.name`).

- **Checkbox state:** handle with `defines.events.on_gui_checked_state_changed`,
  not `on_gui_click`.

- **Prototype lookups:** `prototypes.entity[name]` (1.1 `game.entity_prototypes`
  is removed).

- **Sprite validation:** `helpers.is_valid_sprite_path("type/name")` → boolean,
  available at runtime via the `helpers` global (was `game.is_valid_sprite_path`
  in 1.1). Use it to guard every sprite string.

---

## 3. Localised strings (repeated crash source — not an API signature)

A localised string is a table: `{"locale.key", param1, param2, ...}`.

- **You CANNOT `string.format()` a localised string.** `string.format`'s first
  argument must be a plain string; passing the table throws
  `bad argument #1 to 'format' (string expected, got table)`.
- Inject values *inside* the table. Pre-format numbers on the number only:
  ```lua
  caption = {"gom.radius-label", string.format("%.1f", s.radius)}
  caption = {"gom.search-limit-label", string.format("%d", math.floor(s.cache_limit))}
  ```

---

## 4. Sprite / prototype NAMES are not in the API JSON

`runtime-api.json` / `prototype-api.json` describe the API *shape*, not which
concrete sprites/styles exist. To confirm a name is valid, use either:

- `helpers.is_valid_sprite_path(path)` at runtime (definitive for the installed
  version), **or**
- Wube's data: `core/prototypes/utility-sprites.lua` in `wube/factorio-data`.

**Confirmed-present utility sprites** (safe fallbacks): `utility/add`,
`utility/clone`, `utility/go_to_arrow`, `utility/play`, `utility/pause`,
`utility/stop`.

**UNVERIFIED — guessed from memory in v2.3.6, must be validated in-game or
against `utility-sprites.lua` before trusting:** `utility/expand_dots`,
`utility/close`, `utility/editor_selection`.

---

## 5. 1.1 → 2.0 changes worth knowing (verify exact params in `runtime-api.json`)

Likely relevant to this mod:
- `global` → `storage`.
- `on_entity_destroyed` → `on_object_destroyed`; `register_on_entity_destroyed`
  → `register_on_object_destroyed`.
- `game/player/surface/force.print` no longer takes a `Color` as 2nd param.
- `LuaEntity.rotate` no longer takes `spill_items` / `enable_looted` / `force`.
- `on_built_entity` passes `consumed_items` instead of `stack`/`item`.
- `spill_item_stack` takes a table of parameters (see §2).

(Source: the official 2.0 mod-porting guide. Confirm any specific signature in
`runtime-api.json` before relying on it.)

---

## 6. Pre-commit checklist (run before every push)

1. No `global.` anywhere — all persistent state via `storage.`.
2. Every LuaSurface / LuaEntity / event / GUI call matches its signature in
   `runtime-api.json` for the targeted version (table-vs-positional AND exact
   parameter names).
3. No `string.format` wrapping a localised-string table.
4. Every sprite string is either guarded with `helpers.is_valid_sprite_path`
   (plus a confirmed fallback) or verified against `utility-sprites.lua`.
5. `require("util")` present if `table.deepcopy` / `util.*` is used.
6. `info.json` `factorio_version = "2.0"`; version bumped; `changelog.txt`
   entry added and consistent with `info.json`.
7. Treat every change as UNVERIFIED until the mod loads AND the specific code
   path is exercised in-game — static review has missed real runtime bugs in
   this repo repeatedly.
