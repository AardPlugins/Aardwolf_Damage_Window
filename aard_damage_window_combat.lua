-- aard_damage_window_combat.lua
-- Combat damage combining logic and damage type tables

-- =============================================================================
-- Damage Type Mappings
-- =============================================================================
damage_nouns = {
    ['acidic bite'   ] = 'Acid',
    ['digestion'     ] = 'Acid',
    ['slime'         ] = 'Acid',
    ['air'           ] = 'Air',
    ['beating'       ] = 'Bash',
    ['blast'         ] = 'Bash',
    ['charge'        ] = 'Bash',
    ['crush'         ] = 'Bash',
    ['hit'           ] = 'Bash',
    ['pound'         ] = 'Bash',
    ['punch'         ] = 'Bash',
    ['slap'          ] = 'Bash',
    ['smash'         ] = 'Bash',
    ['suction'       ] = 'Bash',
    ['thwack'        ] = 'Bash',
    ['chill'         ] = 'Cold',
    ['freezing bite' ] = 'Cold',
    ['earth'         ] = 'Earth',
    ['shock'         ] = 'Electric',
    ['shocking bite' ] = 'Electric',
    ['friction'      ] = 'Energy',
    ['wrath'         ] = 'Energy',
    ['flame'         ] = 'Fire',
    ['flaming bite'  ] = 'Fire',
    ['divine power'  ] = 'Holy',
    ['light'         ] = 'Light',
    ['magic'         ] = 'Magic',
    ['mental energy' ] = 'Mental',
    ['mind force'    ] = 'Mental',
    ['decaying touch'] = 'Negative',
    ['life drain'    ] = 'Negative',
    ['bite'          ] = 'Pierce',
    ['chomp'         ] = 'Pierce',
    ['peck'          ] = 'Pierce',
    ['pierce'        ] = 'Pierce',
    ['scratch'       ] = 'Pierce',
    ['stab'          ] = 'Pierce',
    ['sting'         ] = 'Pierce',
    ['thrust'        ] = 'Pierce',
    ['chop'          ] = 'Slash',
    ['claw'          ] = 'Slash',
    ['cleave'        ] = 'Slash',
    ['grep'          ] = 'Slash',
    ['slash'         ] = 'Slash',
    ['slice'         ] = 'Slash',
    ['whip'          ] = 'Slash',
    ['shadow'        ] = 'Shadow',
    ['wail'          ] = 'Sonic',
    ['water blast'   ] = 'Water'
}

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
-- Regex Helpers
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
-- Combat Combining Handler
-- =============================================================================
function combine_combat(name, line, wc, sr, data)
    if name == "combat_damage" then
        local crit = (wc[1] == "*")
        local hits = tonumber(wc[2] or 1) or 1
        local attacker = wc[3]
        local damage_type = wc[4]
        local defender = wc[5]
        local damage = tonumber(wc[6] or 0) or 0

        if ends_with(attacker, "'s God") and damage_type == "wrath" then
            attacker = remove_from_end(attacker, "'s God")
            damage_type = "God's wrath"
        end

        if not data.combat_hits then
            data.combat_hits = {}
        end
        if not data.combat_hits[attacker] then
            data.combat_hits[attacker] = {}
        end
        local defenders = data.combat_hits[attacker]
        if not defenders[defender] then
            defenders[defender] = {}
        end
        local types = defenders[defender]
        if not types[damage_type] then
            types[damage_type] = {
                hits = 0,
                damage = 0,
                crit = false,
            }
        end
        local hit = types[damage_type]
        hit.hits = hit.hits + hits
        hit.damage = hit.damage + damage
        hit.crit = hit.crit or crit

    elseif name == "combat_immune" then
        local attacker = "You"
        local hits = tonumber(wc[1] or 1) or 1
        local defender = wc[2]
        local damage_type = wc[3]

        if not data.combat_hits then
            data.combat_hits = {}
        end
        if not data.combat_hits[attacker] then
            data.combat_hits[attacker] = {}
        end
        local defenders = data.combat_hits[attacker]
        if not defenders[defender] then
            defenders[defender] = {}
        end
        local types = defenders[defender]
        if not types[damage_type] then
            types[damage_type] = {
                hits = 0,
                damage = 0,
                crit = false,
                immune = true,
            }
        end
        local hit = types[damage_type]
        hit.hits = hit.hits + hits

    elseif starts_with(name, "combat_preserve_") then
        if not data.preserve then
            data.preserve = {}
        end
        table.insert(data.preserve, sr)

    elseif starts_with(name, "combat_force_") then
        if not data.force then
            data.force = {}
        end
        table.insert(data.force, sr)
    end

    -- Output force effects
    if data.force then
        for _, sr in ipairs(data.force) do
            duplicate_color_output(sr)
        end
    end

    -- Output preserve effects if enabled or not in active combat
    if data.preserve and (GetVariable(VAR_PRESERVE) == "true" or (not data.combat_hits and gmcp("char.status.enemy") == "")) then
        for _, sr in ipairs(data.preserve) do
            duplicate_color_output(sr)
        end
    end

    -- Output combat damage summary
    if data.combat_hits then
        output_combat_damage(data)
    end
end

