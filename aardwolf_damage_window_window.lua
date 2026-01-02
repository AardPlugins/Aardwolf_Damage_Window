-- aard_damage_window_window.lua
-- Miniwindow management with fixed stats display

-- =============================================================================
-- Window Colors
-- =============================================================================
local COLOR_LABEL = 0xC0C0C0   -- Silver for labels
local COLOR_VALUE = 0x00FF00   -- Green for values
local COLOR_HEADER = 0xFFFF00  -- Yellow for headers
local COLOR_GIVEN = 0x00FF00   -- Green for damage given
local COLOR_TAKEN = 0x5F5FFF   -- Red for damage taken (BGR format)
local COLOR_TAKEN_ZERO = 0xCC9966  -- Pastel blue for zero damage taken (BGR format)
local COLOR_SLASH = 0x808080   -- Gray for slash separator

-- =============================================================================
-- Layout Dimensions
-- =============================================================================
local layout_dimensions = {
    tabular = {width = 250, height = 175},
    compact = {width = 150, height = 125},
    classic = {width = 175, height = 330},
}

-- =============================================================================
-- Window Initialization
-- =============================================================================
function init_window()
    win = GetPluginID()

    -- Install Dina font if not present
    local fonts = utils.getfontfamilies()
    if not fonts.Dina then
        AddFont(GetInfo(66) .. "\\Dina.fon")
    end

    -- Create window with position from movewindow
    windowinfo = movewindow.install(win, miniwin.pos_top_right,
        miniwin.create_absolute_location, false, nil,
        {mouseup=MouseUp, mousedown=LeftClickOnly, dragmove=LeftClickOnly, dragrelease=LeftClickOnly},
        {x=default_x, y=default_y})

    WindowCreate(win, windowinfo.window_left, windowinfo.window_top,
        width, height, windowinfo.window_mode, windowinfo.window_flags,
        Theme.PRIMARY_BODY)

    setup_window_contents()
    refresh_display()
    WindowShow(win, true)
end

function setup_window_contents()
    -- Setup fonts - use Dina 6pt for title bar (matches Rich Exits)
    WindowFont(win, "title_font", "Dina", 6, false, false, false, false, 0)
    WindowFont(win, "stats_font", font_name, font_size, false, false, false, false, 0)
    WindowFont(win, "header_font", font_name, font_size, false, false, false, false, 0)

    -- Dress window with theme (title bar, border)
    Theme.DressWindow(win, "title_font", "Damage Tracker")

    -- Add resize handler
    Theme.AddResizeTag(win, 2, nil, nil, "MouseDown", "ResizeMoveCallback", "ResizeReleaseCallback")
end

-- =============================================================================
-- Stats Display
-- =============================================================================

-- Stat definitions for consistent ordering
local stats_order = {"given", "taken", "healed", "gold", "exp", "kills"}
local stats_labels = {
    given = "Given:",
    taken = "Taken:",
    healed = "Heals:",
    gold = "Gold:",
    exp = "XP:",
    kills = "Kills:"
}

-- Compact layout uses shorter labels
local stats_labels_compact = {
    given = "At:",
    taken = "Df:",
    healed = "Hp:",
    gold = "Gp:",
    exp = "XP:",
    kills = "Kil:"
}

-- Format number in K/M notation (e.g., 1100 -> 1.1K, 1100000 -> 1.1M)
-- At 100K+ and 100M+, drop the decimal to save width
local function format_number_short(n)
    if n >= 1000000 then
        local m = n / 1000000
        if m >= 100 or m == math.floor(m) then
            return string.format("%dM", math.floor(m))
        else
            return string.format("%.1fM", m)
        end
    elseif n >= 1000 then
        local k = n / 1000
        if k >= 100 or k == math.floor(k) then
            return string.format("%dK", math.floor(k))
        else
            return string.format("%.1fK", k)
        end
    else
        return tostring(n)
    end
end

-- Get color for a stat value
local function get_stat_color(stat_name, value)
    if stat_name == "given" then
        return COLOR_GIVEN
    elseif stat_name == "taken" then
        return value > 0 and COLOR_TAKEN or COLOR_TAKEN_ZERO
    else
        return COLOR_VALUE
    end
end

-- Draw a single stat line (label + value)
local function draw_stat_line(x, y, label_width, label, value, color)
    WindowText(win, "stats_font", label, x, y, 0, 0, COLOR_LABEL)
    WindowText(win, "stats_font", format_number(value), x + label_width, y, 0, 0, color)
end

