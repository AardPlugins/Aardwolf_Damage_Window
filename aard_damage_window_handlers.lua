-- aard_damage_window_handlers.lua
-- All alias/trigger/plugin callbacks (MUST be global for MUSHclient)

-- =============================================================================
-- Plugin Lifecycle Callbacks
-- =============================================================================
function OnPluginInstall()
    load_state()

    -- Create combat damage trigger dynamically
    -- Use the correct MUSHclient constants (eOmitFromOutput, eTriggerRegularExpression, eEnabled)
    local flags = eOmitFromOutput + eTriggerRegularExpression + eEnabled
    AddTrigger("combat_damage", get_damage_regex(), "",
        flags, -1, 0, "", "track", 0, 100)

    -- Apply echo mode to all triggers
    set_echo_mode(echo_enabled)

    -- Apply battlespam mode
    set_battlespam_mode(battlespam_enabled)

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
-- Main Trigger Handler
-- =============================================================================
function track(name, line, wc)
    local bucket = get_current_bucket()
    if not bucket then return end

    if name == "combat_damage" then
        local attacker = wc[3] or ""
        local defender = wc[5] or ""
        local damage = tonumber(wc[6]) or 0

        -- Normalize to lowercase for case-insensitive comparison
        local attacker_lower = string.lower(attacker)
        local defender_lower = string.lower(defender)

        -- Debug output
        if debug_enabled then
            ColourNote("orange", "", string.format("[DEBUG] attacker='%s' defender='%s' damage=%d",
                attacker, defender, damage))
        end

        if attacker_lower == "your" then
            bucket.given = bucket.given + damage
            if debug_enabled then
                ColourNote("lime", "", string.format("[DEBUG] +%d given (total: %d)", damage, bucket.given))
            end
        elseif defender_lower == "you" then
            bucket.taken = bucket.taken + damage
            if debug_enabled then
                ColourNote("red", "", string.format("[DEBUG] +%d taken (total: %d)", damage, bucket.taken))
            end
        else
            if debug_enabled then
                ColourNote("gray", "", "[DEBUG] Ignored third-party damage")
            end
        end
        -- Ignore third-party damage (neither attacker nor defender is player)

    elseif starts_with(name, "death_mob_") then
        bucket.kills = bucket.kills + 1

    elseif name == "death_exp" then
        local exp_str = wc[2] or "0"
        for amt in string.gmatch(exp_str, "%d+") do
            bucket.exp = bucket.exp + (tonumber(amt) or 0)
        end

    elseif name == "death_gold" or name == "death_gold_daily" then
        bucket.gold = bucket.gold + parse_gold(wc[1])

    elseif name == "death_sacrifice" then
        bucket.gold = bucket.gold + parse_gold(wc[2])

    elseif name == "death_split" or name == "death_other_split" then
        bucket.gold = bucket.gold + parse_gold(wc[4])

    elseif name == "death_crumble" then
        bucket.gold = bucket.gold + parse_gold(wc[2])
    end

    refresh_display()
end

-- Handler for spam triggers (does nothing - just used for omit control)
function spam_ignore(name, line, wc)
    -- Lines are shown/hidden via omit_from_output setting
end

-- Parse gold string, removing commas
function parse_gold(s)
    if not s then return 0 end
    local clean = s:gsub(",", "")
    return tonumber(clean) or 0
end

-- =============================================================================
-- Timer Callback
-- =============================================================================
function on_battle_tick()
    rotate_bucket()
    refresh_display()
end

-- =============================================================================
-- Alias Handlers
-- =============================================================================
function dt_show(name, line, wildcards)
    WindowShow(win, true)
    ColourNote("yellow", "", "Damage tracker window shown. Type 'dt hide' to hide it.")
end

function dt_hide(name, line, wildcards)
    WindowShow(win, false)
    ColourNote("yellow", "", "Damage tracker window hidden. Type 'dt show' to see it again.")
end

function dt_echo(name, line, wildcards)
    echo_enabled = not echo_enabled
    set_echo_mode(echo_enabled)
    if echo_enabled then
        ColourNote("yellow", "", "Echo mode ON - original combat/death lines will show in main window.")
    else
        ColourNote("yellow", "", "Echo mode OFF - combat/death lines are hidden (stats only in tracker).")
    end
    SaveState()
end

function dt_reset(name, line, wildcards)
    reset_all_buckets()
    refresh_display()
    ColourNote("yellow", "", "Damage tracker stats reset.")
end

function dt_ticks(name, line, wildcards)
    local new_count = tonumber(wildcards[1])
    if not new_count then
        ColourNote("silver", "", "Current round count: " .. NUM_BUCKETS)
        ColourNote("silver", "", "Usage: dt ticks <number> (1-100)")
        return
    end

    if new_count < 1 then new_count = 1 end
    if new_count > 100 then new_count = 100 end

    NUM_BUCKETS = new_count
    reset_all_buckets()
    refresh_display()
    SaveState()
    ColourNote("yellow", "", "Now tracking last " .. NUM_BUCKETS .. " rounds (stats reset).")
end

function dt_battlespam(name, line, wildcards)
    battlespam_enabled = not battlespam_enabled
    set_battlespam_mode(battlespam_enabled)
    if battlespam_enabled then
        ColourNote("yellow", "", "Battle spam ON - combat effect messages will show.")
    else
        ColourNote("yellow", "", "Battle spam OFF - combat effect messages hidden.")
    end
    SaveState()
end

function dt_debug(name, line, wildcards)
    debug_enabled = not debug_enabled
    if debug_enabled then
        ColourNote("orange", "", "Debug mode ON - will show trigger capture details.")
    else
        ColourNote("orange", "", "Debug mode OFF.")
    end
    SaveState()
end

-- =============================================================================
-- Echo Mode Control
-- =============================================================================
-- List of all triggers that should have omit_from_output toggled
local tracked_triggers = {
    "combat_damage",
    "death_mob_mind", "death_mob_drain", "death_mob_pale", "death_mob_acid",
    "death_mob_holy", "death_mob_fire", "death_mob_water", "death_mob_earth",
    "death_mob_lightning", "death_mob_god", "death_mob_mindforce",
    "death_mob_desolate", "death_mob_fabric", "death_mob_letsout",
    "death_mob_slain", "death_mob_dead",
    "death_exp",
    "death_gold", "death_gold_daily",
    "death_sacrifice",
    "death_split", "death_other_split",
    "death_crumble"
}

function set_echo_mode(enabled)
    local omit_value = enabled and "n" or "y"
    for _, trigger_name in ipairs(tracked_triggers) do
        -- Check if trigger exists before trying to set option
        local match = GetTriggerOption(trigger_name, "match")
        if match and match ~= "" then
            SetTriggerOption(trigger_name, "omit_from_output", omit_value)
        end
    end
end

-- =============================================================================
-- Battle Spam Control
-- =============================================================================
-- List of triggers for combat spam (effects, dodges, etc.)
local battlespam_triggers = {
    "combat_spam"
}

function set_battlespam_mode(enabled)
    local omit_value = enabled and "n" or "y"
    for _, trigger_name in ipairs(battlespam_triggers) do
        local match = GetTriggerOption(trigger_name, "match")
        if match and match ~= "" then
            SetTriggerOption(trigger_name, "omit_from_output", omit_value)
        end
    end
end
