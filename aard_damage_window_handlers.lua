-- aard_damage_window_handlers.lua
-- All alias/trigger/plugin callbacks (MUST be global for MUSHclient)

-- =============================================================================
-- Plugin Lifecycle Callbacks
-- =============================================================================
function OnPluginInstall()
    load_state()
    suppress_triggers_for_all_tags()

    -- Create combat damage trigger dynamically
    AddTrigger("combat_damage", get_damage_regex(), "", eOmitFromOutput + eTriggerRegularExpression, 0, 0, "")
    SetTriggerOption("combat_damage", "group", "combat")
    SetTriggerOption("combat_damage", "omit_from_output", "y")
    SetTriggerOption("combat_damage", "script", "combine")

    init_window()
end

function OnPluginEnable()
    if win then
        WindowShow(win, true)
    end
end

function OnPluginDisable()
    if win then
        WindowShow(win, false)
    end
end

function OnPluginClose()
    if win then
        WindowDelete(win)
    end
end

function OnPluginSaveState()
    save_state()
end

-- =============================================================================
-- Main Trigger Handlers
-- =============================================================================
function combine(name, line, wc, sr)
    local group = GetTriggerOption(name, "group")
    group = remove_from_end(group, "_conditional")

    if GetVariable(group) == "true" then
        combine_group(group)
        local data = options[group].data

        if group == "death" then
            combine_death(name, line, wc, sr, data)
        elseif group == "lotus" then
            combine_lotus(name, line, wc, sr, data)
        elseif group == "equip" then
            combine_equip(name, line, wc, sr, data)
        elseif group == "spellup" then
            combine_spellup(name, line, wc, sr, data)
        elseif group == "where" then
            combine_where(name, line, wc, sr, data)
        elseif group == "combat" then
            combine_combat(name, line, wc, sr, data)
        end

        options[group].end_line = GetLineCount()
    end

    return true
end

function non_combine(name, line, wc)
    clear_combine_data()
    prev_group = nil
end

function ignore(name, line, wc)
    -- Intentionally empty - these triggers are captured but not displayed
end

function none()
    -- No-op handler
end

-- =============================================================================
-- Alias Handlers - Window Control
-- =============================================================================
function window_show(name, line, wildcards)
    WindowShow(win, true)
    ColourNote("yellow", "", "Damage window now shown. Type 'spamwin hide' to hide it.")
end

function window_hide(name, line, wildcards)
    WindowShow(win, false)
    ColourNote("yellow", "", "Damage window now hidden. Type 'spamwin show' to see it again.")
end

function window_clear(name, line, wildcards)
    if text_rect then
        text_rect:clear(true)
    end
    ColourNote("yellow", "", "Damage window cleared.")
end

function toggle_main_echo(name, line, wildcards)
    output_to_main = not output_to_main
    if output_to_main then
        ColourNote("yellow", "", "Damage window output will echo to main window.")
    else
        ColourNote("yellow", "", "Damage window output will only appear in miniwindow.")
    end
    SaveState()
end

-- =============================================================================
-- Alias Handlers - Configuration
-- =============================================================================
function display_spamreduce_option()
    ColourNote("silver", "", "COMBINE      Type 'spamreduce combine' for list of options")
end

function spamreduce_list()
    ColourNote("teal", "", "Option       Description                                      Status")
    ColourNote("silver", "", "---------------- ------------------------------------------------ ------")
    for option, info in pairs(options) do
        ColourTell("silver", "", string.format("%-16s %-49s", string.upper(option), info.desc))
        if GetVariable(option) == "true" then
            ColourTell("#a6da95", "", "Yes")
        else
            ColourTell("#f38ba8", "", "No")
        end
        Note()

        if option == "combat" and GetVariable(option) == "true" then
            ColourTell("silver", "", string.format("%-16s %-49s", string.upper("COMBAT OTHERS"), "Display others' damage (hide/list/full)"))
            ColourTell("yellow", "", upper_first(GetVariable(VAR_COMBAT_OTHERS) or "full"))
            Note()

            ColourTell("silver", "", string.format("%-16s %-49s", string.upper("COMBAT PRESERVE"), "Display non-damage lines in combat"))
            if GetVariable(VAR_PRESERVE) == "true" then
                ColourTell("#a6da95", "", "Yes")
            else
                ColourTell("#f38ba8", "", "No")
            end
            Note()
        end

        if option == "death" and GetVariable(option) == "true" then
            ColourTell("silver", "", string.format("%-16s %-49s", string.upper("DEATH SIMPLE"), "Simplified output (X exp. Y gold)"))
            if GetVariable(VAR_DEATH_SIMPLE) == "true" then
                ColourTell("#a6da95", "", "Yes")
            else
                ColourTell("#f38ba8", "", "No")
            end
            Note()
        end
    end
    ColourNote("silver", "", "---------------------------------------------------------------------")