-- =============================================================================
-- Layout: Classic (original two-section vertical)
-- =============================================================================
local function draw_classic(left, top, right, bottom)
    local line_height = WindowFontInfo(win, "stats_font", 1) + 2
    local x = left + 5
    local y = top + 5
    local label_width = 70

    local bucket = get_last_n_buckets(BUCKETS_PER_ROUND)
    local totals = get_totals()

    -- Draw "Last Round:" header
    WindowText(win, "header_font", "Last Round:", x, y, 0, 0, COLOR_HEADER)
    y = y + line_height + 2

    -- Current bucket stats
    for _, stat in ipairs(stats_order) do
        local value = bucket[stat] or 0
        draw_stat_line(x, y, label_width, stats_labels[stat], value, get_stat_color(stat, value))
        y = y + line_height
    end

    -- Spacer
    y = y + 12

    -- Draw "Last N Rounds:" header
    local header_text = "Last " .. NUM_ROUNDS .. " Rounds:"
    WindowText(win, "header_font", header_text, x, y, 0, 0, COLOR_HEADER)
    y = y + line_height + 2

    -- Totals
    for _, stat in ipairs(stats_order) do
        local value = totals[stat] or 0
        draw_stat_line(x, y, label_width, stats_labels[stat], value, get_stat_color(stat, value))
        y = y + line_height
    end
end

-- =============================================================================
-- Layout: Tabular (two columns with headers)
-- =============================================================================
local function draw_tabular(left, top, right, bottom)
    local line_height = WindowFontInfo(win, "stats_font", 1) + 2
    local x = left + 5
    local y = top + 5

    -- Calculate column positions based on available width
    local content_width = right - left - 10  -- 5px margin each side
    local label_width = 55                   -- Space for labels like "Heals:"
    local col1_x = x + label_width + 15      -- Round column (15px gap after label)
    local col_width = math.floor((content_width - label_width - 15) / 2)
    local col2_x = col1_x + col_width        -- Total column

    local bucket = get_last_n_buckets(BUCKETS_PER_ROUND)
    local totals = get_totals()

    -- Draw column headers
    WindowText(win, "header_font", "Now", col1_x, y, 0, 0, COLOR_HEADER)
    WindowText(win, "header_font", "Sum", col2_x, y, 0, 0, COLOR_HEADER)
    y = y + line_height + 2

    -- Draw stats rows
    for _, stat in ipairs(stats_order) do
        local round_val = bucket[stat] or 0
        local total_val = totals[stat] or 0

        -- Label (left-aligned)
        WindowText(win, "stats_font", stats_labels[stat], x, y, 0, 0, COLOR_LABEL)

        -- Round value (left-aligned in column)
        WindowText(win, "stats_font", format_number(round_val), col1_x, y, 0, 0, get_stat_color(stat, round_val))

        -- Total value (left-aligned in column)
        WindowText(win, "stats_font", format_number(total_val), col2_x, y, 0, 0, get_stat_color(stat, total_val))

        y = y + line_height
    end
end

-- =============================================================================
-- Layout: Compact (tabular without headers, K/M notation)
-- =============================================================================
local function draw_compact(left, top, right, bottom)
    local line_height = WindowFontInfo(win, "stats_font", 1) + 2
    local x = left + 5
    local y = top + 5

    -- Fixed column positions for tight layout
    local label_width = 25                   -- Short labels like "At:"
    local col_width = 50                     -- Fixed 50px per column
    local col_gap = 8                        -- Gap between columns
    local col1_x = x + label_width + 5       -- Now column
    local col2_x = col1_x + col_width + col_gap  -- Sum column

    local bucket = get_last_n_buckets(BUCKETS_PER_ROUND)
    local totals = get_totals()

    -- Draw stats rows (no headers, K/M notation, skip kills)
    for _, stat in ipairs(stats_order) do
        if stat == "kills" then goto continue end
        local round_val = bucket[stat] or 0
        local total_val = totals[stat] or 0

        -- Label (compact version)
        WindowText(win, "stats_font", stats_labels_compact[stat], x, y, 0, 0, COLOR_LABEL)

        -- Now value (left-aligned in column, K/M format)
        WindowText(win, "stats_font", format_number_short(round_val), col1_x, y, 0, 0, get_stat_color(stat, round_val))

        -- Sum value (left-aligned in column, K/M format)
        WindowText(win, "stats_font", format_number_short(total_val), col2_x, y, 0, 0, get_stat_color(stat, total_val))

        y = y + line_height
        ::continue::
    end
end

-- =============================================================================
-- Layout Dispatcher
-- =============================================================================
local draw_functions = {
    tabular = draw_tabular,
    compact = draw_compact,
    classic = draw_classic,
}

function refresh_display()
    if not win then return end

    -- Get theme boundaries
    local left, top, right, bottom = Theme.DressWindow(win, "title_font", "Damage Tracker")

    -- Clear the content area
    WindowRectOp(win, 2, left, top, right, bottom, Theme.PRIMARY_BODY)

    -- Dispatch to the appropriate layout draw function
    local draw_fn = draw_functions[layout_mode] or draw_tabular
    draw_fn(left, top, right, bottom)

    -- Repaint
    CallPlugin(plugin_id_repaint, "BufferedRepaint")
end

