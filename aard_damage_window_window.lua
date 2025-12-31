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
    -- Setup fonts
    WindowFont(win, "title_font", font_name, font_size, false, false, false, false, 0)
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
function refresh_display()
    if not win then return end

    -- Get theme boundaries
    local left, top, right, bottom = Theme.DressWindow(win, "title_font", "Damage Tracker")

    -- Clear the content area
    WindowRectOp(win, 2, left, top, right, bottom, Theme.PRIMARY_BODY)

    local line_height = WindowFontInfo(win, "stats_font", 1) + 2
    local x = left + 5
    local y = top + 5
    local label_width = 70

    local bucket = get_previous_bucket()
    local totals = get_totals()

    -- Draw "Last Round:" header
    WindowText(win, "header_font", "Last Round:", x, y, 0, 0, COLOR_HEADER)
    y = y + line_height + 2

    -- Current bucket stats
    draw_stat_line(x, y, label_width, "Given:", bucket.given, COLOR_GIVEN)
    y = y + line_height
    draw_stat_line(x, y, label_width, "Taken:", bucket.taken, bucket.taken > 0 and COLOR_TAKEN or COLOR_TAKEN_ZERO)
    y = y + line_height
    draw_stat_line(x, y, label_width, "Heals:", bucket.healed or 0, COLOR_VALUE)
    y = y + line_height
    draw_stat_line(x, y, label_width, "Gold:", bucket.gold, COLOR_VALUE)
    y = y + line_height
    draw_stat_line(x, y, label_width, "XP:", bucket.exp, COLOR_VALUE)
    y = y + line_height
    draw_stat_line(x, y, label_width, "Kills:", bucket.kills, COLOR_VALUE)
    y = y + line_height

    -- Spacer
    y = y + 12

    -- Draw "Last N Rounds:" header
    local header_text = "Last " .. NUM_BUCKETS .. " Rounds:"
    WindowText(win, "header_font", header_text, x, y, 0, 0, COLOR_HEADER)
    y = y + line_height + 2

    -- Totals
    draw_stat_line(x, y, label_width, "Given:", totals.given, COLOR_GIVEN)
    y = y + line_height
    draw_stat_line(x, y, label_width, "Taken:", totals.taken, totals.taken > 0 and COLOR_TAKEN or COLOR_TAKEN_ZERO)
    y = y + line_height
    draw_stat_line(x, y, label_width, "Heals:", totals.healed or 0, COLOR_VALUE)
    y = y + line_height
    draw_stat_line(x, y, label_width, "Gold:", totals.gold, COLOR_VALUE)
    y = y + line_height
    draw_stat_line(x, y, label_width, "XP:", totals.exp, COLOR_VALUE)
    y = y + line_height
    draw_stat_line(x, y, label_width, "Kills:", totals.kills, COLOR_VALUE)

    -- Repaint
    CallPlugin(plugin_id_repaint, "BufferedRepaint")
end

function draw_stat_line(x, y, label_width, label, value, color)
    WindowText(win, "stats_font", label, x, y, 0, 0, COLOR_LABEL)
    WindowText(win, "stats_font", format_number(value), x + label_width, y, 0, 0, color)
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
    if height < 200 then
        height = 200
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
function show_context_menu()
    local menu_str = "Configure Font"
    menu_str = menu_str .. "|" .. (echo_enabled and "+" or "") .. "Echo to Main"
    menu_str = menu_str .. "|-"
    menu_str = menu_str .. "|Reset Stats"

    local result = WindowMenu(win,
        WindowInfo(win, 14),  -- mouse x
        WindowInfo(win, 15),  -- mouse y
        menu_str)

    if result == "Configure Font" then
        local wanted_font = utils.fontpicker(font_name, font_size)
        if wanted_font then
            font_name = wanted_font.name
            font_size = wanted_font.size
            setup_window_contents()
            refresh_display()
            SaveState()
        end
    elseif result == "Echo to Main" then
        dt_echo()
    elseif result == "Reset Stats" then
        dt_reset()
    end
end
