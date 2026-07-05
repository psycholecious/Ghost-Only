# Ghost-Only Mode

A [Factorio 2.0](https://factorio.com/) mod that restricts building to positions where a matching **ghost entity** already exists. Useful when laying out blueprints and you want to avoid accidentally placing entities off-ghost.

**Current version:** 2.3.11 · **Factorio:** 2.0+ · **Dependency:** `base >= 2.0.0`

## Features

- Toggle enforcement with **Ctrl+G** or the status-bar button
- Status bar (top of screen) showing **Ghost-Only: ON/OFF**
- Settings window: search radius, ghost search limit, auto-align to ghost rotation, optional robot enforcement, visual feedback, entity blacklist
- Off-ghost placement is rejected: items are refunded and you get a message (and optional flying text)
- Valid placement over blueprint ghosts is allowed; rotation can follow the ghost when auto-align is enabled

## Installation

1. Download or clone this repository.
2. Copy or symlink the mod folder into your Factorio mods directory:
   - **Windows:** `%APPDATA%\Factorio\mods\`
   - **Linux:** `~/.factorio/mods/`
   - **macOS:** `~/Library/Application Support/factorio/mods/`
3. Name the folder to match the version in `info.json`, e.g. `ghost-only-mode_2.3.11`,  
   or zip it as `ghost-only-mode_2.3.11.zip`.
4. Launch Factorio 2.0+, enable **Ghost-Only Mode** in the mod list, and start or load a save.

## Usage

| Action | How |
|--------|-----|
| Toggle mode | **Ctrl+G** or click the construction-robot icon in the top bar |
| Open settings | Click the **⋯** (options) button next to the status label |
| When mode is **ON** | You can only build entities on top of an existing ghost of the same type |
| Blacklist | Entities on the blacklist can always be placed normally (e.g. tiles, landfill) |

Default blacklisted entities include landfill, concrete, hazard concrete, stone path, and refined concrete variants.

## Settings (summary)

- **Auto-align** — match placed entity direction (and orientation when supported) to the ghost
- **Enforce for robots** — apply ghost-only rules to construction robot builds (uses live ghost search; robots do not trigger pre-build recording)
- **Show status bar** — show or hide the top HUD bar
- **Visual feedback** — flying text when placement is rejected; highlight on successful ghost placement
- **Ghost search radius / limit** — tuning for robot fallback search (player builds use pre-build ghost detection)

## Project layout

```
ghost-only-mode/
├── info.json              Mod manifest
├── data.lua               Prototypes (hotkey, GUI styles)
├── control.lua            Runtime logic
├── locale/en/en.cfg       English strings ([gom] section)
├── changelog.txt          Version history
├── README.md              This file
├── AGENTS.md                Notes for contributors / AI agents
└── FACTORIO_2.0_API_REFERENCE.md   Factorio 2.0 API porting notes
```

## Contributing

See [AGENTS.md](AGENTS.md) for repository conventions, testing steps, and [FACTORIO_2.0_API_REFERENCE.md](FACTORIO_2.0_API_REFERENCE.md) for Factorio 2.0 API details used by this mod.

## License

No license file is included in this repository. Contact the author if you need clarification on reuse or distribution.

## Author

Danick B. — coded and optimized with assistance from ChatGPT, Deepseek, Fable, Opus, Sonnet and Composer 2.5. 