end

function toggle_var(name, line, wc)
    local option = wc[1]
    if options[option] then
        toggle_group(option)
    else
        ColourNote("silver", "", "Invalid spam combine option given. Type 'spamreduce combine' for a list.")
    end
end

function spamreduce_combat_preserve()
    ColourTell("silver", "", "Turning ")
    if GetVariable(VAR_PRESERVE) == "true" then
        ColourTell("#f38ba8", "", "OFF")
        SetVariable(VAR_PRESERVE, "false")
    else
        ColourTell("#a6da95", "", "ON")
        SetVariable(VAR_PRESERVE, "true")
    end

    ColourTell("silver", "", " combat setting to preserve non-damage lines.")
    Note()
    SaveState()
end

function spamreduce_death_simple()
    ColourTell("silver", "", "Turning ")
    if GetVariable(VAR_DEATH_SIMPLE) == "true" then
        ColourTell("#f38ba8", "", "OFF")
        SetVariable(VAR_DEATH_SIMPLE, "false")
    else
        ColourTell("#a6da95", "", "ON")
        SetVariable(VAR_DEATH_SIMPLE, "true")
    end

    ColourTell("silver", "", " simplified death output (X exp. Y gold).")
    Note()
    SaveState()
end

function spamreduce_bonusexp()
    ColourTell("silver", "", "Turning ")
    if GetVariable(VAR_BONUSEXP_PCT) == "true" then
        ColourTell("#f38ba8", "", "OFF")
        SetVariable(VAR_BONUSEXP_PCT, "false")
    else
        ColourTell("#a6da95", "", "ON")
        SetVariable(VAR_BONUSEXP_PCT, "true")
    end

    ColourTell("silver", "", " bonus exp percentages.")
    Note()
    SaveState()
end

function spamreduce_combat_others(name, line, wc)
    if wc[1] == "hide" or wc[1] == "list" or wc[1] == "full" then
        set_other(wc[1])
    else
        ColourTell("silver", "", "Valid options for ")
        ColourTell("olive", "", "spamreduce combine combat others")
        ColourTell("silver", "", ": ")
        ColourTell("yellow", "", "hide list full")
        Note()
    end
end

function set_other(value)
    ColourTell("silver", "", "Display third party combat : ")
    ColourTell("yellow", "", value)
    Note()

    SetVariable(VAR_COMBAT_OTHERS, value)
    SaveState()
end

-- =============================================================================
-- Alias Handlers - Trigger Management
-- =============================================================================
function spamreduce_trigger(name, line, wc)
    local trigger = wc[1]
    local group = GetTriggerOption(trigger, "group")
    if group and group ~= "" then
        if trigger_overrides[trigger] then
            ColourNote("#a6da95", "", "Enabling trigger: " .. trigger)
            trigger_overrides[trigger] = nil
        else
            ColourNote("#f38ba8", "", "Disabling trigger: " .. trigger)
            trigger_overrides[trigger] = true
        end
        SetVariable(VAR_TRIGGER_OVERRIDES, json.encode(trigger_overrides))
        group = remove_from_end(group, "_conditional")
        enable_group(group, GetVariable(group) == "true")
        SaveState()
    else
        ColourNote("#f38ba8", "", "No such trigger: " .. trigger)
    end
end

function spamreduce_triggers_all()
    ColourNote("yellow", "", "All triggers:")
    display_triggers(GetTriggerList())
end

