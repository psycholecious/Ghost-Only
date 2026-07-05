-- =========================================================
-- Ghost-Only Mode (Factorio 2.0) - Complete Final Version
-- =========================================================

local util = require("util")

local function safe_sprite(path, fallback)
    if helpers and helpers.is_valid_sprite_path and helpers.is_valid_sprite_path(path) then
        return path
    end
    return fallback
end

-------------------
-- Constants
-------------------
local GUI = {
    FLOW    = "gom_flow",
    STATUS  = "gom_status",
    TOGGLE  = "gom_toggle",
    SETTINGS= "gom_settings",
    FRAME   = "gom_frame",
    CLOSE   = "gom_close"
}

local TOGGLE_KEY = "ghost-only-toggle"

local DEFAULTS = {
    enabled = false,
    align = true,
    enforce_robots = false,
    show_gui = true,
    show_visual_feedback = true,
    radius = 0.5,
    cache_limit = 10,
    blacklist = {}
}

local BLACKLIST_DEFAULT = {
    landfill = true,
    concrete = true,
    ["hazard-concrete"] = true,
    ["stone-path"] = true,
    ["refined-concrete"] = true,
    ["refined-hazard-concrete"] = true
}

local CLOSE_ENOUGH_SQ = 0.04
local CLEANUP_INTERVAL = 3600
local CACHE_SIZE_LIMIT = 300
local CACHE_PRECISION = "%.2f"
local PREBUILD_KEY_PRECISION = "%d:%.2f:%.2f"

local function prebuild_key(surface_index, pos)
    return string.format(PREBUILD_KEY_PRECISION, surface_index, pos.x, pos.y)
end

-------------------
-- Persistent State (storage)
-------------------
local function data()
    storage.gom = storage.gom or {
        enabled = {},
        settings = {},
        cache = {},
        gui_positions = {},
        last_cleanup = 0,
        enabled_players_by_force = {},
        pre_build_ghosts = {}
    }
    return storage.gom
end

local function settings(player)
    local d = data()
    local s = d.settings[player.index]
    if not s then
        s = table.deepcopy(DEFAULTS)
        s.blacklist = table.deepcopy(BLACKLIST_DEFAULT)
        d.settings[player.index] = s
    end
    return s
end

local function merge_settings_defaults(s)
    for key, value in pairs(DEFAULTS) do
        if s[key] == nil then
            if key == "blacklist" then
                s.blacklist = table.deepcopy(BLACKLIST_DEFAULT)
            else
                s[key] = value
            end
        end
    end
    if not s.blacklist then
        s.blacklist = table.deepcopy(BLACKLIST_DEFAULT)
    end
end

-------------------
-- Helper Functions
-------------------
local function should_check(entity)
    if not entity or not entity.valid then return false end
    local t = entity.type
    return not (t == "item-entity" or t == "resource" or t == "particle" or t == "projectile" or t == "corpse")
end

local function cache_key(entity)
    local p = entity.position
    return string.format("%d:%s:" .. CACHE_PRECISION .. ":" .. CACHE_PRECISION,
        entity.surface.index, entity.name, p.x, p.y)
end

local function should_align(entity, s)
    if not s.align then return false end
    return entity.supports_direction
end

local function update_enabled_cache_smart(player_index, enabled)
    local player = game.get_player(player_index)
    if not player then return end
    local force_name = player.force.name
    local d = data()
    local cache = d.enabled_players_by_force

    if enabled then
        cache[force_name] = cache[force_name] or {}
        for _, p in ipairs(cache[force_name]) do
            if p.index == player_index then return end
        end
        table.insert(cache[force_name], player)
    else
        local list = cache[force_name]
        if list then
            for i = #list, 1, -1 do
                if list[i].index == player_index then
                    table.remove(list, i)
                    break
                end
            end
            if #list == 0 then cache[force_name] = nil end
        end
    end
end

