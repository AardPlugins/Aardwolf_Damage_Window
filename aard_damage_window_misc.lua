-- aard_damage_window_misc.lua
-- Lotus, equip, spellup, and where combining handlers

-- =============================================================================
-- Lotus Combining Handler
-- =============================================================================
function combine_lotus(name, line, wc, sr, data)
    if name == "lotus_amount" then
        data.sum = (data.sum or 0) + tonumber(wc[1])
        data.count = (data.count or 0) + 1
    elseif name == "lotus_max" then
        data.max = true
    end

    if data.count and data.count > 1 then
        output_tell("#cba6f7", "[")
        output_tell("white", tostring(data.count))
        output_tell("#cba6f7", "] ")
    end
    output_tell("silver", "Wow....what a rush!")
    if data.sum then
        output_tell("#cba6f7", " [")
        output_tell("white", tostring(data.sum))
        output_tell("#cba6f7", "]")
    end

    if data.max then
        output_tell("silver", " (Your concentration is at its peak.)")
    end

    output_note()
end

-- =============================================================================
-- Equip Combining Handler
-- =============================================================================
function combine_equip(name, line, wc, sr, data)
    if name == "remove" then
        local item_name, slot

        if wc.remove2_item ~= "" then
            item_name = wc.remove2_item
            slot = wc.remove2_slot
        elseif wc.remove_wielded_item ~= "" then
            item_name = wc.remove_wielded_item
            slot = "wielded"
        elseif wc.remove_secondary_item ~= "" then
            item_name = wc.remove_secondary_item
            slot = "secondary"
        elseif wc.remove_float_item ~= "" then
            item_name = wc.remove_float_item
            slot = "float"
        elseif wc.remove_aura_item ~= "" then
            item_name = wc.remove_aura_item
            slot = "aura"
        elseif wc.remove_light_item ~= "" then
            item_name = wc.remove_light_item
            slot = "light"
        elseif wc.remove_sleeping_item ~= "" then
            item_name = wc.remove_sleeping_item
            slot = "sleeping"
        end

        local first, last = string.find(line, item_name, 1, true)
        local item_sr = style_run_sub(sr, first, last)

        if not data.remove then
            data.remove = {}
        end
        table.insert(data.remove, {
            sr = item_sr,
            slot = slot
        })

    elseif name == "equip" then
        local item_name, slot
        if wc.equip2_item ~= "" then
            item_name = wc.equip2_item
            slot = wc.equip2_slot
        elseif wc.equip_pin_item ~= "" then
            item_name = wc.equip_pin_item
            slot = "pin"
        elseif wc.equip_secondary_item ~= "" then
            item_name = wc.equip_secondary_item
            slot = "secondary"
        elseif wc.equip_wielded_item ~= "" then
            item_name = wc.equip_wielded_item
            slot = "wielded"
        elseif wc.equip_aura_item ~= "" then
            item_name = wc.equip_aura_item
            slot = "aura"
        elseif wc.equip_float_item ~= "" then
            item_name = wc.equip_float_item
            slot = "float"
        elseif wc.equip_light_item ~= "" then
            item_name = wc.equip_light_item
            slot = "light"
        end

        local first, last = string.find(line, item_name, 1, true)
        local item_sr = style_run_sub(sr, first, last)

        if not data.wear then
            data.wear = {}
        end
        table.insert(data.wear, {
            sr = item_sr,
            slot = slot
        })
    end

    -- Output the equip/remove summary
    if data.wear and data.remove and #data.wear == 1 and #data.remove == 1 and data.wear[1].slot == data.remove[1].slot then
        output_tell("silver", "You swap ")
        duplicate_color_output(data.remove[1].sr, true)
        output_tell("silver", " for ")
        duplicate_color_output(data.wear[1].sr, true)
        output_tell("silver", " (" .. data.remove[1].slot .. ").")
        output_note()
    else
        if data.remove then
            output_tell("silver", "You remove ")
            for i, remove_info in ipairs(data.remove) do
                duplicate_color_output(remove_info.sr, true)
                output_tell("silver", " (" .. remove_info.slot .. ")")
                if i < #data.remove then
                    if i == #data.remove - 1 then
                        output_tell("silver", " and ")
                    else
                        output_tell("silver", ", ")
                    end
                end
            end
        end
        if data.wear then
            if data.remove then
                output_tell("silver", " and wear ")
            else
                output_tell("silver", "You wear ")
            end

            for i, wear_info in ipairs(data.wear) do
                duplicate_color_output(wear_info.sr, true)
                output_tell("silver", " (" .. wear_info.slot .. ")")
                if i < #data.wear then
                    if i == #data.wear - 1 then
                        output_tell("silver", " and ")
                    else
                        output_tell("silver", ", ")
                    end
                end
            end
        end

        if data.remove or data.wear then
            output_tell("silver", ".")
            output_note()
        end
    end
end

-- =============================================================================
-- Spellup Combining Handler
-- =============================================================================
function combine_spellup(name, line, wc, sr, data)
    data.spellup_items = data.spellup_items or {}
    table.insert(data.spellup_items, wc[1])

    if #data.spellup_items == 1 then
        output_tell("silver", "Queueing spell : ")
    else
        output_tell("silver", "Queueing spells : ")
    end

    for i, item in ipairs(data.spellup_items) do
        if i > 1 then
            output_tell("silver", ", ")
        end
        output_tell("silver", item)
    end

    output_tell("silver", ".")
    output_note()
end

-- =============================================================================
-- Where Combining Handler
-- =============================================================================
function combine_where(name, line, wc, sr, data)
    if name == "where_area" then
        data.name = wc[1]
    elseif name == "where_creator" then
        data.creator = wc[1]
    elseif name == "where_range" then
        data.range = wc[1]
    end

    local color1 = "#00ff80"
    local color2 = "#ff0080"

    if data.name then
        output_tell(color1, "You're in ")
        output_tell(color2, data.name)
        output_tell(color1, " ")
    else
        output_tell(color1, "Area ")
    end

    if data.creator then
        output_tell(color1, "by ")
        output_tell(color2, data.creator)
        output_tell(color1, " ")
    end

    if data.range then
        output_tell(color1, "(")
        output_tell(color2, data.range)
        output_tell(color1, ") ")
    end

    output_tell(color1, "Players nearby:")
    output_note()
end
