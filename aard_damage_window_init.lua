-- aard_damage_window_init.lua
-- Bootstrap file - loaded first by XML
-- Defines shared utilities and loads modules in order

-- =============================================================================
-- Dependencies
-- =============================================================================
require("gmcphelper")
json = require("json")

require "mw_theme_base"
require "movewindow"
require "text_rect"
require "scrollbar"
require "serialize"

-- =============================================================================
-- Constants
-- =============================================================================
PLUGIN_VERSION = "2.0"
MAX_LINES = 1000

-- Plugin IDs for inter-plugin communication
plugin_id_gmcp_handler = "3e7dedbe37e44942dd46d264"
plugin_id_who = "1be8c97f04fa4558b6ba98a4"
plugin_id_repaint = "abc1a0944ae4af7586ce88dc"
plugin_id_lock = "c293f9e7f04dde889f65cb90"

-- =============================================================================
-- Shared State (global for cross-file access)
-- =============================================================================
debug_enabled = false
win = nil

-- =============================================================================
-- GMCP Helper (used by all modules)
-- =============================================================================
function gmcp(s)
    local ret, datastring = CallPlugin(plugin_id_gmcp_handler, "gmcpdata_as_string", s)
    if ret ~= 0 or datastring == nil then
        return nil
    end
    local data = nil
    pcall(function() data = loadstring("return " .. datastring)() end)
    return data
end

-- =============================================================================
-- Logging Utilities (used by all modules)
-- =============================================================================
function info(msg)
    ColourNote("lime", "", "[DamageWindow] " .. msg)
end

function debug_log(msg)
    if debug_enabled then
        ColourNote("orange", "", "[DamageWindow Debug] " .. msg)
    end
end

-- =============================================================================
-- Helper Functions (shared across modules)
-- =============================================================================
function starts_with(a, b)
    return string.sub(a, 1, string.len(b)) == b
end

function remove_from_start(a, b)
    if starts_with(a, b) then
        return string.sub(a, string.len(b)+1)
    else
        return a
    end
end

function ends_with(a, b)
    return string.sub(a, string.len(a)-string.len(b)+1, string.len(a)) == b
end

function remove_from_end(a, b)
    if ends_with(a, b) then
        return string.sub(a, 1, string.len(a)-string.len(b))
    else
        return a
    end
end

function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    if t[1] == nil then
        t[1] = ""
    end
    return t
end

function upper_first(name)
    return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
end

function remove_articles(name)
    local lower_name = string.lower(name)
    for _, article in pairs({"a ", "an ", "the "}) do
        if starts_with(lower_name, article) then
            return upper_first(string.sub(name, string.len(article)+1))
        end
    end
    return upper_first(name)
end

function style_run_sub(sr, first, last)
    local used = 0
    local ret = {}
    for _, run in ipairs(sr) do
        local l = string.len(run.text)
        local nextused = used + l
        if used < last and nextused >= first then
            local copy = {}
            for k, v in pairs(run) do
                copy[k] = v
            end

            if nextused > last then
                copy.text = string.sub(copy.text, 1, l - (nextused-last))
            end

            if used < first then
                copy.text = string.sub(copy.text, first - used)
            end

            table.insert(ret, copy)
        end
        used = nextused
    end
    return ret
end

function get_wildcard_sr(line, wc, sr, index)
    local p1, p2 = string.find(line, wc[index], 1, true)
    if not p1 or not p2 then
        return {}
    end
    return style_run_sub(sr, p1, p2)
end

function get_player_info(player_name)
    local success, player_info = CallPlugin(plugin_id_who, "get_who", player_name)
    if success == 0 and player_info then
        return json.decode(player_info)
    end
end

function get_line_info(line)
    line = line or GetLinesInBufferCount()-1
    local info = {}
    info.text = GetLineInfo(line, 1)
    info.is_note = GetLineInfo(line, 4)
    info.is_input = GetLineInfo(line, 5)
    info.sr = GetStyleInfo(line, 0)
    info.newline = GetLineInfo(line, 3)
    return info
end

function line_is_all_red(line_num)
    local info = get_line_info(line_num)
    if info and info.sr and #info.sr >= 1 and RGBColourToName(info.sr[1].textcolour) == "red" then
        if #info.sr == 2 and info.sr[2].text == "" then
            return true
        elseif #info.sr == 1 then
            return true
        end
    end
end

function is_newline(line_num)
    local info = get_line_info(line_num)
    return info and info.newline
end

function reload_plugin()
    if GetAlphaOption("script_prefix") == "" then
        SetAlphaOption("script_prefix", "\\\\\\")
    end
    Execute(
        GetAlphaOption("script_prefix") ..
        'DoAfterSpecial(0.5, "ReloadPlugin(\'' .. GetPluginID() .. '\')", sendto.script)'
    )
end

-- =============================================================================
-- Load Modules in Order
-- =============================================================================
local plugin_dir = GetPluginInfo(GetPluginID(), 20)

dofile(plugin_dir .. "aard_damage_window_core.lua")
dofile(plugin_dir .. "aard_damage_window_output.lua")
dofile(plugin_dir .. "aard_damage_window_window.lua")
dofile(plugin_dir .. "aard_damage_window_death.lua")
dofile(plugin_dir .. "aard_damage_window_combat.lua")
dofile(plugin_dir .. "aard_damage_window_misc.lua")
dofile(plugin_dir .. "aard_damage_window_handlers.lua")

-- Initialization message
info("Damage Window v" .. PLUGIN_VERSION .. " loaded")
