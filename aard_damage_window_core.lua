-- aard_damage_window_core.lua
-- Configuration, state management, and bucket system

-- =============================================================================
-- Configuration Defaults
-- =============================================================================
default_width = 200
default_height = 280
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
NUM_BUCKETS = 10  -- configurable, saved
current_bucket = 1
buckets = {}  -- array of {given=0, taken=0, exp=0, gold=0, kills=0}
echo_enabled = false  -- saved
battlespam_enabled = true  -- saved (true = show spam, false = hide)

-- =============================================================================
-- Persistence Variable Keys
-- =============================================================================
VAR_DEBUG = "debug_enabled"
VAR_WINDOW_WIDTH = "window_width"
VAR_WINDOW_HEIGHT = "window_height"
VAR_FONT_NAME = "font_name"
VAR_FONT_SIZE = "font_size"
VAR_NUM_BUCKETS = "num_buckets"
VAR_ECHO_ENABLED = "echo_enabled"
VAR_BATTLESPAM = "battlespam_enabled"

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
        kills = 0
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
        end
    end
    return totals
end

-- Reset all buckets to zero
function reset_all_buckets()
    init_buckets()
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

    -- Bucket settings
    NUM_BUCKETS = tonumber(GetVariable(VAR_NUM_BUCKETS)) or 10
    if NUM_BUCKETS < 1 then NUM_BUCKETS = 1 end
    if NUM_BUCKETS > 100 then NUM_BUCKETS = 100 end

    -- Echo mode
    echo_enabled = (GetVariable(VAR_ECHO_ENABLED) == "true")

    -- Battlespam mode (default true = show)
    local bs = GetVariable(VAR_BATTLESPAM)
    battlespam_enabled = (bs == nil) or (bs == "true")

    -- Initialize buckets
    init_buckets()
end

function save_state()
    SetVariable(VAR_DEBUG, tostring(debug_enabled))
    SetVariable(VAR_WINDOW_WIDTH, width)
    SetVariable(VAR_WINDOW_HEIGHT, height)
    SetVariable(VAR_FONT_NAME, font_name)
    SetVariable(VAR_FONT_SIZE, font_size)
    SetVariable(VAR_NUM_BUCKETS, NUM_BUCKETS)
    SetVariable(VAR_ECHO_ENABLED, tostring(echo_enabled))
    SetVariable(VAR_BATTLESPAM, tostring(battlespam_enabled))

    -- Save window position
    if win then
        movewindow.save_state(win)
    end
end
