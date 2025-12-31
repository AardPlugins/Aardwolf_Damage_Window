-- aard_damage_window_window.lua
-- Miniwindow management, resize handling, and context menu

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
    WindowShow(win, true)
end

function setup_window_contents()
    -- Setup fonts
    WindowFont(win, "title_font", font_name, font_size, false, false, false, false, 0)

    -- Dress window with theme (title bar, border)
    local left, top, right, bottom = Theme.DressWindow(win, "title_font", "Damage Window")

    -- Add resize handler
    Theme.AddResizeTag(win, 2, nil, nil, "MouseDown", "ResizeMoveCallback", "ResizeReleaseCallback")

    -- Calculate text rect and scrollbar dimensions
    local sb_width = Theme.RESIZER_SIZE
    local tr_right = right - sb_width
    local tr_bottom = bottom - 1

    -- Create or update text rect (preserve content on resize)
    if text_rect then
        text_rect:setRect(left, top, tr_right, tr_bottom)
    else
        text_rect = TextRect.new(win, "output",
            left, top, tr_right, tr_bottom,
            MAX_LINES, true, Theme.PRIMARY_BODY, 3, font_name, font_size)
        text_rect:setExternalMenuFunction(build_menu)
    end

    -- Create or update scrollbar
    if scrollbar then
        scrollbar:setRect(tr_right, top, right, bottom - sb_width)
    else
        scrollbar = ScrollBar.new(win, "scroll",
            tr_right, top, right, bottom - sb_width)

        -- Connect scroll callbacks (only on first creation)
        text_rect:addUpdateCallback(scrollbar, scrollbar.setScroll)
        scrollbar:addUpdateCallback(text_rect, text_rect.setScroll)
    end

    text_rect:draw()
    scrollbar:draw()
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
        if text_rect then
            text_rect:rightClickMenu()
        end
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
    if width < 200 then
        width = 200
        startx = windowinfo.window_left + width
    elseif windowinfo.window_left + width > GetInfo(281) then
        width = GetInfo(281) - windowinfo.window_left
        startx = GetInfo(281)
    end
    height = height + posy - starty
    starty = posy
    if height < 100 then
        height = 100
        starty = windowinfo.window_top + height
    elseif windowinfo.window_top + height > GetInfo(280) then
        height = GetInfo(280) - windowinfo.window_top
        starty = GetInfo(280)
    end
    if utils.timer() - lastRefresh > 0.0333 then
        WindowResize(win, width, height, Theme.PRIMARY_BODY)
        setup_window_contents()
        lastRefresh = utils.timer()
    end
end

function ResizeReleaseCallback()
    WindowResize(win, width, height, Theme.PRIMARY_BODY)
    setup_window_contents()
    if text_rect then
        text_rect:reWrapLines()
        text_rect:draw()
    end
    if scrollbar then
        scrollbar:draw()
    end
    CallPlugin(plugin_id_repaint, "BufferedRepaint")
end

-- =============================================================================
-- Context Menu
-- =============================================================================
function build_menu()
    local menu_items = {}

    -- Font configuration
    table.insert(menu_items, {"Configure Font", function()
        local wanted_font = utils.fontpicker(font_name, font_size)
        if wanted_font then
            font_name = wanted_font.name
            font_size = wanted_font.size
            if text_rect then
                text_rect:loadFont(font_name, font_size)
                text_rect:reWrapLines()
            end
            setup_window_contents()
            SaveState()
        end
    end})

    table.insert(menu_items, {"-", ""})

    -- Echo toggle
    table.insert(menu_items, {
        (output_to_main and "+" or "") .. "Echo to Main Window",
        function()
            output_to_main = not output_to_main
            if output_to_main then
                ColourNote("yellow", "", "Damage window output will echo to main window.")
            else
                ColourNote("yellow", "", "Damage window output will only appear in miniwindow.")
            end
            SaveState()
        end
    })

    table.insert(menu_items, {"-", ""})

    -- Groups submenu
    table.insert(menu_items, {">Groups", ""})
    for option, info in pairs(options) do
        table.insert(menu_items, {
            (GetVariable(option) == "true" and "+" or "") .. upper_first(option),
            function()
                toggle_group(option)
            end
        })
    end
    table.insert(menu_items, {"<", ""})

    table.insert(menu_items, {"-", ""})

    -- Clear window
    table.insert(menu_items, {"Clear Window", function()
        window_clear()
    end})

    -- Build menu string and handlers
    local menu_strings = {}
    local menu_functions = {}
    for i, v in ipairs(menu_items) do
        table.insert(menu_strings, v[1])
        if type(v[2]) == "function" then
            table.insert(menu_functions, v[2])
        end
    end

    return table.concat(menu_strings, "|"), menu_functions
end
