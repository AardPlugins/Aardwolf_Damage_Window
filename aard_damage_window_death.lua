-- aard_damage_window_death.lua
-- Death message combining logic

-- =============================================================================
-- Color Configuration
-- =============================================================================
local LOOT_COLOR1 = "#d7af5f"
local LOOT_COLOR2 = "#875f5f"
local EXP_COLOR = "#afd787"
local GOLD_COLOR = "#ffff00"

-- =============================================================================
-- Death Combining Handler
-- =============================================================================
function combine_death(name, line, wc, sr, data)
    -- Capture mob name from death message triggers
    if starts_with(name, "death_mob_") then
        if wc.mob then
            data.mob_name = remove_articles(wc.mob)
        end
    elseif name == "death_exp" then
        if wc[1] == "don't" then
            data.noexp = true
        end

        if not data.exp then
            data.exp = {}
        end

        local exp_sr = get_wildcard_sr(line, wc, sr, 2)
        for _, run in ipairs(exp_sr) do
            local pieces = split(run.text, "+")
            for _, amt in ipairs(pieces) do
                amt = tonumber(amt)
                if amt then
                    table.insert(data.exp, {
                        amt = amt,
                        color = RGBColourToName(run.textcolour)
                    })
                end
            end
        end
    elseif starts_with(name, "death_preserve") then
        data.preserve = data.preserve or {}
        table.insert(data.preserve, sr)
    elseif name == "death_other_exp" then
        data.other_exp = data.other_exp or {}
        table.insert(data.other_exp, {name = wc[1], amt = wc[2]})
    elseif name == "death_other_vampire" then
        data.other_vampire = wc[1]
    elseif name == "death_daily_exp_remaining" then
        data.daily_exp = wc[1]
    elseif name == "death_pointless" then
        data.pointless = true
    elseif name == "death_is_noexp" then
        data.noexp = true
    elseif name == "death_gold" or name == "death_gold_daily" then
        if data.gold then
            data.gold = data.gold .. " + " .. wc[1]
        else
            data.gold = wc[1]
        end
    elseif name == "death_gold_clan_tax" then
        if data.tax then
            data.tax = data.tax .. "+" .. wc[1]
        else
            data.tax = wc[1]
        end
    elseif name == "death_daily_gold_remaining" then
        data.daily_gold = wc[1]
    elseif name == "death_other_split" then
        data.other_split = data.other_split or {}
        table.insert(data.other_split, {
            name = wc[1],
            total = wc[2],
            share = wc[4]
        })
    elseif name == "death_loot" then
        sr[1].text = remove_from_start(sr[1].text, "You get ")

        local delete_remaining = false
        for i, run in ipairs(sr) do
            if delete_remaining and i > 1 then
                sr[i] = nil
            else
                local pos = string.find(run.text, " from the ")
                if pos then
                    if pos > 1 then
                        run.text = string.sub(run.text, 1, pos-1)
                    else
                        sr[i] = nil
                    end
                    delete_remaining = true
                end
            end
        end

        data.loot_items = data.loot_items or {}
        table.insert(data.loot_items, {
            sr = sr
        })
    elseif name == "death_crumble" then
        if data.loot_items then
            data.loot_items[#data.loot_items].crumble = wc[2]
        end
    elseif name == "death_split" then
        data.split = data.split or {}
        table.insert(data.split, {
            total = wc[1],
            count = wc[2],
            share = wc[4]
        })
    elseif name == "death_campaign" then
        data.cp = true
    elseif name == "death_gq" then
        data.gq = true
    elseif name == "death_gq_kills" then
        data.gq_kills = wc[1]
    elseif name == "death_gq_qp" then
        data.gq_qp = (data.gq_qp or 0) + 3
    elseif name == "death_quest" then
        data.quest = true
    elseif name == "death_vampire" then
        data.vampire = true
    elseif name == "death_sacrifice" then
        local gold = wc[2]

        table.remove(sr, 1)
        table.remove(sr, 1)
        if sr[1] then
            sr[1].text = remove_from_start(sr[1].text, " gold coins for ")
            sr[#sr].text = remove_from_end(sr[#sr].text, ".")
        end

        if not data.sac then
            data.sac = {}
        end
        table.insert(data.sac, {
            gold = gold,
            item = sr
        })
    elseif name == "death_sacrifice_none" then
        if sr[1] then
            local findstr = " is not impressed with "
            local pos = string.find(sr[1].text, findstr)
            if pos then
                sr[1].text = string.sub(sr[1].text, pos + #findstr)
            end
        end

        if not data.sac then
            data.sac = {}
        end

        table.insert(data.sac, {
            item = sr
        })
    end

    -- Output the death summary
    if data.exp or data.gold or data.pointless or data.loot_items or data.split or data.other_split then
        if GetVariable(VAR_DEATH_SIMPLE) == "true" then
            output_death_simple(data)
        else
            output_death_verbose(data)
        end
    end

    -- Output preserved lines
    if data.preserve then
        for _, sr in ipairs(data.preserve) do
            duplicate_color_output(sr)
        end
    end
end

-- =============================================================================
-- Simple Death Output (mob, X exp. Y gp.)
-- =============================================================================
function output_death_simple(data)
    local mob_name = data.mob_name or ""
    local details = ""

    if data.exp then
        local total = 0
        for _, piece in ipairs(data.exp) do
            total = total + piece.amt
        end
        if data.noexp then
            details = details .. total .. " noexp"
        else
            details = details .. total .. " exp"
        end
    end

    if data.pointless then
        details = details .. " no exp"
    end

    local total_gold = 0
    local has_gold = false

    if data.gold then
        for gold_str in string.gmatch(data.gold, "[%d,]+") do
            local gold_num = tonumber((gold_str:gsub(",", "")))
            if gold_num then
                total_gold = total_gold + gold_num
                has_gold = true
            end
        end
    end

    if data.split then
        for _, info in ipairs(data.split) do
            local share_num = tonumber((info.share:gsub(",", "")))
            if share_num then
                total_gold = total_gold + share_num
                has_gold = true
            end
        end
    end

    if data.other_split then
        for _, info in ipairs(data.other_split) do
            local share_num = tonumber((info.share:gsub(",", "")))
            if share_num then
                total_gold = total_gold + share_num
                has_gold = true
            end
        end
    end

    if data.sac then
        for _, sac in ipairs(data.sac) do
            if sac.gold then
                local sac_num = tonumber((sac.gold:gsub(",", "")))
                if sac_num then
                    total_gold = total_gold + sac_num
                    has_gold = true
                end
            end
        end
    end

    if has_gold then
        if #details > 0 then
            details = details .. ". "
        end
        details = details .. total_gold .. " gp"
    end

    if #details > 0 then
        details = details .. "."
    end

    local max_mob_len = 30
    if #mob_name > max_mob_len then
        mob_name = string.sub(mob_name, 1, max_mob_len)
    end

    output_tell("silver", mob_name .. ", ")
    output_tell(LOOT_COLOR1, details)
    output_note()
end

-- =============================================================================
-- Verbose Death Output
-- =============================================================================
function output_death_verbose(data)
    local mob_name = data.mob_name or ""
    local max_mob_len = 30
    if #mob_name > max_mob_len then
        mob_name = string.sub(mob_name, 1, max_mob_len)
    end
    output_tell("silver", mob_name)
    output_tell("silver", ", ")

    local needs_comma = false

    if data.exp then
        output_death_experience(data)
        needs_comma = true
    end

    if data.pointless then
        if needs_comma then
            output_tell("silver", ", ")
        end
        output_tell("silver", "no exp (pointless)")
        needs_comma = true
    end

    if data.loot_items then
        if needs_comma then
            output_tell("silver", ", ")
        end
        output_death_loot(data)
        needs_comma = true
    end

    if data.gold then
        if needs_comma then
            output_tell("silver", ", ")
        end
        output_tell("yellow", data.gold)
        output_tell("silver", " gp")
        needs_comma = true
    end

    if data.tax then
        if needs_comma then
            output_tell("silver", ", ")
        end
        output_tell("silver", "taxed ")
        output_tell("olive", data.tax)
        output_tell("silver", " gp")
        needs_comma = true
    end

    output_tell("silver", ". ")

    -- Other exp
    if data.other_exp then
        for _, info in ipairs(data.other_exp) do
            output_tell("silver", info.name .. " gets ")
            output_tell("#a6da95", info.amt)
            output_tell("silver", " exp. ")
        end
    end

    -- Splits
    if data.split then
        for _, info in ipairs(data.split) do
            output_tell("silver", "You split ")
            output_tell("yellow", info.total)
            output_tell("silver", " (")
            output_tell("yellow", info.share)
            output_tell("silver", ") gold with ")
            output_tell("white", info.count)
            if info.count == 1 then
                output_tell("silver", " other. ")
            else
                output_tell("silver", " others. ")
            end
        end
    end

    if data.other_split then
        for _, info in ipairs(data.other_split) do
            output_tell("silver", info.name .. " splits ")
            output_tell("yellow", info.total)
            output_tell("silver", " (")
            output_tell("yellow", info.share)
            output_tell("silver", ") gold. ")
        end
    end

    -- Daily blessing
    if data.daily_exp or data.daily_gold then
        output_tell("yellow", "DB")
        output_tell("silver", ": ")
        if data.daily_exp then
            output_tell("yellow", data.daily_exp)
            if data.daily_exp == "1" then
                output_tell("silver", " exp kill")
            else
                output_tell("silver", " exp kills")
            end
        end

        if data.daily_gold then
            if data.daily_exp then
                output_tell("silver", ", ")
            end
            output_tell("yellow", data.daily_gold)
            if data.daily_gold == "1" then
                output_tell("silver", " gold kill")
            else
                output_tell("silver", " gold kills")
            end
        end
        output_tell("silver", ". ")
    end

    -- Quest flags
    if data.cp then
        output_tell("white", "CAMPAIGN mob! ")
    end

    if data.gq then
        output_tell("#f38ba8", "GQ mob! ")
        if data.gq_kills then
            output_tell("#f38ba8", "(" .. data.gq_kills .. " left this lvl) ")
        end
        if data.gq_qp then
            output_tell("#f38ba8", "+" .. data.gq_qp .. " qp. ")
        end
    end

    if data.quest then
        output_tell("#f38ba8", "QUEST mob! ")
    end

    -- Vampire
    if data.vampire then
        output_tell("silver", "You drink the corpse. ")
    end

    if data.other_vampire then
        output_tell("silver", data.other_vampire .. " drinks the corpse. ")
    end

    -- Sacrifice
    if data.sac then
        if (data.exp or data.pointless or data.gold or data.loot_items) and #data.sac == 1 then
            output_tell("silver", "Sacced: ")
            output_tell("yellow", data.sac[1].gold or "0")
            output_tell("silver", " gp. ")
        else
            output_tell("teal", "You sacrifice ")
            for i, sac in ipairs(data.sac) do
                if i > 1 then
                    output_tell("teal", ", ")
                end

                for _, sr in ipairs(sac.item) do
                    output_tell(RGBColourToName(sr.textcolour) or "teal", sr.text)
                end

                if sac.gold then
                    output_tell("teal", " (")
                    output_tell("yellow", sac.gold)
                    output_tell("teal", " gp)")
                end
            end
            output_tell("teal", ". ")
        end
    end

    output_note()
end

-- =============================================================================
-- Experience Output Helper
-- =============================================================================
function output_death_experience(data)
    local total = data.exp[1].amt
    local base_exp = data.exp[1].amt
    local racial_bonus = 0

    if gmcp("char.base.race") == "Tigran" then
        local bonus
        if data.other_exp then
            bonus = 0.88
        else
            bonus = 1.12
        end

        base_exp = math.floor(data.exp[1].amt / bonus)
        racial_bonus = data.exp[1].amt - base_exp
    end

    if data.noexp then
        output_style(2)
        output_tell("#a0a0a0", tostring(base_exp))
        output_style(0)
    else
        output_tell("#a6da95", tostring(base_exp))
    end

    if racial_bonus > 0 then
        if data.noexp then
            output_style(2)
            output_tell("#a0a0a0", "+")
            if GetVariable(VAR_BONUSEXP_PCT) == "true" then
                output_tell("#a0a0a0", math.floor(100 * racial_bonus / base_exp) .. "%")
            else
                output_tell("#a0a0a0", tostring(racial_bonus))
            end
            output_style(0)
        else
            if GetVariable(VAR_BONUSEXP_PCT) == "true" then
                output_tell("#87d787", "+")
                output_tell("#b4e8a6", math.floor(100 * racial_bonus / base_exp) .. "%")
            else
                output_tell("#87d787", "+")
                output_tell("#b4e8a6", tostring(racial_bonus))
            end
        end
    end

    for i = 2, #data.exp do
        local piece = data.exp[i]
        if data.noexp then
            output_tell("#a0a0a0", "+")
        else
            output_tell("#87d787", "+")
        end

        if data.noexp then
            output_tell("#a0a0a0", tostring(piece.amt))
        else
            if #data.exp == 1 then
                output_style(2)
                output_tell("#89dceb", tostring(piece.amt))
                output_style(0)
            else
                if i > 1 and GetVariable(VAR_BONUSEXP_PCT) == "true" then
                    output_tell(piece.color, math.floor(100 * piece.amt / base_exp) .. "%")
                else
                    output_tell(piece.color, tostring(piece.amt))
                end
            end
        end

        total = total + piece.amt
    end

    if #data.exp > 1 or racial_bonus > 0 then
        if data.noexp then
            output_tell("#a0a0a0", "=")
            output_tell("#a0a0a0", tostring(total))
        else
            output_tell("#87d787", "=")
            output_style(2)
            output_tell("#89dceb", tostring(total))
            output_style(0)
        end
    end

    if data.noexp then
        output_tell("#a0a0a0", " noexp")
    else
        output_tell("silver", " exp")
    end
end

-- =============================================================================
-- Loot Output Helper
-- =============================================================================
function output_death_loot(data)
    for i, item in ipairs(data.loot_items) do
        if i > 1 then
            output_tell("silver", ", ")
        end

        for _, run in ipairs(item.sr) do
            output_tell(RGBColourToName(run.textcolour) or "silver", run.text)
        end

        if item.crumble then
            output_tell("white", " => ")
            output_tell("yellow", item.crumble)
            output_tell("silver", " gp")
        end
    end
end