-- =============================================================================
-- Combat Damage Output
-- =============================================================================
function output_combat_damage(data)
    local TotalDamageWidth = 9
    local AttackerWidth = 30
    local TypeWidth = 40
    local DefenderWidth = 30

    local wrap_width = GetOption("wrap_column")
    if wrap_width then
        wrap_width = wrap_width - TotalDamageWidth
        wrap_width = wrap_width - TypeWidth
        AttackerWidth = math.floor(wrap_width * 2 / 3)
        if AttackerWidth < 12 then
            AttackerWidth = 12
        end
        if AttackerWidth > 30 then
            AttackerWidth = 30
        end
        wrap_width = wrap_width - AttackerWidth - 1
        DefenderWidth = wrap_width
        if DefenderWidth < 12 then
            DefenderWidth = 12
        end
    end

    local others = {}
    local others_total = 0

    for attacker, defenders in pairs(data.combat_hits) do
        attacker = remove_from_end(attacker, "'s")
        attacker = remove_from_end(attacker, "'")
        local attacker_player_info = get_player_info(attacker)
        attacker = remove_articles(attacker)

        if attacker == "Your" then
            attacker = "You"
        end

        for defender, types in pairs(defenders) do
            local defender_player_info = get_player_info(defender)
            defender = remove_articles(defender)

            local total = 0
            local immune = false
            for damage_type, hit in pairs(types) do
                total = total + hit.damage
                if hit.immune then
                    immune = true
                end
            end

            if attacker ~= "You" and defender ~= "You" and GetVariable(VAR_COMBAT_OTHERS) ~= "full" then
                if GetVariable(VAR_COMBAT_OTHERS) == "list" then
                    others[attacker] = true
                    others[defender] = true
                    others_total = others_total + total
                end
            else
                local color1, color2, color3, color4
                if attacker == "You" then
                    if total == 0 and immune then
                        color1 = "#b0b0b0"
                        color2 = "#707070"
                        color3 = "#c0c0c0"
                        color4 = "#b0b0b0"
                    else
                        color1 = "#00af00"
                        color2 = "#005f00"
                        color3 = "#87ff87"
                        color4 = "#00af00"

                        if defender_player_info then
                            defender = defender .. " (" .. (defender_player_info.level or "???") .. " / T" .. (defender_player_info.tier or "?") .. ")"
                            color1 = "#87ff87"
                        end
                    end
                elseif defender == "You" then
                    color1 = "#ff5f5f"
                    color2 = "#ff0000"
                    color3 = "#ffafaf"
                    color4 = "#ff5f5f"
                    if attacker_player_info then
                        attacker = attacker .. " (" .. (attacker_player_info.level or "???") .. " / T" .. (attacker_player_info.tier or "?") .. ")"
                        color1 = "#ffafaf"
                    end
                else
                    if attacker_player_info then
                        attacker = attacker .. " (" .. (attacker_player_info.level or "???") .. " / T" .. (attacker_player_info.tier or "?") .. ")"
                    end
                    if defender_player_info then
                        defender = defender .. " (" .. (defender_player_info.level or "???") .. " / T" .. (defender_player_info.tier or "?") .. ")"
                    end

                    color1 = "#a0a0a0"
                    color2 = "#606060"
                    color3 = "#c0c0c0"
                    color4 = "#a0a0a0"
                end

                if total > 0 then
                    local total_str = tostring(total)

                    local mob_name = ""
                    if attacker ~= "You" then
                        mob_name = attacker
                    elseif defender ~= "You" then
                        mob_name = defender
                    end

                    local details = ""
                    for damage_type, hit in pairs(types) do
                        if hit.crit then
                            details = details .. "*"
                        end
                        details = details .. (hit.hits or 1) .. "x"
                        details = details .. (upper_first(damage_type) or "Damage") .. "/"
                        if hit.immune then
                            details = details .. "immune"
                        else
                            details = details .. (hit.damage or 0)
                        end
                        details = details .. " "
                    end
                    if attacker ~= "You" and defender ~= "You" then
                        details = details .. "-> " .. defender
                    end

                    local max_mob_len = 30
                    if #mob_name > max_mob_len then
                        mob_name = string.sub(mob_name, 1, max_mob_len)
                    end
                    details = details:gsub("%s+$", "")

                    output_tell("silver", mob_name .. ", " .. details .. ".")

                    output_tell(color2, " [")
                    output_tell(color3, total_str)
                    output_tell(color2, "]")

                    output_note()
                end
            end
        end
    end

    -- Output "others" summary if in list mode
    if GetVariable(VAR_COMBAT_OTHERS) == "list" then
        local color1 = "#a0a0a0"
        local color2 = "#606060"
        local color3 = "#c0c0c0"

        local total_str = tostring(others_total)
        local others_list = {}
        for other in pairs(others) do
            table.insert(others_list, other)
        end
        if #others_list > 0 then
            output_tell(color2, "[")
            output_tell(color3, total_str)
            output_tell(color2, "]")
            output_tell(color1, string.rep(" ", math.max(0, 9 - 2 - #total_str)))

            table.sort(others_list)
            for i, other in ipairs(others_list) do
                local player_info = get_player_info(other)
                if player_info then
                    other = other .. " (" .. (player_info.level or "???") .. " / T" .. (player_info.tier or "?") .. ")"
                end

                if i == 1 then
                    output_tell(color1, other)
                else
                    output_tell(color2, " / ")
                    output_tell(color1, other)
                end
            end
            output_note()
        end
    end
end
