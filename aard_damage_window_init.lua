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

-- =============================================================================
-- Constants
-- =============================================================================
PLUGIN_VERSION = "3.0"

-- Plugin IDs for inter-plugin communication
plugin_id_gmcp_handler = "3e7dedbe37e44942dd46d264"
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
    ColourNote("lime", "", "[DamageTracker] " .. msg)
end

function debug_log(msg)
    if debug_enabled then
        ColourNote("orange", "", "[DamageTracker Debug] " .. msg)
    end
end

-- =============================================================================
-- Helper Functions (shared across modules)
-- =============================================================================
function starts_with(a, b)
    return string.sub(a, 1, string.len(b)) == b
end

function ends_with(a, b)
    return string.sub(a, string.len(a)-string.len(b)+1, string.len(a)) == b
end

function upper_first(name)
    return string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
end

-- Format number with commas for readability
function format_number(n)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

-- =============================================================================
-- Damage Verb Table (for dynamic combat regex)
-- =============================================================================
damage_verbs = {
    "misses",
    "tickles",
    "bruises",
    "scratches",
    "grazes",
    "nicks",
    "scars",
    "hits",
    "injures",
    "wounds",
    "mauls",
    "maims",
    "mangles",
    "mars",
    "LACERATES",
    "DECIMATES",
    "DEVASTATES",
    "ERADICATES",
    "OBLITERATES",
    "EXTIRPATES",
    "INCINERATES",
    "MUTILATES",
    "DISEMBOWELS",
    "MASSACRES",
    "DISMEMBERS",
    "RENDS",
    "- BLASTS -",
    "-= DEMOLISHES =-",
    "** SHREDS **",
    "**** DESTROYS ****",
    "***** PULVERIZES *****",
    "-=- VAPORIZES -=-",
    "<-==-> ATOMIZES <-==->",
    "<-:-> ASPHYXIATES <-:->",
    "<-*-> RAVAGES <-*->",
    "<>*<> FISSURES <>*<>",
    "<*><*> LIQUIDATES <*><*>",
    "<*><*><*> EVAPORATES <*><*><*>",
    "<-=-> SUNDERS <-=->",
    "<=-=><=-=> TEARS INTO <=-=><=-=>",
    "<->*<=> WASTES <=>*<->",
    "<-+-><-*-> CREMATES <-*-><-+->",
    "<*><*><*><*> ANNIHILATES <*><*><*><*>",
    "<--*--><--*--> IMPLODES <--*--><--*-->",
    "<-><-=-><-> EXTERMINATES <-><-=-><->",
    "<-==-><-==-> SHATTERS <-==-><-==->",
    "<*><-:-><*> SLAUGHTERS <*><-:-><*>",
    "<-*-><-><-*-> RUPTURES <-*-><-><-*->",
    "<-*-><*><-*-> NUKES <-*-><*><-*->",
    "-<[=-+-=]<:::<>:::> GLACIATES <:::<>:::>[=-+-=]>-",
    "<-=-><-:-*-:-><*--*> METEORITES <*--*><-:-*-:-><-=->",
    "<-:-><-:-*-:-><-*-> SUPERNOVAS <-*-><-:-*-:-><-:->",
    "does UNSPEAKABLE things to",
    "does UNTHINKABLE things to",
    "does UNIMAGINABLE things to",
    "does UNBELIEVABLE things to",
    "lacerates",
    "decimates",
    "devastates",
    "eradicates",
    "obliterates",
    "extirpates",
    "incinerates",
    "mutilates",
    "disembowels",
    "massacres",
    "dismembers",
    "rends",
    "blasts",
    "demolishes",
    "shreds",
    "destroys",
    "pulverizes",
    "vaporizes",
    "atomizes",
    "asphyxiates",
    "ravages",
    "fissures",
    "liquidates",
    "evaporates",
    "sunders",
    "tears into",
    "wastes",
    "cremates",
    "annihilates",
    "implodes",
    "exterminates",
    "shatters",
    "slaughters",
    "ruptures",
    "nukes",
    "glaciates",
    "meteorites",
    "supernovas",
    "does unspeakable things to",
    "does unthinkable things to",
    "does unimaginable things to",
    "does unbelievable things to",
}

-- =============================================================================
-- Regex Helpers (for dynamic combat trigger)
-- =============================================================================
function regex_escape_string(s)
    local e = ""
    for i = 1, string.len(s) do
        local c = string.sub(s, i, i)
        if regex_special_character(c) then
            e = e .. "\\" .. c
        else
            e = e .. c
        end
    end
    return e
end

function regex_special_character(c)
    local special_chars = "[\\^$.|?*+()"
    for i = 1, string.len(special_chars) do
        if c == string.sub(special_chars, i, i) then
            return true
        end
    end
    return false
end

function damage_verb_regex()
    local regex = ""
    for i, verb in ipairs(damage_verbs) do
        if i > 1 then
            regex = regex .. "|"
        end
        regex = regex .. regex_escape_string(verb)
    end
    return regex
end

function get_damage_regex()
    return string.format(
        "^(\\*?)(?:\\[(\\d+)\\] )?(Your|(?:.*(?:'s|s'))?) (.*)? (?:%s) (.*)[\\.!] \\[(\\d+)\\]\\*?$",
        damage_verb_regex()
    )
end

-- =============================================================================
-- Load Modules in Order
-- =============================================================================
local plugin_dir = GetPluginInfo(GetPluginID(), 20)

dofile(plugin_dir .. "aard_damage_window_core.lua")
dofile(plugin_dir .. "aard_damage_window_window.lua")
dofile(plugin_dir .. "aard_damage_window_handlers.lua")

-- Initialization message
info("Damage Tracker v" .. PLUGIN_VERSION .. " loaded")
