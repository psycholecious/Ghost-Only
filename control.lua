local MOD_TOGGLE_KEY = "ghostPlacementToggle"

-- ---------------------------------------------------------------------------
-- Global-safe helpers
-- ---------------------------------------------------------------------------
local function get_mod_data()
    global.mod_data = global.mod_data or { ghost_only_mode = {} }
    return global.mod_data
end

local function get_player(player_index)
    return player_index and game.players[player_index] or nil
end

local function log_event(message, player_name)
    log(string.format(
        "[%d] %s %s",
        game.tick,
        player_name and ("[Player: " .. player_name .. "]") or "[Global]",
        message
    ))
end

-- ---------------------------------------------------------------------------
-- GUI
-- ---------------------------------------------------------------------------
local function update_gui(player, force)
    local mod_data = get_mod_data()
    local root = player.gui.top
    local label = root.ghost_only_mode_label

    if not label then
        label = root.add{
            type = "label",
            name = "ghost_only_mode_label",
            caption = ""
        }
    end

    local enabled = mod_data.ghost_only_mode[player.index]
    local caption = enabled and "Ghost-Only Mode: ON" or "Ghost-Only Mode: OFF"

    if force or label.caption ~= caption then
        label.caption = caption
        log_event("GUI updated → " .. caption, player.name)
    end
end

-- ---------------------------------------------------------------------------
-- Toggle
-- ---------------------------------------------------------------------------
local function toggle_ghost_mode(player_index)
    local mod_data = get_mod_data()
    local player = get_player(player_index)
    if not player then return end

    mod_data.ghost_only_mode[player.index] =
        not mod_data.ghost_only_mode[player.index]

    local state = mod_data.ghost_only_mode[player.index]
    player.print("Ghost-Only Mode: " .. (state and "Enabled" or "Disabled"))
    log_event("Ghost-Only Mode toggled", player.name)

    update_gui(player, true)
end

-- ---------------------------------------------------------------------------
-- Placement enforcement
-- ---------------------------------------------------------------------------
local function handle_placement(event)
    local mod_data = get_mod_data()
    local entity = event.created_entity or event.entity
    if not entity or not entity.valid then return end

    local player = get_player(event.player_index)

    -- Robots are ignored (optional: could enforce for construction robots)
    if not player then return end

    -- Ghost-only mode check
    if not mod_data.ghost_only_mode[player.index] then return end

    -- Determine search area
    local area = entity.bounding_box or {
        {entity.position.x - 1, entity.position.y - 1},
        {entity.position.x + 1, entity.position.y + 1},
    }

    local ghosts = entity.surface.find_entities_filtered{
        area = area,
        type = "entity-ghost"
    }

    for _, ghost in ipairs(ghosts) do
        if ghost.valid and ghost.ghost_name == entity.name then
            local is_rail = entity.type == "straight-rail" or entity.type == "curved-rail"

            if is_rail then
                -- Rails always align to ghost
                entity.direction = ghost.direction
                entity.orientation = ghost.orientation or entity.orientation
            else
                -- Non-rails: enforce strict match only if entity supports rotation
                local dir_match = entity.direction == ghost.direction
                local can_rotate = entity.prototype and entity.prototype.rotatable

                if not dir_match and can_rotate then
                    entity.direction = ghost.direction
                    entity.orientation = ghost.orientation or entity.orientation
                elseif not dir_match then
                    -- Non-rotatable mismatch → destroy
                    entity.destroy()
                    player.print(
                        "Ghost-Only Mode: build only over existing ghosts.",
                        { r = 1, g = 0, b = 0 }
                    )
                    log_event("Invalid placement destroyed (non-rotatable mismatch)", player.name)
                    return
                end
            end

            log_event("Placed over matching ghost: " .. ghost.ghost_name, player.name)
            return
        end
    end

    -- No matching ghost → destroy
    entity.destroy()
    player.print(
        "Ghost-Only Mode: build only over existing ghosts.",
        { r = 1, g = 0, b = 0 }
    )
    log_event("Invalid placement destroyed (no matching ghost)", player.name)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
script.on_event(defines.events.on_built_entity, handle_placement)
script.on_event(defines.events.on_robot_built_entity, handle_placement)

script.on_event(defines.events.on_player_created, function(event)
    local mod_data = get_mod_data()
    mod_data.ghost_only_mode[event.player_index] = false
    update_gui(game.players[event.player_index], true)
end)

script.on_event(MOD_TOGGLE_KEY, function(event)
    toggle_ghost_mode(event.player_index)
end)

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------
script.on_init(function()
    global.mod_data = { ghost_only_mode = {} }
    for _, player in pairs(game.players) do
        global.mod_data.ghost_only_mode[player.index] = false
        update_gui(player, true)
    end
end)