-- =============================================================================
-- Layout Resize Helper
-- =============================================================================
function resize_to_layout(mode)
    local dims = layout_dimensions[mode]
    if dims and win then
        width = dims.width
        height = dims.height
        WindowResize(win, width, height, Theme.PRIMARY_BODY)
        setup_window_contents()
        refresh_display()
    end
end

-- =============================================================================
-- Mouse Handlers
-- =============================================================================
function MouseDown(flags, hotspot_id)
    if hotspot_id == win .. "_resize" then
        startx, starty = WindowInfo(win, 17), WindowInfo(win, 18)
    end
end

function LeftClickOnly(flags, hotspot_id)
    if bit.band(flags, miniwin.hotspot_got_rh_mouse) ~= 0 then
        return true  -- cancel right-click drag
    end
end

function MouseUp(flags, hotspot_id)
    -- Handle right-click menu on title bar
    if bit.band(flags, miniwin.hotspot_got_rh_mouse) ~= 0 then
        show_context_menu()
    end
end

-- =============================================================================
-- Resize Callbacks
-- =============================================================================
function ResizeMoveCallback()
    if GetPluginVariable(plugin_id_lock, "lock_down_miniwindows") == "1" then
        return
    end
    local posx, posy = WindowInfo(win, 17), WindowInfo(win, 18)
    width = width + posx - startx
    startx = posx
    if width < 150 then
        width = 150
        startx = windowinfo.window_left + width
    elseif windowinfo.window_left + width > GetInfo(281) then
        width = GetInfo(281) - windowinfo.window_left
        startx = GetInfo(281)
    end
    height = height + posy - starty
    starty = posy
    local min_height = 100  -- Allow compact layouts (130px minimum needed)
    if height < min_height then
        height = min_height
        starty = windowinfo.window_top + height
    elseif windowinfo.window_top + height > GetInfo(280) then
        height = GetInfo(280) - windowinfo.window_top
        starty = GetInfo(280)
    end
    if utils.timer() - lastRefresh > 0.0333 then
        WindowResize(win, width, height, Theme.PRIMARY_BODY)
        setup_window_contents()
        refresh_display()
        lastRefresh = utils.timer()
    end
end

function ResizeReleaseCallback()
    WindowResize(win, width, height, Theme.PRIMARY_BODY)
    setup_window_contents()
    refresh_display()
end

-- =============================================================================
-- Context Menu
-- =============================================================================
-- Plugin ID for miniwindow z-order management
local plugin_id_zorder = "462b665ecb569efbf261422f"

function bring_to_front()
    CallPlugin(plugin_id_zorder, "boostMe", win)
end

function send_to_back()
    CallPlugin(plugin_id_zorder, "dropMe", win)
end

function show_context_menu()
    -- Layout submenu with checkmarks for current selection
    local menu_str = ">Layout"
    menu_str = menu_str .. "|" .. (layout_mode == "tabular" and "+" or "") .. "Tabular"
    menu_str = menu_str .. "|" .. (layout_mode == "compact" and "+" or "") .. "Compact"
    menu_str = menu_str .. "|" .. (layout_mode == "classic" and "+" or "") .. "Classic"
    menu_str = menu_str .. "|<"
    menu_str = menu_str .. "|-"
    -- Toggle options with checkmarks
    menu_str = menu_str .. "|" .. (echo_enabled and "+" or "") .. "Echo to Main"
    menu_str = menu_str .. "|" .. (battlespam_enabled and "+" or "") .. "Battle Spam"
    menu_str = menu_str .. "|" .. (debug_enabled and "+" or "") .. "Debug Mode"
    menu_str = menu_str .. "|-"
    menu_str = menu_str .. "|Configure Font"
    menu_str = menu_str .. "|Reset Stats"
    menu_str = menu_str .. "|-"
    menu_str = menu_str .. "|Bring To Front"
    menu_str = menu_str .. "|Send To Back"

    local result = WindowMenu(win,
        WindowInfo(win, 14),  -- mouse x
        WindowInfo(win, 15),  -- mouse y
        menu_str)

    if result == "Bring To Front" then
        bring_to_front()
    elseif result == "Send To Back" then
        send_to_back()
    elseif result == "Tabular" then
        dt_layout("tabular")
    elseif result == "Compact" then
        dt_layout("compact")
    elseif result == "Classic" then
        dt_layout("classic")
    elseif result == "Echo to Main" then
        dt_echo()
    elseif result == "Battle Spam" then
        cmd_battlespam()
    elseif result == "Debug Mode" then
        cmd_debug()
    elseif result == "Configure Font" then
        local wanted_font = utils.fontpicker(font_name, font_size)
        if wanted_font then
            font_name = wanted_font.name
            font_size = wanted_font.size
            setup_window_contents()
            refresh_display()
            SaveState()
        end
    elseif result == "Reset Stats" then
        dt_reset()
    end
end
