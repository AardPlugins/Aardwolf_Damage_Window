-- aard_damage_window_init.lua
-- Bootstrap file - loaded first by XML
-- Defines shared utilities and loads modules in order

-- =============================================================================
-- Dependencies
-- =============================================================================
dofile(GetInfo(60) .. "aardwolf_colors.lua")
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

function Message(str)
    AnsiNote(stylesToANSI(ColoursToStyles(string.format(
        "\n@C[@YDamageTracker@C]@w %s\n", str))))
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
-- Combat Spam Patterns (for dynamic battlespam trigger)
-- Each pattern is a complete regex matching one type of spam message
-- =============================================================================
combat_spam_patterns = {
    -- Healing/restoration
    "^You feel less tired after .* refreshing spell\\. \\[\\d+\\]$",
    "^[\\w ']+ heals .*self\\.$",
    "^[\\w ']+ restores? life to .*self\\.$",
    "^[\\w ']+ touch of nature heals .* wounds\\.$",
    "^Protector Golem has repaired itself\\.$",
    "^Protector Golem begins to repair itself\\.$",

    -- Poison/debuff effects
    "^As .* a spray of toxic blood hits your eyes!$",
    "^Unseen forces remove .* poison from you before it can take hold\\.$",
    "^Acidic poison severely impairs your senses\\.$",
    "^The venom destroys your combat ability\\. You feel dizzy\\.$",
    "^The stench is incredible, you feel faint and weak!$",
    "^[\\w ']+ chokes as .* breathes in the poison\\.$",
    "^[\\w ']+ is poisoned by the venom on .*\\.$",
    "^[\\w ']+ forms a deadly cloud of poison\\.$",
    "^You feel momentarily ill, but it passes\\.$",
    "^A green mist emanates from .*\\. The mist surrounds you\\.$",
    "^A green mist emanates from .* towards .*\\.$",
    "^[\\w ']+ poison tears at .* skin, .* eyes stream in agony\\.$",
    "^[\\w ']+ uses the power of the cobra against .*\\.$",

    -- Blindness/vision
    "^You can't see a thing!$",
    "^You are weak and BLIND!$",
    "^[\\w ']+ kicks? dirt in .* eyes!$",
    "^[\\w ']+ failed to kick dirt into .* eyes!$",
    "^[\\w ']+ jams .* fingers into .* eyes, causing .* searing pain\\.$",
    "^[\\w ']+ eyes are seared by .*\\.$",
    "^[\\w ']+ fails? to blind .*\\.$",

    -- Stun/daze effects
    "^[\\w ']+ dazes? .*, slamming into .* like a tank\\.$",
    "^[\\w ']+ hits? .* with a massive blow, leaving .* stunned!$",
    "^[\\w ']+ dazes? .* with a mind-numbing headbutt!$",
    "^[\\w ']+ fails? to stun .* and .* in an attack!$",
    "^[\\w ']+ slams .* head sideways into .*\\. OUCH! That smarts!$",
    "^[\\w ']+ smacks? .* with a solid uppercut!$",

    -- Curse/hex/debuff failures
    "^[\\w ']+ fails to curse .*\\.$",
    "^[\\w ']+ fails to hex .*!$",
    "^[\\w ']+ fails to weaken .*\\.$",
    "^[\\w ']+ fails? to interfere with .* healing\\.$",
    "^[\\w ']+ tries to slow .* down but fails\\.$",

    -- Web/entangle
    "^[\\w ']+ entangled in an invisible web\\.$",
    "^[\\w ']+ web fails to take hold of .*\\.$",
    "^Unseen forces protect you from (.*?) tangling web\\.$",

    -- Drain/life steal
    "^[\\w ']+ drains? life from .*\\.$",
    "^You feel your blood being drained!$",
    "^You feel .* drawing your life away\\.$",
    "^It tears at your existence and you feel extremely vulnerable\\.$",
    "^[\\w ']+ slime tears at .* soul!$",

    -- Strength/stat drain
    "^You feel your strength slip away\\.$",
    "^You feel a little run down, but it passes\\.$",
    "^[\\w ']+ muscles stop responding\\.$",

    -- Combat skill effects - bash/knockdown
    "^[\\w ']+ sends? .* sprawling with a powerful bash!$",
    "^[\\w ']+ sweeps your legs from under you!$",
    "^[\\w ']+ hurls .* at .*, slamming into .* like a tank\\.$",

    -- Combat skill effects - disarm
    "^[\\w ']+(try|tries) to disarm .*, but fails?\\.$",
    "^Your power grip is too strong for .*\\.$",

    -- Combat skill effects - backstab
    "^[\\w ']+ reappears behind .* and stabs .* in the back!$",
    "^[\\w ']+ circles around .* and stabs .* in the back!$",
    "^You attempt to bury .* deep into .* back!$",
    "^\\w+ attempts to bury .* deep into .*$",
    "^[\\w ']+ spins around .*, catching .* off guard, and executes a vicious triple backstab\\.$",

    -- Combat skill effects - whirlwind/spin
    "^[\\w ']+ begins to spin around, flailing wildly\\.$",
    "^[\\w ']+ begins to spin around with .* weapon outstretched\\.$",
    "^You stretch out your weapon and begin to spin violently!$",
    "^[\\w ']+ with a series of hammering blows!$",
    "^[\\w ']+ hammers? .* with a series of blows!$",

    -- Combat skill effects - other
    "^[\\w ']+ catch(es)? .* completely off-guard and inflicts? massive damage on .*\\.$",
    "^[\\w ']+ screams? wildly and attacks? .*\\.$",
    "^[\\w ']+ screams? wildly and (try|tries) to cleave .* in half!$",
    "^[\\w ']+ gets? a raged look in .* eyes\\.$",
    "^[\\w ']+ gets a wild look in .* eyes\\.$",

    -- Spell/magic effects
    "^As you land a final blow on .*, the raw energy it contains runs out of control, blasting the room!$",
    "^[\\w ']+ hurls? a barrage of searing white blades at .*!$",
    "^A black field of death emanates from .*\\.$",
    "^A deep aura of dread settles around .*\\.$",
    "^[\\w ']+ shoots? .* beam from .* hand straight towards .*!$",
    "^[\\w ']+ calls down rains of fire!$",
    "^[\\w ']+ conjures? a storm of freezing snow and sleet\\.$",
    "^[\\w ']+ a chilling cloud of ice\\.$",
    "^[\\w ']+ chants the phrase '.*'\\.$",
    "^[\\w ']+ calls the justice of .* to strike .* foes!$",
    "^[\\w ']+ unleashes a blast of atomic energy on the room\\.$",
    "^Your head throbs as your reality is torn apart!$",

    -- Fire/ice/shock effects
    "^[\\w ']+ is frozen by .*\\.$",
    "^You are frozen by .*\\.$",
    "^[\\w ']+ turns blue and shivers\\.$",
    "^[\\w ']+ is burned by .*\\.$",
    "^[\\w ']+ is shocked by .*\\.$",
    "^You are shocked by .*\\.$",
    "^You feel a brief tingling sensation\\.$",
    "^You feel a momentary chill on your neck\\.$",

    -- Breath attacks
    "^\\* breathes forth a huge blast of fire\\.$",
    "^(.*?) breathes forth a huge blast of fire\\.$",

    -- Bite/vampire
    "^[\\w ']+ bites .* on .* neck\\.$",
    "^[\\w ']+ flesh is ripped from .* body\\.$",

    -- KAI-HA attacks
    "^[\\w ']+ raises .* and starts yelling KAI-HA!$",
    "^[\\w ']+ yells KAI-HA and then strikes .* torso\\.$",

    -- Shield/reflect
    "^[\\w ']+ spirit shield reflects .* back at .*!$",
    "^You glow with energy as you absorb .*\\.$",

    -- Root/nature
    "^[\\w ']+ black root smashes into you and you lose control of your senses\\.$",

    -- Kobold/venom items
    "^[\\w ']+ sprays .* with .*Kobold glands\\.$",
    "^[\\w ']+ sprays .* with acidic raven venom\\.$",
    "^[\\w ']+ touches .* with venomous hydra's blood\\.$",

    -- Mob dialogue
    "^[\\w ']+ exclaims? 'Your level is of no interest to me .*; I will kill you anyway!'$",
    "^[\\w ']+ says? 'Your purity sickens me, .*\\.'$",

    -- Defend/intercept
    "^\\* jumps? in to defend .*!$",
    "^You block .* way as .* attempts? to flee\\.$",

    -- Disappear/teleport
    "^Suddenly, after performing an incantation, .* disappears\\.$",
    "^[\\w ']+ shimmers momentarily\\.$",

    -- Player dodges/avoids (enemy attacks you)
    "^You dodge .* attack\\.$",
    "^You parry .* attack\\.$",
    "^You instinctively dodge .* attack\\.$",
    "^You counter-strike .* attack!$",
    "^You misdirect .* attack\\.$",
    "^You get lucky and manage to escape .* attack\\.$",
    "^You create a time shift and calmly step away from .* attack\\.$",
    "^You blink out of existence and avoid .* attack\\.$",
    "^You blend perfectly with your surroundings and avoid .* attack\\.$",
    "^You sense divine intervention as .* attack narrowly misses you\\.$",
    "^You are unaffected by .* dispel .*\\.$",
    "^[\\w ']+ holy rift protects you from .* attack\\.$",

    -- Mob dodges/avoids (you attack mob)
    "^[\\w ']+ dodges? your attack\\.$",
    "^[\\w ']+ parries your attack\\.$",
    "^[\\w ']+ counter-strikes your attack!$",
    "^[\\w ']+ misdirects your attack\\.$",
    "^[\\w ']+ avoids your attack, almost too easily\\.$",
    "^[\\w ']+ blocks your attack with .* shield\\.$",
    "^[\\w ']+ blends in perfectly causing .* to hit nothing but air\\.$",
    "^[\\w ']+ blinks out of existence avoiding your attack\\.$",
    "^[\\w ']+ fiddles with time and your attack is just a few seconds slow\\.$",
    "^[\\w ']+ holy rift protects .* from your attack\\.$",

    -- Pet/familiar attacks
    "^You slash at .* ferociously with your razor-sharp claws!$",
    "^You lunge forward gnashing at .* viciously\\.$",
    "^You spitefully bite (.*?) as if (.*?) tried to pet you more than three times\\.$",
    "^[\\w ']+ tries to jump into the air, realizes .* is already flying, and kicks .* in the face instead!$",

    -- Other player actions
    "^\\w+ sacrifices .* corpse .*$",
    "^With a series of lashes, .*$",
    "^\\w+ charges into the room in a frenzy!$",
    "^\\w+ makes .* skinned from .*\\.$",
    "^\\w+ drops .* skinned from .*\\.$",
    "^.* skinned from .* crumbles into dust\\.$",
}

function combat_spam_regex()
    return table.concat(combat_spam_patterns, "|")
end

-- =============================================================================
-- Load Modules in Order
-- =============================================================================
local plugin_dir = GetPluginInfo(GetPluginID(), 20)

dofile(plugin_dir .. "aardwolf_damage_window_core.lua")
dofile(plugin_dir .. "aardwolf_damage_window_window.lua")
dofile(plugin_dir .. "aardwolf_damage_window_handlers.lua")

-- Initialization message
info("Damage Tracker loaded")