-------------------
-- Cache Management
-------------------
local function cleanup_cache()
    local d = data()
    if game.tick - d.last_cleanup < CLEANUP_INTERVAL then return end
    d.last_cleanup = game.tick

    local count = 0
    local to_remove = {}
    for k, g in pairs(d.cache) do
        if not g or not g.valid then
            to_remove[#to_remove+1] = k
        else
            count = count + 1
            if count > CACHE_SIZE_LIMIT then
                to_remove[#to_remove+1] = k
            end
        end
    end
    for _, k in ipairs(to_remove) do d.cache[k] = nil end
end

-------------------
-- Ghost Search
-------------------
local function find_ghost(entity, radius, player)
    cleanup_cache()
    local s = settings(player)
    local key = cache_key(entity)
    local pos = entity.position
    local cache = data().cache

    local cached = cache[key]
    if cached and cached.valid then
        local dx, dy = cached.position.x - pos.x, cached.position.y - pos.y
        if dx*dx + dy*dy <= radius*radius then return cached end
    end

    local ghosts = entity.surface.find_entities_filtered{
        type = "entity-ghost",
        ghost_name = entity.name,
        area = {{pos.x-radius, pos.y-radius},{pos.x+radius,pos.y+radius}},
        limit = s.cache_limit
    }

    local best, best_sq = nil, radius*radius
    for _, g in ipairs(ghosts) do
        if g.ghost_name == entity.name then
            local dx, dy = g.position.x - pos.x, g.position.y - pos.y
            local d = dx*dx + dy*dy
            if d < best_sq then
                best, best_sq = g, d
                if d < CLOSE_ENOUGH_SQ then break end
            end
        end
    end

    if best then cache[key] = best end
    return best
end

-------------------
-- Robot Attribution
-------------------
local function find_robot_owner(entity, robot)
    local d = data()
    if robot and robot.last_user then
        local p = game.get_player(robot.last_user)
        if p and p.valid and p.force == entity.force then
            local s = settings(p)
            if s.enforce_robots and d.enabled[p.index] then return p end
        end
    end

    local list = d.enabled_players_by_force[entity.force.name]
    if list then
        -- Known simplification: first enforce_robots player on the force wins when last_user is absent.
        for _, p in ipairs(list) do
            if p and p.valid then
                local s = settings(p)
                if s.enforce_robots then return p end
            end
        end
    end
    return nil
end

-------------------
-- Refund Logic
-------------------
local function refund_build_items(event, player, entity, robot)
    local surface = entity.surface
    local position = entity.position
    local force = entity.force

    if event.consumed_items and event.consumed_items.valid then
        for i = 1, #event.consumed_items do
            local stack = event.consumed_items[i]
            if stack.valid_for_read then
                local remaining = stack.count
                if player and player.valid then
                    remaining = remaining - player.insert(stack)
                end
                if remaining > 0 then
                    surface.spill_item_stack{
                        position = position,
                        stack = { name = stack.name, count = remaining, quality = stack.quality },
                        enable_looted = false, force = force, allow_belts = false
                    }
                end
            end
        end
    elseif robot and robot.valid and event.stack and event.stack.valid_for_read then
        -- Robot builds: item not in robot inventory yet at event time; spill for logistics pickup.
        surface.spill_item_stack{
            position = robot.position, stack = event.stack,
            enable_looted = true, force = force, allow_belts = false
        }
    end
end

-------------------
-- Placement Logic
-------------------
local function handle_placement(event)
    local entity = event.created_entity or event.entity
    if not entity or not should_check(entity) then return end

    local player = event.player_index and game.get_player(event.player_index)
    if event.robot then
        player = find_robot_owner(entity, event.robot)
        if not player then return end
    end

    local d = data()
    if not player or not d.enabled[player.index] then return end
    local s = settings(player)
    if s.blacklist[entity.name] then return end

    -- Check the pre-build lookahead: did a ghost exist at this position before the engine consumed it?
    local pos = entity.position
    local key = prebuild_key(entity.surface.index, pos)
    d.pre_build_ghosts = d.pre_build_ghosts or {}
    local pre = d.pre_build_ghosts[key]
    d.pre_build_ghosts[key] = nil

    local ghost = nil
    local ghost_was_present
    local pre_direction
    if pre == nil then
        -- Robot build: no on_pre_build record, fall back to live search.
        ghost = find_ghost(entity, s.radius, player)
        ghost_was_present = ghost ~= nil
        if ghost then pre_direction = ghost.direction end
    elseif pre == false then
        ghost_was_present = false
    else
        ghost_was_present = (pre.ghost_name == entity.name)
        pre_direction = pre.direction
    end

    if not ghost_was_present then
        refund_build_items(event, player, entity, event.robot)
        entity.destroy{raise_destroy = true}
        if s.show_visual_feedback and player and player.valid then
            player.create_local_flying_text{
                text = {"gom.no-matching-ghost"},
                position = pos,
                color = {1, 0, 0},
                time_to_live = 60,
                speed = 40
            }
        end
        if not event.robot then player.print({"gom.build-only-on-ghosts"}) end
        return
    end

    if should_align(entity, s) and pre_direction then
        entity.direction = pre_direction
    end

    if s.show_visual_feedback then
        pcall(function()
            rendering.draw_sprite{
                sprite = "utility/editor_selection",
                target = entity,
                surface = entity.surface,
                time_to_live = 30,
                color = {0, 1, 0, 0.5}
            }
        end)
    end
end

-------------------
-- GUI Functions
-------------------
local function create_gui_elements(flow)
    if not flow[GUI.TOGGLE] then
        flow.add{
            type = "sprite-button",
            name = GUI.TOGGLE,
            sprite = safe_sprite("item/construction-robot", "utility/go_to_arrow"),
            tooltip = {"gom.tooltip-toggle"}
        }
    end
    if not flow[GUI.STATUS] then
        flow.add{type = "label", name = GUI.STATUS}
    end
    if not flow[GUI.SETTINGS] then
        flow.add{
            type = "sprite-button",
            name = GUI.SETTINGS,
            sprite = safe_sprite("utility/expand_dots", "utility/go_to_arrow"),
            tooltip = {"gom.tooltip-settings"}
        }
    end
end

local function update_gui_status(flow, is_enabled)
    if flow and flow[GUI.STATUS] then
        flow[GUI.STATUS].caption = is_enabled and {"gom.status-on"} or {"gom.status-off"}
    end
end

local function update_gui(player)
    local s = settings(player)
    -- Always-visible HUD bar (player.gui.top), not player.gui.relative — relative
    -- anchors require a valid defines.relative_gui_type, and this mod is not tied
    -- to a specific vanilla panel.
    local old_relative = player.gui.relative[GUI.FLOW]
    if old_relative then old_relative.destroy() end

    local root = player.gui.top
    local flow = root[GUI.FLOW]

    if not s.show_gui then
        if flow then flow.destroy() end
        return
    end

    if not flow then
        flow = root.add{
            type = "flow",
            name = GUI.FLOW,
            direction = "horizontal"
        }
        create_gui_elements(flow)
    end

    update_gui_status(flow, data().enabled[player.index])
end

local function rebuild_enabled_players_by_force()
    local d = data()
    d.enabled_players_by_force = {}
    for player_index, enabled in pairs(d.enabled) do
        if enabled then
            update_enabled_cache_smart(player_index, true)
        end
    end
end

local function ensure_all_player_guis()
    for _, player in pairs(game.players) do
        if player.valid then
            settings(player)
            update_gui(player)
        end
    end
end

-------------------
-- Blacklist Functions
-------------------
local function add_to_blacklist(player, entity_names_text)
    local s = settings(player)
    s.blacklist = s.blacklist or {}
    local entities_added, invalid_entities = 0, {}

    for name in entity_names_text:gmatch("[^,%s;]+") do
        name = name:match("^%s*(.-)%s*$")
        if name ~= "" then
            if prototypes.entity[name] then
                s.blacklist[name] = true
                entities_added = entities_added + 1
            else
                table.insert(invalid_entities, name)
            end
        end
    end

    if entities_added > 0 then
        player.print({"gom.entities-added-to-blacklist", entities_added})
    end
    if #invalid_entities > 0 then
        player.print({"gom.invalid-entities", table.concat(invalid_entities, ", ")})
    end

    return entities_added
end

local function update_blacklist_display(list_flow, blacklist)
    list_flow.clear()
    local names = {}
    for name in pairs(blacklist) do table.insert(names, name) end
    table.sort(names)

    for _, name in ipairs(names) do
        list_flow.add{
            type = "button",
            name = "gom_blacklist_remove_"..name,
            caption = {"gom.blacklist-remove", name},
            style = "back_button"
        }
    end
end

-------------------
-- Settings Window
-------------------
local function create_settings_window_content(frame, player)
    local s = settings(player)
    -- Clear previous children (except titlebar)
    for _, child in pairs(frame.children) do
        if child.name ~= GUI.CLOSE and not child.name:match("^gom_titlebar") then
            child.destroy()
        end
    end

    -- Checkboxes
    frame.add{type="checkbox", name="gom_align", caption={"gom.auto-align"}, state=s.align}
    frame.add{type="checkbox", name="gom_robots", caption={"gom.tooltip-robots"}, state=s.enforce_robots}
    frame.add{type="checkbox", name="gom_gui", caption={"gom.show-gui"}, state=s.show_gui}
    frame.add{type="checkbox", name="gom_visual", caption={"gom.tooltip-visual"}, state=s.show_visual_feedback}

    -- Radius slider
    frame.add{type="label", name="gom_radius_label", caption={"gom.radius-label", string.format("%.1f", s.radius)}}
    frame.add{
        type="slider",
        name="gom_radius",
        minimum_value=0.1,
        maximum_value=5,
        value=s.radius,
        value_step=0.1
    }

    -- Cache limit slider
    frame.add{type="label", name="gom_cache_limit_label", caption={"gom.search-limit-label", string.format("%d", math.floor(s.cache_limit))}}
    frame.add{
        type="slider",
        name="gom_cache_limit",
        minimum_value=1,
        maximum_value=100,
        value=s.cache_limit,
        value_step=1
    }

    -- Blacklist frame
    local blacklist_frame = frame.add{type="frame", direction="vertical", caption={"gom.blacklist-title"}}
    blacklist_frame.add{type="label", caption={"gom.blacklist-help"}}
    blacklist_frame.add{type="textfield", name="gom_blacklist_input", text="", tooltip={"gom.blacklist-tooltip"}, style="gom_wide_textfield"}

    local button_flow = blacklist_frame.add{type="flow", direction="horizontal"}
    button_flow.add{type="button", name="gom_blacklist_add", caption={"gom.blacklist-add"}}
    button_flow.add{type="button", name="gom_blacklist_clear", caption={"gom.blacklist-clear"}, style="red_button"}

    local list_flow = blacklist_frame.add{type="flow", name="gom_blacklist_list", direction="vertical"}
    update_blacklist_display(list_flow, s.blacklist or {})
end

local function open_settings(player)
    local root = player.gui.screen
    local d = data()
    local s = settings(player)

    if root[GUI.FRAME] then
        d.gui_positions[player.index] = root[GUI.FRAME].location
        root[GUI.FRAME].destroy()
    end

    local frame = root.add{type="frame", name=GUI.FRAME, caption={"gom.settings-title"}, direction="vertical"}
    frame.location = d.gui_positions[player.index] or {x=300, y=200}

    -- Title bar
    local titlebar = frame.add{type="flow", direction="horizontal", name="gom_titlebar"}
    titlebar.drag_target = frame
    titlebar.add{type="label", caption={"gom.settings-title"}, style="frame_title"}
    local drag_space = titlebar.add{type="empty-widget", style="draggable_space_header"}
    drag_space.style.horizontally_stretchable = true
    titlebar.add{type="sprite-button", name=GUI.CLOSE, sprite=safe_sprite("utility/close", "utility/go_to_arrow"), style="frame_action_button"}

    create_settings_window_content(frame, player)
end

-------------------
-- GUI Event Handlers
-------------------
local function on_gui_click(e)
    local el = e.element
    local player = game.get_player(e.player_index)
    if not el or not player then return end
    local s, d = settings(player), data()

    if el.name == GUI.TOGGLE then
        d.enabled[player.index] = not d.enabled[player.index]
        update_enabled_cache_smart(player.index, d.enabled[player.index])
        update_gui(player)
    elseif el.name == GUI.SETTINGS then
        open_settings(player)
    elseif el.name == GUI.CLOSE then
        if el.parent and el.parent.parent then
            d.gui_positions[player.index] = el.parent.parent.location
            el.parent.parent.destroy()
        end
    elseif el.name == "gom_blacklist_add" then
        local input = el.parent.parent["gom_blacklist_input"]
        if input and input.valid and input.text ~= "" then
            if add_to_blacklist(player, input.text) > 0 then
                input.text = ""
                update_blacklist_display(el.parent.parent["gom_blacklist_list"], s.blacklist or {})
            end
        end
    elseif el.name == "gom_blacklist_clear" then
        s.blacklist = {}
        player.print({"gom.blacklist-cleared"})
        update_blacklist_display(el.parent.parent["gom_blacklist_list"], {})
    elseif el.name:match("^gom_blacklist_remove_") then
        local name = el.name:gsub("^gom_blacklist_remove_", "")
        if s.blacklist then
            s.blacklist[name] = nil
            player.print({"gom.entity-removed-from-blacklist", name})
            update_blacklist_display(el.parent, s.blacklist or {})
        end
    end
end

local function on_gui_checked_state_changed(e)
    local el = e.element
    local player = game.get_player(e.player_index)
    if not el or not el.valid or not player then return end
    local s = settings(player)

    if el.name == "gom_align" then
        s.align = el.state
    elseif el.name == "gom_robots" then
        s.enforce_robots = el.state
    elseif el.name == "gom_gui" then
        s.show_gui = el.state
        update_gui(player)
        if not s.show_gui and player.gui.screen[GUI.FRAME] then
            player.gui.screen[GUI.FRAME].destroy()
        end
    elseif el.name == "gom_visual" then
        s.show_visual_feedback = el.state
    end
end

local function on_gui_value_changed(e)
    local player = game.get_player(e.player_index)
    if not player or not e.element or not e.element.valid then return end
    local s = settings(player)
    local parent = e.element.parent
    if e.element.name == "gom_radius" then
        s.radius = e.element.slider_value
        local label = parent and parent["gom_radius_label"]
        if label and label.valid then
            label.caption = {"gom.radius-label", string.format("%.1f", s.radius)}
        end
    elseif e.element.name == "gom_cache_limit" then
        s.cache_limit = e.element.slider_value
        local label = parent and parent["gom_cache_limit_label"]
        if label and label.valid then
            label.caption = {"gom.search-limit-label", string.format("%d", math.floor(s.cache_limit))}
        end
    end
end

local function on_gui_closed(e)
    if e.element and e.element.valid and e.element.name == GUI.FRAME then
        local player = game.get_player(e.player_index)
        if player then data().gui_positions[player.index] = e.element.location end
    end
end

script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
script.on_event(defines.events.on_gui_closed, on_gui_closed)

-------------------
-- Event Handlers
-------------------
script.on_event(defines.events.on_built_entity, handle_placement)
script.on_event(defines.events.on_robot_built_entity, handle_placement)

script.on_event(defines.events.on_pre_build, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local d = data()
    if not d.enabled[player.index] then return end

    -- surface_index is available via player.surface when on_pre_build fires
    local surface = player.surface
    local pos = e.position

    -- Search for any entity-ghost at the cursor position before the engine consumes it.
    -- Use a small area (0.5 tiles) — the cursor is always tile-centred for entity builds.
    local ghosts = surface.find_entities_filtered{
        type = "entity-ghost",
        area = {{pos.x - 0.5, pos.y - 0.5}, {pos.x + 0.5, pos.y + 0.5}}
    }

    local key = prebuild_key(surface.index, pos)
    -- Store ghost metadata before the engine consumes it, for on_built_entity cross-check.
    d.pre_build_ghosts = d.pre_build_ghosts or {}
    if #ghosts > 0 then
        local g = ghosts[1]
        d.pre_build_ghosts[key] = {
            ghost_name = g.ghost_name,
            direction = g.direction
        }
    else
        d.pre_build_ghosts[key] = false
    end
end)

script.on_event(defines.events.on_player_created, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    settings(player)
    data().enabled[player.index] = false
    update_gui(player)
end)

script.on_event(defines.events.on_player_removed, function(e)
    local d = data()
    d.enabled[e.player_index] = nil
    d.settings[e.player_index] = nil
    d.gui_positions[e.player_index] = nil

    for force_name, list in pairs(d.enabled_players_by_force) do
        for i=#list,1,-1 do
            if list[i].index==e.player_index then table.remove(list,i); break end
        end
        if #list==0 then d.enabled_players_by_force[force_name]=nil end
    end
end)

script.on_event(defines.events.on_player_changed_force, function(e)
    local d = data()
    local player = game.get_player(e.player_index)
    if not player then return end
    for force_name, list in pairs(d.enabled_players_by_force) do
        for i=#list,1,-1 do
            if list[i].index==e.player_index then table.remove(list,i); break end
        end
        if #list==0 then d.enabled_players_by_force[force_name]=nil end
    end
    if d.enabled[player.index] then update_enabled_cache_smart(e.player_index,true) end
end)

script.on_event(defines.events.on_player_display_scale_changed, function(e)
    local player = game.get_player(e.player_index)
    if player and player.gui.screen[GUI.FRAME] then open_settings(player) end
end)

script.on_event(defines.events.on_singleplayer_init, function()
    rebuild_enabled_players_by_force()
    ensure_all_player_guis()
end)

script.on_event(defines.events.on_multiplayer_init, function()
    rebuild_enabled_players_by_force()
    ensure_all_player_guis()
end)

script.on_event(defines.events.on_player_joined_game, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    settings(player)
    if data().enabled[player.index] then
        update_enabled_cache_smart(player.index, true)
    end
    update_gui(player)
end)

script.on_event(TOGGLE_KEY, function(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local d = data()
    d.enabled[player.index] = not d.enabled[player.index]
    update_enabled_cache_smart(player.index, d.enabled[player.index])
    update_gui(player)
end)

-------------------
-- Initialization
-------------------
script.on_init(function()
    for _, player in pairs(game.players) do
        settings(player)
        data().enabled[player.index] = false
        update_gui(player)
    end
end)

script.on_configuration_changed(function(cfg)
    data()
    for _, player in pairs(game.players) do
        if player.valid then
            merge_settings_defaults(settings(player))
            update_gui(player)
        end
    end
    rebuild_enabled_players_by_force()
end)

-- Runs once per session start (including save load). on_singleplayer_init only fires when
-- is_multiplayer changes, so this covers ordinary singleplayer quit-and-reload cycles.
script.on_nth_tick(1, function()
    script.on_nth_tick(1, nil)
    rebuild_enabled_players_by_force()
    ensure_all_player_guis()
end)
