-- aard_damage_window_output.lua
-- Output abstraction layer - routes output to miniwindow and optionally main window

-- =============================================================================
-- State Variables
-- =============================================================================
local pending_styles = {}
local pending_bold = false

-- =============================================================================
-- Color Parsing
-- =============================================================================
function parse_color(color)
    -- Convert color name or #hex to RGB number
    local rgb = ColourNameToRGB(color)
    if rgb then
        return rgb
    end
    if type(color) == "string" and color:sub(1,1) == "#" then
        return tonumber(color:sub(2), 16)
    end
    return 0xC0C0C0  -- default gray
end

-- =============================================================================
-- Output Functions
-- =============================================================================

-- Replacement for ColourTell(color, bg, text)
function output_tell(color, text)
    local rgb = parse_color(color)
    table.insert(pending_styles, {
        text = text,
        textcolour = rgb,
        backcolour = 0,
        bold = pending_bold,
        length = #text
    })
    -- Also output to main window if enabled
    if output_to_main then
        if pending_bold then NoteStyle(2) end
        ColourTell(color, "", text)
        if pending_bold then NoteStyle(0) end
    end
end

-- Replacement for Note() - flushes pending styles
function output_note()
    if #pending_styles > 0 then
        if text_rect then
            text_rect:addText({pending_styles})
            text_rect:draw()
            if scrollbar then
                scrollbar:draw()
            end
            CallPlugin(plugin_id_repaint, "BufferedRepaint")
        end
        if output_to_main then
            Note()
        end
        pending_styles = {}
        pending_bold = false
    elseif output_to_main then
        Note()
    end
end

-- Replacement for NoteStyle(style)
function output_style(style)
    pending_bold = (style == 2)  -- 2 = bold in MUSHclient
    if output_to_main then
        NoteStyle(style)
    end
end

-- Output style runs to both miniwindow and optionally main window
function duplicate_color_output(sr, no_endline)
    for _, v in ipairs(sr) do
        output_tell(RGBColourToName(v.textcolour) or "silver", v.text)
    end

    if not no_endline then
        output_note()
    end
end

-- =============================================================================
-- Clear pending styles (for reset)
-- =============================================================================
function clear_pending_output()
    pending_styles = {}
    pending_bold = false
end
