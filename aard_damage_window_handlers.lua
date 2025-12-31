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
-- Unified Alias Dispatcher
-- =============================================================================
function alias_dt(name, line, wildcards)
    local args = wildcards[1] or ""
    local parts = {}
    for word in args:gmatch("%S+") do
        table.insert(parts, word)
    end

    local cmd = parts[1] and parts[1]:lower() or "status"
    table.remove(parts, 1)

    if cmd == "help" then
        cmd_help()
    elseif cmd == "status" then
        cmd_status()
    elseif cmd == "show" then
        cmd_show()
    elseif cmd == "hide" then
        cmd_hide()
    elseif cmd == "echo" then
        cmd_echo(parts[1])
    elseif cmd == "reset" then
        cmd_reset()
    elseif cmd == "rounds" then
        cmd_rounds(parts[1])
    elseif cmd == "battlespam" then
        cmd_battlespam(parts[1])
    elseif cmd == "debug" then
        cmd_debug(parts[1])
    elseif cmd == "reload" then
        cmd_reload()
    else
        info("Unknown command: " .. cmd)
        cmd_help()
    end
end

-- =============================================================================
-- Command Handlers
-- =============================================================================
function cmd_help()
    Message([[@WCommands:@w

  @Ydt                       @w- Show plugin status
  @Ydt help                  @w- Show this help
  @Ydt status                @w- Show plugin status
  @Ydt show                  @w- Show tracker window
  @Ydt hide                  @w- Hide tracker window
  @Ydt echo @w[@Yon@w|@Yoff@w]          - Toggle/set echo mode
  @Ydt reset                 @w- Reset all stats to zero
  @Ydt rounds @w<@Yn@w>            - Set rounds to track (1-100)
  @Ydt battlespam @w[@Yon@w|@Yoff@w]   - Toggle combat spam
  @Ydt debug @w[@Yon@w|@Yoff@w]        - Toggle debug mode
  @Ydt reload                @w- Reload plugin]])
end

function cmd_status()
    local echo_str = echo_enabled and "@GYes" or "@RNo"
    local spam_str = battlespam_enabled and "@GYes" or "@RNo"
    local debug_str = debug_enabled and "@GYes" or "@RNo"
    local visible = win and WindowInfo(win, 5) and "@GVisible" or "@RHidden"
    local totals = get_totals()

    Message(string.format([[@WStatus:@w

  @WWindow:       @w(%s@w)
  @WRounds:       @w(@Y%d@w)
  @WEcho:         @w(%s@w)
  @WBattlespam:   @w(%s@w)
  @WDebug:        @w(%s@w)

  @W--- Session Totals ---@w
  @WGiven:        @G%s@w
  @WTaken:        @R%s@w
  @WGold:         @Y%s@w
  @WExp:          @Y%s@w
  @WKills:        @Y%s@w]],
    visible,
    NUM_BUCKETS,
    echo_str,
    spam_str,
    debug_str,
    format_number(totals.given),
    format_number(totals.taken),
    format_number(totals.gold),
    format_number(totals.exp),
    format_number(totals.kills)))
end

function cmd_show()
    WindowShow(win, true)
    ColourNote("yellow", "", "Damage tracker window shown. Type 'dt hide' to hide it.")
end

function cmd_hide()
    WindowShow(win, false)
    ColourNote("yellow", "", "Damage tracker window hidden. Type 'dt show' to see it again.")
end

function cmd_echo(toggle)
    if toggle == "on" then
        echo_enabled = true
    elseif toggle == "off" then
        echo_enabled = false
    else
        echo_enabled = not echo_enabled
    end
    set_echo_mode(echo_enabled)
    if echo_enabled then
        ColourNote("yellow", "", "Echo mode ON - original combat/death lines will show in main window.")
    else
        ColourNote("yellow", "", "Echo mode OFF - combat/death lines are hidden (stats only in tracker).")
    end
    SaveState()
end

function cmd_reset()
    reset_all_buckets()
    refresh_display()
    ColourNote("yellow", "", "Damage tracker stats reset.")
end

function cmd_rounds(n)
    local new_count = tonumber(n)
    if not new_count then
        ColourNote("silver", "", "Current round count: " .. NUM_BUCKETS)
        ColourNote("silver", "", "Usage: dt rounds <number> (1-100)")
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

function cmd_battlespam(toggle)
    if toggle == "on" then
        battlespam_enabled = true
    elseif toggle == "off" then
        battlespam_enabled = false
    else
        battlespam_enabled = not battlespam_enabled
    end
    set_battlespam_mode(battlespam_enabled)
    if battlespam_enabled then
        ColourNote("yellow", "", "Battle spam ON - combat effect messages will show.")
    else
        ColourNote("yellow", "", "Battle spam OFF - combat effect messages hidden.")
    end
    SaveState()
end

function cmd_debug(toggle)
    if toggle == "on" then
        debug_enabled = true
    elseif toggle == "off" then
        debug_enabled = false
    else
        debug_enabled = not debug_enabled
    end
    if debug_enabled then
        ColourNote("orange", "", "Debug mode ON - will show trigger capture details.")
    else
        ColourNote("orange", "", "Debug mode OFF.")
    end
    SaveState()
end

function cmd_reload()
    info("Reloading plugin...")
    if GetAlphaOption("script_prefix") == "" then
        SetAlphaOption("script_prefix", "\\\\\\")
    end
    Execute(
        GetAlphaOption("script_prefix") .. 'DoAfterSpecial(0.5, "ReloadPlugin(\'' .. GetPluginID() .. '\')", sendto.script)'
    )
end

-- =============================================================================
-- Context Menu Compatibility Wrappers
-- =============================================================================
function dt_echo()
    cmd_echo()
end

function dt_reset()
    cmd_reset()
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