function spamreduce_triggers_search(name, line, wc)
    local search = string.lower(wc[1])
    local matches = {}

    for _, name in pairs(GetTriggerList()) do
        local match_str = GetTriggerOption(name, "match")
        if string.find(string.lower(name), search, 1, true) or (match_str and string.find(string.lower(match_str), search, 1, true)) then
            table.insert(matches, name)
        end
    end

    if #matches > 0 then
        ColourNote("yellow", "", "Triggers matching '" .. search .. "':")
        display_triggers(matches)
    else
        ColourNote("#f38ba8", "", "No triggers matched '" .. search .. "'")
    end
end

function display_triggers(triggers)
    local groups = {}
    for _, trigger in pairs(triggers) do
        local group = GetTriggerOption(trigger, "group")
        group = remove_from_end(group, "_conditional")
        groups[group] = groups[group] or {}

        table.insert(groups[group], trigger)
    end

    for name, triggers in pairs(groups) do
        ColourNote("white", "", "Group: " .. name)

        table.sort(triggers)
        for _, trigger in ipairs(triggers) do
            ColourTell("silver", "", string.format("%-35s", trigger))
            if trigger_overrides[trigger] then
                ColourTell("#f38ba8", "", "Off ")
            else
                ColourTell("#a6da95", "", "On  ")
            end
            local match_str = GetTriggerOption(trigger, "match")
            if match_str then
                ColourTell("silver", "", string.format("%-40.40s", match_str))
            end
            Note()
        end
    end
end

-- =============================================================================
-- Tag Suppression System
-- =============================================================================
local SuppressAllSequence = 12
local HeaderSequence = 13
local FooterSequence = 11

local suppress_trigger_index = 0
local suppress_triggers_headers = {}

local function regex_escape_line(str)
    return "^" .. str:gsub("([%(%)%.%+%-%*%?%[%^%$])", "\\%1") .. "$"
end

function suppress_triggers_for_all_tags()
    suppress_triggers_between_tags("<MAPSTART>", "<MAPEND>")
    suppress_triggers_between_tags("{BIGMAP}", "{/BIGMAP}")
    suppress_triggers_between_tags("{edit}", "{/edit}")
    suppress_triggers_between_tags("{equip}", "{/equip}")
    suppress_triggers_between_tags("{help}", "{/help}")
    suppress_triggers_between_tags("{inventory}", "{/inventory}")
    suppress_triggers_between_tags("{rdesc}", "{/rdesc}")
    suppress_triggers_between_tags("{score}", "{/score}")
    suppress_triggers_between_tags("{roomchars}", "{/roomchars}")
    suppress_triggers_between_tags("{scan}", "{/scan}")
end

function suppress_triggers_between_tags(header, footer)
    suppress_trigger_index = suppress_trigger_index + 1

    local match = GetTriggerOption("suppress_triggers_header", "match")
    if match then
        local combined = match .. "|" .. regex_escape_line(header)
        SetTriggerOption("suppress_triggers_header", "match", combined)
    else
        AddTriggerEx("suppress_triggers_header", regex_escape_line(header), "", trigger_flag.Enabled + trigger_flag.Replace + trigger_flag.RegularExpression + trigger_flag.Temporary, -1, 0, "", "suppress_triggers_header", 0, HeaderSequence)
    end

    AddTriggerEx("suppress_all_triggers", "*", "", trigger_flag.Replace + trigger_flag.Temporary, -1, 0, "", "", 0, SuppressAllSequence)

    local footer_name = "suppress_triggers_footer_" .. suppress_trigger_index
    AddTriggerEx(footer_name, regex_escape_line(footer), "", trigger_flag.Replace + trigger_flag.RegularExpression + trigger_flag.Temporary, -1, 0, "", "suppress_triggers_footer", 0, FooterSequence)

    suppress_triggers_headers[header] = {
        footer = footer,
        footer_name = footer_name,
    }
end

function suppress_triggers_header(name, line)
    local data = suppress_triggers_headers[line]

    if not data then
        ColourNote("#f38ba8", "", "Error suppressing triggers. Invalid header line: " .. line)
        EnableTrigger("suppress_all_triggers", false)
        return
    end

    EnableTrigger(data.footer_name, true)
    EnableTrigger("suppress_all_triggers", true)
    EnableTrigger("suppress_triggers_header", false)
end

function suppress_triggers_footer(name)
    EnableTrigger(name, false)
    EnableTrigger("suppress_all_triggers", false)
    EnableTrigger("suppress_triggers_header", true)
end
