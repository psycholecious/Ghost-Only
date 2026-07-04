# Ghost-Only Mode — Repository Audit

**Date:** 2026-07-04  
**Branch audited:** `main` @ `a1b442b` (after pull)  
**Mod:** Ghost-Only Mode (`ghost-only-mode` v2.3.0)

## What the mod does

Ghost-Only Mode is a Factorio quality-of-life mod. When a player enables the mode (hotkey **Ctrl+G** or GUI toggle), placement is restricted to positions where a matching ghost already exists. Invalid placements are destroyed with feedback. Optional features include auto-alignment to ghost rotation, robot-build enforcement, configurable search radius, entity blacklist, and a settings GUI.

There is no README in the repository. `info.json` and inline comments in `control.lua` are the authoritative descriptions.

---

## File map

| Path | Factorio stage | Purpose |
|------|----------------|---------|
| `info.json` | Manifest | Mod metadata, version, dependencies |
| `data.lua` | Data | Registers `custom-input` prototype `ghost-only-toggle` |
| `control.lua` | Control / runtime | Toggle, GUI, ghost search, placement enforcement |
| `locale/en/locale.cfg` | Locale | GUI tooltips, messages, custom-input display name |
| `control2.lua` | — | **Orphan.** Empty file (0 bytes). Not loaded by Factorio. |
| `control3_DS.txt` | — | **Draft.** Older control-script iteration (DeepSeek). Uses `ghostPlacementToggle`, `global.mod_data`. |
| `control4_GPT.txt` | — | **Draft.** Older control-script iteration (ChatGPT). |
| `toggles_DS.txt` | — | **Draft.** "Flexible Final" iteration. |
| `toggles_DS2.txt` | — | **Draft.** Adds ghost cache + settings GUI. |
| `toggles_DS3.txt` | — | **Draft.** "Optimized Final" iteration. |
| `toggles_DS4.txt` | — | **Draft.** "Complete Final v2.0" iteration (largest draft). |
| `toggles_GPT.txt` | — | **Draft.** Early GPT iteration with robot-handling bugs. |
| `toggles_GPT2.txt` | — | **Draft.** GPT iteration with ghost cache. |
| `toggles_GPT3.txt` | — | **Draft.** GPT "Complete Final" trimmed version. |

**Not present (and not required for current scope):** `data-updates.lua`, `data-final-fixes.lua`, `settings.lua`, `migrations/`, `prototypes/`, `graphics/`, `changelog.txt`, `README`.

### Load order (Factorio)

1. **Data stage:** `data.lua` only
2. **Control stage:** `control.lua` only
3. **Locale:** `locale/en/locale.cfg` loaded automatically

No `require()` calls exist anywhere in the repo.

---

## Duplicate analysis

### Byte-identical duplicates

**None.** Every file has a unique MD5 checksum.

### Divergent duplicates (same intent, different content)

All nine `.txt` files and `control2.lua` are **superseded drafts** of `control.lua`. They are not loaded by Factorio (wrong extension / empty).

| Draft file | Lines | Relationship to canonical `control.lua` |
|------------|-------|----------------------------------------|
| `control3_DS.txt` | 246 | Early iteration; `ghostPlacementToggle`, simple GUI |
| `control4_GPT.txt` | 209 | Early GPT iteration; player-only builds |
| `toggles_GPT.txt` | 260 | Adds per-player settings; broken robot logic |
| `toggles_DS.txt` | 328 | "Flexible Final"; robot enforcement option |
| `toggles_GPT2.txt` | 527 | Adds ghost cache + settings GUI |
| `toggles_GPT3.txt` | 427 | Trimmed "Complete Final" (GPT) |
| `toggles_DS2.txt` | 523 | Adds cache, settings GUI, flying text |
| `toggles_DS3.txt` | 571 | "Optimized Final"; GUI constants, slider events |
| `toggles_DS4.txt` | 798 | Most feature-rich draft; blacklist, log levels, draggable settings |

**Current `control.lua` (579 lines) is a separate rewrite**, not a copy of any draft:

- Uses `ghost-only-toggle` (drafts use `ghostPlacementToggle`)
- Uses `global.gom` (drafts use `global.mod_data`)
- Uses Factorio 2.0 APIs (`player.gui.relative`, `defines.relative_gui_type`, locale keys)
- Adds tile-ghost support, blacklist GUI, cache-limit setting, force-level robot attribution cache

**Merge decision:** Keep `control.lua` as-is. Drafts are historical artifacts preserved in git history; no content merge required.

---

## Broken / suspicious items

### Critical (blocks mod load)

| Issue | Location | Detail |
|-------|----------|--------|
| Lua syntax error | `data.lua:6-7` | Missing comma after `consuming = "none"` before `action = "lua"` |

### High (runtime errors when feature used)

| Issue | Location | Detail |
|-------|----------|--------|
| Undefined GUI style | `control.lua:401` | References `style = "gom_wide_textfield"` but no `gui-style` prototype defined in `data.lua` |

### Medium (manifest / compatibility mismatch)

| Issue | Location | Detail |
|-------|----------|--------|
| Factorio version mismatch | `info.json` vs `control.lua` | Manifest says `"factorio_version": "1.1"` but `control.lua` header and APIs target **Factorio 2.0** (`player.gui.relative`, `action = "lua"` on custom-input, `defines.relative_gui_type`) |

### Not broken (verified OK)

| Check | Result |
|-------|--------|
| Duplicate prototype registrations | **OK** — single `custom-input` named `ghost-only-toggle` |
| Broken `require` paths | **OK** — no requires |
| `info.json` JSON validity | **OK** — valid JSON, required fields present |
| Locale key coverage | **OK** — all `{"gom.*"}` keys in `control.lua` exist in `locale/en/locale.cfg` |
| Custom-input name consistency | **OK** — `data.lua`, `control.lua`, and locale all use `ghost-only-toggle` |
| Missing graphics references | **OK** — uses vanilla sprites (`item/construction-robot`, `utility/settings`, `utility/close_white`, `utility/indicator_bracket`) |

### Orphaned files (not referenced, not loaded)

- `control2.lua` (empty)
- All nine `*.txt` draft files

---

## Planned actions

### Fixes (no merge ambiguity)

1. **`data.lua`** — Add missing comma; register `gom_wide_textfield` gui-style (parent `wide_textfield`)
2. **`info.json`** — Update `factorio_version` to `"2.0"` and dependency to `base >= 2.0.0` to match code

### Planned deletions (content preserved in git)

| File | Reason |
|------|--------|
| `control2.lua` | Empty orphan |
| `control3_DS.txt` | Superseded draft |
| `control4_GPT.txt` | Superseded draft |
| `toggles_DS.txt` | Superseded draft |
| `toggles_DS2.txt` | Superseded draft |
| `toggles_DS3.txt` | Superseded draft |
| `toggles_DS4.txt` | Superseded draft |
| `toggles_GPT.txt` | Superseded draft |
| `toggles_GPT2.txt` | Superseded draft |
| `toggles_GPT3.txt` | Superseded draft |

### No merge required

`control.lua` on `main` is already the authoritative runtime file.

### Ambiguous items (flagged for your decision)

| Item | Options | Recommendation |
|------|---------|----------------|
| Target Factorio version | Stay on 1.1 (would require rewriting `control.lua`) vs update manifest to 2.0 | Update to 2.0 — code already uses 2.0 APIs |
| Draft archive | Delete vs move to `archive/` | Delete — recoverable via git; keeps repo clean |

---

## Prototype naming conventions (current canonical code)

| Type | Name | Notes |
|------|------|-------|
| `custom-input` | `ghost-only-toggle` | Hotkey Ctrl+G |
| GUI elements | `gom_*` prefix | e.g. `gom_flow`, `gom_frame`, `gom_toggle` |
| Global state | `global.gom` | `enabled`, `settings`, `cache`, `gui_positions`, `enabled_players_by_force` |

Draft files used `ghostPlacementToggle` and `ghost_only_mode_*` GUI names — **not used by canonical code**.
