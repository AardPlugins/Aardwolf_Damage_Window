-- aard_damage_window_core.lua
-- Configuration, state management, and constants

-- =============================================================================
-- Configuration Defaults
-- =============================================================================
default_width = 500
default_height = 200
default_x = 0
default_y = 300
default_font_name = "Dina"
default_font_size = 10

-- =============================================================================
-- State Variables (global for cross-file access)
-- =============================================================================
width = nil
height = nil
font_name = nil
font_size = nil
startx = nil
starty = nil

text_rect = nil
scrollbar = nil
windowinfo = nil

output_to_main = true
lastRefresh = 0

-- =============================================================================
-- Options Configuration
-- =============================================================================
-- Each option defines a trigger group that can be toggled
options = {
    lotus = {
        desc = "Combine lotus potion output",
    },
    equip = {
        desc = "Combine equip/remove output",
    },
    spellup = {
        desc = "Combine spellup command output",
    },
    where = {
        desc = "Combine the header on the 'where' command",
    },
    combat = {
        desc = "Combine lines of combat",
    },
    death = {
        desc = "Combine mob death output."
    },
}

-- Trigger overrides for individual triggers
trigger_overrides = {}

-- Previous group for combine continuity
prev_group = nil

-- =============================================================================
-- Persistence Variable Keys
-- =============================================================================
VAR_DEBUG = "debug_enabled"
VAR_OUTPUT_TO_MAIN = "output_to_main"
VAR_WINDOW_WIDTH = "window_width"
VAR_WINDOW_HEIGHT = "window_height"
VAR_FONT_NAME = "font_name"
VAR_FONT_SIZE = "font_size"
VAR_TRIGGER_OVERRIDES = "trigger_overrides"
VAR_COMBAT_OTHERS = "combat_others"
VAR_PRESERVE = "preserve"
VAR_DEATH_SIMPLE = "death_simple"
VAR_BONUSEXP_PCT = "bonusexp_pct"

-- =============================================================================
-- State Management Functions
-- =============================================================================
function load_state()
    -- Debug mode
    debug_enabled = (GetVariable(VAR_DEBUG) == "true")

    -- Output settings
    output_to_main = GetVariable(VAR_OUTPUT_TO_MAIN) ~= "false"

    -- Window dimensions
    width = tonumber(GetVariable(VAR_WINDOW_WIDTH)) or default_width
    height = tonumber(GetVariable(VAR_WINDOW_HEIGHT)) or default_height
    font_name = GetVariable(VAR_FONT_NAME) or default_font_name
    font_size = tonumber(GetVariable(VAR_FONT_SIZE)) or default_font_size

    -- Trigger overrides
    local overrides_str = GetVariable(VAR_TRIGGER_OVERRIDES)
    if overrides_str then
        trigger_overrides = json.decode(overrides_str) or {}
    else
        trigger_overrides = {}
    end

    -- Combat options defaults
    if not GetVariable(VAR_COMBAT_OTHERS) then
        SetVariable(VAR_COMBAT_OTHERS, "full")
    end

    -- Enable groups based on saved state
    for v in pairs(options) do
        enable_group(v, GetVariable(v) == "true")
    end
end

function save_state()
    SetVariable(VAR_DEBUG, tostring(debug_enabled))
    SetVariable(VAR_OUTPUT_TO_MAIN, tostring(output_to_main))
    SetVariable(VAR_WINDOW_WIDTH, width)
    SetVariable(VAR_WINDOW_HEIGHT, height)
    SetVariable(VAR_FONT_NAME, font_name)
    SetVariable(VAR_FONT_SIZE, font_size)
    SetVariable(VAR_TRIGGER_OVERRIDES, json.encode(trigger_overrides))

    -- Save window position
    if win then
        movewindow.save_state(win)
    end
end

-- =============================================================================
-- Group Management
-- =============================================================================
function enable_group(group, enable)
    EnableTriggerGroup(group, enable)
    EnableTriggerGroup(group .. "_conditional", false)
    for trigger in pairs(trigger_overrides) do
        EnableTrigger(trigger, false)
    end
end

function toggle_group(option)
    if options[option] then
        ColourTell("silver", "", "Turning ")
        if GetVariable(option) == "true" then
            ColourTell("#f38ba8", "", "OFF")
            SetVariable(option, "false")
            enable_group(option, false)
        else
            ColourTell("#a6da95", "", "ON")
            SetVariable(option, "true")
            enable_group(option, true)
        end
        ColourTell("silver", "", " option: " .. options[option].desc)
        Note()
        SaveState()
    end
end

-- =============================================================================
-- Combine Data Management
-- =============================================================================
function clear_combine_data()
    for option, info in pairs(options) do
        info.data = nil
        EnableTriggerGroup(option .. "_conditional", false)
    end
end

function combine_group(group)
    local new_group = false

    if group ~= prev_group or (group and options[group].end_line ~= GetLineCount()) then
        new_group = true
        clear_combine_data()
    end
    prev_group = group

    EnableTriggerGroup(group .. "_conditional", true)

    if not options[group].data then
        local line_count = GetLineCount()
        if new_group and group == "death" and line_is_all_red(line_count-1) then
            if line_is_all_red(line_count-2) then
                options[group].data = {
                    start_line = line_count - 2
                }
            else
                options[group].data = {
                    start_line = line_count-1
                }
            end
        else
            options[group].data = {
                start_line = line_count
            }
        end
    end

    DeleteLines(GetLineCount() - options[group].data.start_line)
end
