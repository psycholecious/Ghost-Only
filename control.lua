-- =========================================================
-- Ghost-Only Mode (Factorio 2.0) - Complete Final Version
-- =========================================================

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
local CACHE_SIZE_LIMIT = 5000
local CACHE_PRECISION = "%.2f"

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
        enabled_players_by_force = {}
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
    return entity.prototype.rotatable or entity.type == "straight-rail" or entity.type == "curved-rail"
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
local function find_ghost(entity, radius, player, include_tile_ghosts)
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

    local ghost_types = {"entity-ghost"}
    if include_tile_ghosts then table.insert(ghost_types, "tile-ghost") end

    local ghosts = entity.surface.find_entities_filtered{
        type = ghost_types,
        name = entity.name,
        area = {{pos.x-radius, pos.y-radius},{pos.x+radius,pos.y+radius}},
        limit = s.cache_limit
    }

    local best, best_sq = nil, radius*radius
    for _, g in ipairs(ghosts) do
        local dx, dy = g.position.x - pos.x, g.position.y - pos.y
        local d = dx*dx + dy*dy
        if d < best_sq then
            best, best_sq = g, d
            if d < CLOSE_ENOUGH_SQ then break end
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

    local ghost = find_ghost(entity, s.radius, player, entity.type == "tile")
    if not ghost then
        local pos = entity.position
        entity.destroy()
        if s.show_visual_feedback then
            entity.surface.create_entity{
                name="flying-text", position=pos,
                text={"gom.no-matching-ghost"}, color={1,0,0}
            }
        end
        if not event.robot then player.print({"gom.build-only-on-ghosts"}) end
        return
    end

    if should_align(entity, s) then
        entity.direction = ghost.direction
        if ghost.orientation and entity.orientation then
            entity.orientation = ghost.orientation
        end
    end

    if s.show_visual_feedback and ghost.valid then
        pcall(function()
            rendering.draw_sprite{
                sprite="utility/indicator_bracket",
                target=ghost,
                surface=ghost.surface,
                time_to_live=30,
                color={0,1,0,0.5}
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
            sprite = "item/construction-robot",
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
            sprite = "utility/settings",
            tooltip = {"gom.tooltip-settings"}
        }
    end
end

local function update_gui_status(flow, is_enabled)
    if flow and flow[GUI.STATUS] then
        flow[GUI.STATUS].caption = is_enabled and
            "[color=green]Ghost-Only: ON[/color]" or
            "[color=red]Ghost-Only: OFF[/color]"
    end
end

local function update_gui(player)
    local s = settings(player)
    local root = player.gui.relative
    local flow = root[GUI.FLOW]

    if not s.show_gui then
        if flow then flow.destroy() end
        return
    end

    if not flow then
        flow = root.add{
            type = "flow",
            name = GUI.FLOW,
            anchor = {gui = defines.relative_gui_type.top, position = defines.relative_gui_position.right}
        }
        create_gui_elements(flow)
    end

    update_gui_status(flow, data().enabled[player.index])
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
            if game.entity_prototypes[name] then
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
    frame.add{type="checkbox", name="gom_gui", caption={"gom.tooltip-settings"}, state=s.show_gui}
    frame.add{type="checkbox", name="gom_visual", caption={"gom.tooltip-visual"}, state=s.show_visual_feedback}

    -- Radius slider
    frame.add{type="label", name="gom_radius_label", caption=string.format({"gom.radius-label"}, s.radius)}
    frame.add{
        type="slider",
        name="gom_radius",
        minimum_value=0.1,
        maximum_value=5,
        value=s.radius,
        value_step=0.1
    }

    -- Cache limit slider
    frame.add{type="label", name="gom_cache_limit_label", caption=string.format({"gom.cache-limit-label"}, s.cache_limit)}
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
    titlebar.add{type="sprite-button", name=GUI.CLOSE, sprite="utility/close_white", style="frame_action_button"}

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
    elseif el.name == "gom_align" then s.align = el.state
    elseif el.name == "gom_robots" then s.enforce_robots = el.state
    elseif el.name == "gom_gui" then
        s.show_gui = el.state
        update_gui(player)
        if not s.show_gui and player.gui.screen[GUI.FRAME] then player.gui.screen[GUI.FRAME].destroy() end
    elseif el.name == "gom_visual" then s.show_visual_feedback = el.state
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

local function on_gui_value_changed(e)
    local player = game.get_player(e.player_index)
    if not player then return end
    local s = settings(player)
    if e.element.name == "gom_radius" then
        s.radius = e.element.slider_value
        e.element.parent["gom_radius_label"].caption = string.format({"gom.radius-label"}, s.radius)
    elseif e.element.name == "gom_cache_limit" then
        s.cache_limit = e.element.slider_value
        e.element.parent["gom_cache_limit_label"].caption = string.format({"gom.cache-limit-label"}, s.cache_limit)
    end
end

local function on_gui_closed(e)
    if e.element and e.element.valid and e.element.name == GUI.FRAME then
        local player = game.get_player(e.player_index)
        if player then data().gui_positions[player.index] = e.element.location end
    end
end

script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)
script.on_event(defines.events.on_gui_closed, on_gui_closed)

-------------------
-- Event Handlers
-------------------
script.on_event(defines.events.on_built_entity, handle_placement)
script.on_event(defines.events.on_robot_built_entity, handle_placement)

script.on_event(defines.events.on_player_created, function(e)
    local player = game.get_player(e.player_index)
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
    for _, player in pairs(game.players) do
        settings(player)
        update_gui(player)
    end
end)
