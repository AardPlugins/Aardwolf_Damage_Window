-- aard_damage_window_core.lua
-- Configuration, state management, and bucket system

-- =============================================================================
-- Configuration Defaults
-- =============================================================================
default_width = 250
default_height = 175
default_x = 0
default_y = 300
default_font_name = "Courier New"
default_font_size = 12

-- =============================================================================
-- State Variables (global for cross-file access)
-- =============================================================================
width = nil
height = nil
font_name = nil
font_size = nil
startx = nil
starty = nil

windowinfo = nil
lastRefresh = 0

-- =============================================================================
-- Bucket System State
-- =============================================================================
BUCKETS_PER_ROUND = 3  -- 1-second buckets per 3-second round
NUM_ROUNDS = 20  -- user-facing rounds (3s each), configurable, saved
NUM_BUCKETS = NUM_ROUNDS * BUCKETS_PER_ROUND  -- actual 1-second buckets
current_bucket = 1
buckets = {}  -- array of {given=0, taken=0, exp=0, gold=0, kills=0, healed=0}
tick_counter = 0  -- counts 1-second ticks for round summary timing
echo_enabled = true  -- saved (default on: show tracked lines in main window)
battlespam_enabled = true  -- saved (true = show spam, false = hide)
summary_enabled = false  -- saved (round summary to main window)
layout_mode = "tabular"  -- saved (tabular, compact, classic)

-- =============================================================================
-- Session Totals (accumulate all stats since plugin load/reset)
-- =============================================================================
session_totals = {given=0, taken=0, exp=0, gold=0, kills=0, healed=0}
session_start = nil  -- os.time() when session started

-- =============================================================================
-- Persistence Variable Keys
-- =============================================================================
VAR_DEBUG = "debug_enabled"
VAR_WINDOW_WIDTH = "window_width"
VAR_WINDOW_HEIGHT = "window_height"
VAR_FONT_NAME = "font_name"
VAR_FONT_SIZE = "font_size"
VAR_NUM_ROUNDS = "num_buckets"  -- keep same key for backwards compatibility
VAR_ECHO_ENABLED = "echo_enabled"
VAR_BATTLESPAM = "battlespam_enabled"
VAR_SUMMARY_ENABLED = "summary_enabled"
VAR_LAYOUT_MODE = "layout_mode"

-- =============================================================================
-- Bucket Functions
-- =============================================================================

-- Create a new empty bucket
local function new_bucket()
    return {
        given = 0,
        taken = 0,
        exp = 0,
        gold = 0,
        kills = 0,
        healed = 0
    }
end

-- Initialize or reset all buckets
function init_buckets()
    buckets = {}
    for i = 1, NUM_BUCKETS do
        buckets[i] = new_bucket()
    end
    current_bucket = 1
end

-- Rotate to next bucket (called by timer)
function rotate_bucket()
    current_bucket = current_bucket + 1
    if current_bucket > NUM_BUCKETS then
        current_bucket = 1
    end
    -- Reset the new current bucket
    buckets[current_bucket] = new_bucket()
end

-- Get the current bucket for accumulating stats
function get_current_bucket()
    return buckets[current_bucket]
end

-- Get the previous bucket (completed tick) for display
function get_previous_bucket()
    local prev_index = current_bucket - 1
    if prev_index < 1 then
        prev_index = NUM_BUCKETS
    end
    return buckets[prev_index]
end

-- Sum the last n buckets including current (for real-time 3-second display)
function get_last_n_buckets(n)
    local totals = new_bucket()
    for i = 0, n - 1 do
        local idx = current_bucket - i
        if idx < 1 then idx = idx + NUM_BUCKETS end
        local b = buckets[idx]
        if b then
            totals.given = totals.given + b.given
            totals.taken = totals.taken + b.taken
            totals.exp = totals.exp + b.exp
            totals.gold = totals.gold + b.gold
            totals.kills = totals.kills + b.kills
            totals.healed = totals.healed + (b.healed or 0)
        end
    end
    return totals
end

-- Sum all buckets and return totals
function get_totals()
    local totals = new_bucket()
    for i = 1, NUM_BUCKETS do
        local b = buckets[i]
        if b then
            totals.given = totals.given + b.given
            totals.taken = totals.taken + b.taken
            totals.exp = totals.exp + b.exp
            totals.gold = totals.gold + b.gold
            totals.kills = totals.kills + b.kills
            totals.healed = totals.healed + (b.healed or 0)
        end
    end
    return totals
end

-- Reset all buckets to zero
function reset_all_buckets()
    init_buckets()
end

-- Reset session totals and start time
function reset_session()
    session_totals = {given=0, taken=0, exp=0, gold=0, kills=0, healed=0}
    session_start = os.time()
end

-- Add to session totals
function add_to_session(field, amount)
    if session_totals[field] then
        session_totals[field] = session_totals[field] + amount
    end
end

-- =============================================================================
-- State Management Functions
-- =============================================================================
function load_state()
    -- Debug mode
    debug_enabled = (GetVariable(VAR_DEBUG) == "true")

    -- Window dimensions
    width = tonumber(GetVariable(VAR_WINDOW_WIDTH)) or default_width
    height = tonumber(GetVariable(VAR_WINDOW_HEIGHT)) or default_height
    font_name = GetVariable(VAR_FONT_NAME) or default_font_name
    font_size = tonumber(GetVariable(VAR_FONT_SIZE)) or default_font_size

    -- Round settings (user-facing 3-second rounds)
    NUM_ROUNDS = tonumber(GetVariable(VAR_NUM_ROUNDS)) or 20
    if NUM_ROUNDS < 1 then NUM_ROUNDS = 1 end
    if NUM_ROUNDS > 300 then NUM_ROUNDS = 300 end
    NUM_BUCKETS = NUM_ROUNDS * BUCKETS_PER_ROUND

    -- Echo mode (default true = show tracked lines)
    local echo = GetVariable(VAR_ECHO_ENABLED)
    echo_enabled = (echo == nil) or (echo == "true")

    -- Battlespam mode (default true = show)
    local bs = GetVariable(VAR_BATTLESPAM)
    battlespam_enabled = (bs == nil) or (bs == "true")

    -- Summary mode
    summary_enabled = (GetVariable(VAR_SUMMARY_ENABLED) == "true")

    -- Layout mode (default tabular)
    local saved_layout = GetVariable(VAR_LAYOUT_MODE)
    if saved_layout == "compact" or saved_layout == "classic" then
        layout_mode = saved_layout
    else
        layout_mode = "tabular"
    end

    -- Initialize buckets
    init_buckets()
end

function save_state()
    SetVariable(VAR_DEBUG, tostring(debug_enabled))
    SetVariable(VAR_WINDOW_WIDTH, width)
    SetVariable(VAR_WINDOW_HEIGHT, height)
    SetVariable(VAR_FONT_NAME, font_name)
    SetVariable(VAR_FONT_SIZE, font_size)
    SetVariable(VAR_NUM_ROUNDS, NUM_ROUNDS)
    SetVariable(VAR_ECHO_ENABLED, tostring(echo_enabled))
    SetVariable(VAR_BATTLESPAM, tostring(battlespam_enabled))
    SetVariable(VAR_SUMMARY_ENABLED, tostring(summary_enabled))
    SetVariable(VAR_LAYOUT_MODE, layout_mode)

    -- Save window position
    if win then
        movewindow.save_state(win)
    end
end
