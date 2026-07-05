-- Luacheck configuration for the Ghost-Only Mode Factorio mod.
-- Declares the Factorio runtime/data-stage globals so lint focuses on real issues.
-- Docs: https://lua-api.factorio.com/

std = "lua52"

-- Read-only globals provided by the Factorio engine.
read_globals = {
    "game",
    "script",
    "defines",
    "prototypes",
    "rendering",
    "settings",
    "mods",
    "rcon",
    "commands",
    "remote",
    "serpent",
    -- Factorio extends the base `table` library with helpers such as table.deepcopy.
    table = {
        fields = {
            "deepcopy",
            "compare",
            "remove",
            "insert",
            "sort",
            "concat",
        },
    },
}

-- Globals the mod both reads and writes.
globals = {
    "data",     -- data-stage prototype table (data.lua)
    "storage",  -- persistent runtime state (control.lua)
}

-- Factorio event handlers are frequently long; don't nag about line length.
max_line_length = false
