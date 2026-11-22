local addonName, ns = ...

-- The gamepad macros: things a controller makes awkward in World of
-- Warcraft: Forever, from what controller players asked for (heal yourself
-- without targeting, use a quest item from the bags, save and wear a set of
-- gear, leave a group, say hello or thanks without a keyboard). Put one on
-- the gamepad's action bar and it is one button.
--
-- Macros every character can share go in the account-wide General macros
-- (120 slots), so they cost none of a character's 18. Only Heal Me, whose
-- spell is the class's, is a character macro.
--
-- A macro has name, desc, how and body, and may have:
--   general  true: an account-wide General macro
--   spells   spells it needs (waits until all are known)
--   icon     the icon to show (the question mark with #showtooltip if none)
--   needs    a function returning what is missing on this client, or nil
--   Body     a function giving the body now (the quest item macro)

ns.QUEST_ITEM = "Quest Item"
local GEAR_SET = "GamepadMacros"

-- Whether a controller is in use: a controller button or stick has been
-- used since logging in (GAME_PAD_ACTIVE_CHANGED). Being connected is not
-- enough: the author's PC reports two controllers with none in use
-- (2026-11-08). Once used it stays true for the session, so a Steam Deck
-- touchscreen tap (which counts as the mouse) does not hide anything.
-- Without C_GamePad the answer is yes.
ns.controllerUsed = false
function ns.ControllerInUse()
    if not C_GamePad then return true end
    return ns.controllerUsed
end

-- The heal each class can cast on itself, from level 1, best first. A
-- priest learns Heal later: its line casts it once known, else Lesser Heal
-- goes off.
local HEALS = {
    PALADIN = { spell = "Holy Light", casts = { "Holy Light" } },
    PRIEST = { spell = "Lesser Heal", casts = { "Heal", "Lesser Heal" } },
    DRUID = { spell = "Healing Touch", casts = { "Healing Touch" } },
    SHAMAN = { spell = "Healing Wave", casts = { "Healing Wave" } },
}

-- The highest rank of a spell this character has learned, from the
-- spellbook ("Rank 3"); nil if the spellbook shows no ranks for it. Forever
-- lists every rank, and /cast with the name alone cast Rank 1 (seen
-- 2026-11-22: Lesser Heal Rank 1, 2 and 3 in a priest's spellbook).
function ns.BestRank(name)
    local book = C_SpellBook
    if not (book and book.GetSpellBookItemName) then return nil end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local future = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
    local best, gap = nil, 0
    for index = 1, 1000 do
        local ok, found, sub = pcall(book.GetSpellBookItemName, index, bank)
        if not ok or type(found) ~= "string" then
            -- Past the end of the spellbook.
            gap = gap + 1
            if gap > 30 then break end
        else
            gap = 0
            if found == name then
                local learned = true
                if future and book.GetSpellBookItemInfo then
                    local okInfo, info = pcall(book.GetSpellBookItemInfo, index, bank)
                    if okInfo and type(info) == "table" and info.itemType == future then learned = false end
                end
                local rank = type(sub) == "string" and tonumber(sub:match("(%d+)")) or nil
                if learned and rank and (not best or rank > best) then best = rank end
            end
        end
    end
    return best
end

-- Heal Me's text: one line, the best heal this character knows at its
-- best rank ("Lesser Heal(Rank 3)", or "Heal(Rank 1)" once a priest has
-- Heal). By name alone if the spellbook shows no ranks.
function ns.HealBody(heal)
    local cast = heal.spell
    for _, spell in ipairs(heal.casts) do
        local rank = ns.BestRank(spell)
        if rank then
            cast = ("%s(Rank %d)"):format(spell, rank)
            break
        elseif ns.Knows(spell) then
            cast = spell
            break
        end
    end
    return "#showtooltip\n/cast [@player] " .. cast
end

local function NoGearSets()
    if not (C_EquipmentSet and C_EquipmentSet.CreateEquipmentSet and C_EquipmentSet.SaveEquipmentSet
            and C_EquipmentSet.GetEquipmentSetID) then
        return "gear sets in this game"
    end
end

local function NoLeaveParty()
    if not (C_PartyInfo and C_PartyInfo.LeaveParty) then return "a way to leave from a macro" end
end

-- The quest item to use: one that starts a quest, else a quest item with a
-- use. Returns its item ID, or nil.
function ns.QuestItemID()
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo
            and C_Container.GetContainerItemQuestInfo) then
        return nil
    end
    local usable
    for bag = 0, 4 do
        local okSlots, slots = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (okSlots and type(slots) == "number") and slots or 0 do
            local okInfo, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
            local okQuest, quest = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
            if okInfo and type(info) == "table" and info.itemID and okQuest and type(quest) == "table" then
                if quest.questID and not quest.isActive then
                    return info.itemID                       -- starts a quest: the best choice
                end
                if not usable and quest.isQuestItem and C_Item and C_Item.GetItemSpell then
                    local okSpell, spell = pcall(C_Item.GetItemSpell, info.itemID)
                    if okSpell and spell then usable = info.itemID end
                end
            end
        end
    end
    return usable
end

-- Whether the item is in the game's Food & Drink category (consumable
-- class 0, subclass 5). Read without the item's details being loaded.
local function IsFoodOrDrink(id)
    if not (C_Item and C_Item.GetItemInfoInstant) then return false end
    local ok, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, id)
    return ok and classID == 0 and subclassID == 5
end

-- The best item in the bags that matches: either a set of spell names
-- (an item's use is a spell: bandages cast "First Aid", water "Drink",
-- healing potions "Healing Potion") or a function(itemID, spellName).
-- Best: the highest item level the character is high enough to use.
-- Returns its item ID, or nil.
--
-- Until the game has loaded an item's details it reports no spell for it.
-- Such an item is asked for, and the macros are brought up to date again
-- when it arrives (GET_ITEM_INFO_RECEIVED). Eat & Drink once missed the
-- food this way and used only the water (found 2026-11-17).
function ns.BestBagItem(spells)
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo
            and C_Item and C_Item.GetItemSpell) then
        return nil
    end
    local okLevel, myLevel = pcall(UnitLevel, "player")
    myLevel = (okLevel and type(myLevel) == "number") and myLevel or 100
    local best, bestLevel
    for bag = 0, 4 do
        local okSlots, slots = pcall(C_Container.GetContainerNumSlots, bag)
        for slot = 1, (okSlots and type(slots) == "number") and slots or 0 do
            local okInfo, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
            local id = okInfo and type(info) == "table" and info.itemID
            if id then
                local okSpell, spell = pcall(C_Item.GetItemSpell, id)
                if not (okSpell and spell) and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, id)
                end
                local matches
                if not okSpell or type(spell) ~= "string" then
                    matches = false
                elseif type(spells) == "function" then
                    matches = spells(id, spell)
                else
                    matches = spells[spell]
                end
                if matches then
                    local itemLevel, minLevel = 0, 0
                    if C_Item.GetItemInfo then
                        local okItem, _, _, _, level, min = pcall(C_Item.GetItemInfo, id)
                        if okItem then itemLevel, minLevel = tonumber(level) or 0, tonumber(min) or 0 end
                    end
                    if minLevel <= myLevel and (not bestLevel or itemLevel > bestLevel) then
                        best, bestLevel = id, itemLevel
                    end
                end
            end
        end
    end
    return best
end

local BANDAGE = { ["First Aid"] = true }
local DRINK_SPELLS = { ["Drink"] = true, ["Refreshment"] = true }

-- Buff food and drink (the ones that make you "Well Fed") are kept for when
-- you want the buff: Eat & Drink skips anything whose tooltip mentions it.
-- An item whose tooltip has not loaded yet is not judged (nor remembered).
local givesBuff = {}
local function GivesBuff(id)
    if givesBuff[id] ~= nil then return givesBuff[id] end
    if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return false end
    local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
    if not (ok and type(data) == "table" and type(data.lines) == "table" and #data.lines > 0) then return false end
    local buff = false
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and not (issecretvalue and issecretvalue(text))
                and text:lower():find("well fed", 1, true) then
            buff = true
        end
    end
    givesBuff[id] = buff
    return buff
end

-- Plain food: what casts "Food" (or "Refreshment", food and drink at once),
-- or anything else in the Food & Drink category that is not a drink, since
-- Forever calls eating "Nutritious Food"; never buff food.
local function FOOD(id, spell)
    if GivesBuff(id) then return false end
    if spell == "Food" or spell == "Refreshment" then return true end
    return not DRINK_SPELLS[spell] and IsFoodOrDrink(id)
end
-- Plain drink: what casts "Drink" (or "Refreshment"); never a buff drink.
local function DRINK(id, spell)
    return DRINK_SPELLS[spell] and not GivesBuff(id)
end
local POTION = { ["Healing Potion"] = true }
local HEARTHSTONE = 6948

-- A body that uses one item, or says in chat that there is none.
local function UseItem(id, missing)
    if id then return ("#showtooltip item:%d\n/use item:%d"):format(id, id) end
    return "/run print(\"GamepadMacros: no " .. missing .. " in your bags.\")"
end

function ns.BandageBody() return UseItem(ns.BestBagItem(BANDAGE), "bandage") end
function ns.PotionBody() return UseItem(ns.BestBagItem(POTION), "healing potion") end
-- Eat & Drink takes two steps, and the button shows the step it is on:
--   "food":  uses your best plain food (where it starts)
--   "drink": uses your best plain drink, from the moment the food's short
--            cast finishes and you sit down eating
-- and goes back to "food" when you drink, move, stand up (the eating buff
-- goes), go into combat, or, if the eating buff was never seen, after
-- SIT_SECONDS. Both in one press does not work in Forever: the drink
-- cancels the food's short cast (found 2026-11-17). The macro is rewritten
-- for each step, and has the question-mark icon, so the button shows the
-- item. (A /castsequence's icon did not follow its steps.)
local SIT_SECONDS = 30
ns.eatStep = "food"
local eatSpell, eatName, eatAura   -- the food's spell, and its buff once seen
local eatToken = 0                 -- tells a stale timer from the current sitting

local function Usable(value)
    return value ~= nil and not (issecretvalue and issecretvalue(value))
end

function ns.FoodAndDrink()
    return ns.BestBagItem(FOOD), ns.BestBagItem(DRINK)
end

function ns.SetEatStep(step)
    if step == "food" then eatSpell, eatName, eatAura = nil, nil, nil end
    if ns.eatStep == step then return end
    ns.eatStep = step
    ns.UpdateItemMacros()
end

-- Whether a spell the player just cast is the one this item casts.
local function CastsItem(spellID, itemID)
    if not itemID then return false end
    local ok, name, id = pcall(C_Item.GetItemSpell, itemID)
    if not ok then return false end
    if Usable(id) and id == spellID then return true end
    if type(name) == "string" and C_Spell and C_Spell.GetSpellName then
        local okName, cast = pcall(C_Spell.GetSpellName, spellID)
        if okName and cast == name then return true end
    end
    return false
end

-- UNIT_SPELLCAST_SUCCEEDED for the player.
function ns.OnPlayerCast(spellID)
    if not Usable(spellID) then return end
    local food, drink = ns.FoodAndDrink()
    if CastsItem(spellID, food) then
        ns.SetEatStep("drink")
        eatSpell, eatAura = spellID, nil
        local okName, name = pcall(C_Spell.GetSpellName, spellID)
        eatName = okName and name or nil
        eatToken = eatToken + 1
        local token = eatToken
        if C_Timer and C_Timer.After then
            C_Timer.After(SIT_SECONDS, function()
                -- Only if this sitting's eating buff was never seen; when it
                -- was, its going is what sends the button back.
                if token == eatToken and ns.eatStep == "drink" and not eatAura then
                    ns.SetEatStep("food")
                end
            end)
        end
    elseif CastsItem(spellID, drink) then
        ns.SetEatStep("food")
    end
end

-- UNIT_AURA for the player: notices the eating buff arriving, and going
-- (standing up, or the food is finished).
function ns.OnPlayerAura(info)
    if ns.eatStep ~= "drink" or type(info) ~= "table" then return end
    if type(info.addedAuras) == "table" then
        for _, aura in ipairs(info.addedAuras) do
            if Usable(aura.spellId) and (aura.spellId == eatSpell or (eatName and aura.name == eatName)) then
                eatAura = aura.auraInstanceID
            end
        end
    end
    if eatAura and type(info.removedAuraInstanceIDs) == "table" then
        for _, id in ipairs(info.removedAuraInstanceIDs) do
            if id == eatAura then
                ns.SetEatStep("food")
                return
            end
        end
    end
end

function ns.EatDrinkBody()
    local food, drink = ns.FoodAndDrink()
    if food and drink then
        if ns.eatStep == "drink" then return UseItem(drink, "drink") end
        return UseItem(food, "food")
    end
    return UseItem(food or drink, "food or drink")
end

function ns.QuestItemBody()
    local id = ns.QuestItemID()
    if id then
        return ("#showtooltip item:%d\n/use item:%d"):format(id, id)
    end
    return "/run print(\"GamepadMacros: no quest item to use in your bags.\")"
end

-- The macros for this character's class, in the order the window lists
-- them. Macros that use an item or spell show it with #showtooltip; the
-- others (emotes, gear, leaving) keep their own icon.
function ns.List()
    local _, class = UnitClass("player")
    local list = {}
    local heal = HEALS[class]
    if heal then
        list[#list + 1] = { name = "Heal Me", desc = heal.spell .. " on yourself, whatever you have targeted",
            how = "Heals you with your best rank, without changing your target and without aiming at your own frame. It always heals you, even with a friend targeted. When you learn a new rank, the macro is updated to it (unless you have edited it).",
            spells = { heal.spell }, body = ns.HealBody(heal) }
    end
    list[#list + 1] = { name = ns.QUEST_ITEM, general = true, icon = "INV_Misc_Note_06",
        desc = "Uses the quest item in your bags",
        how = "Uses the item in your bags that starts a quest, or else a quest item you can use. GamepadMacros keeps the macro pointing at the right item as your bags change (outside combat).",
        Body = ns.QuestItemBody, body = ns.QuestItemBody() }
    list[#list + 1] = { name = "Bandage", general = true, icon = "INV_Misc_Bandage_15",
        desc = "Uses your best bandage on yourself",
        how = "Uses the best bandage in your bags that you can use. GamepadMacros keeps the macro on your best one as your bags change (outside combat).",
        Body = ns.BandageBody, body = ns.BandageBody() }
    list[#list + 1] = { name = "Eat & Drink", general = true, icon = "INV_Misc_Food_15",
        desc = "Eats your best food, then drinks on the next press",
        how = "Press once to sit down with your best food. As soon as you are eating, the button turns into your best drink: press again to drink as well, and you keep eating. It turns back into the food when you drink, move, stand up or go into combat. Buff food and drink (Well Fed) are left for you to use yourself. With only one of them in your bags, it uses that.",
        Body = ns.EatDrinkBody, body = ns.EatDrinkBody() }
    list[#list + 1] = { name = "Potion", general = true, icon = "INV_Potion_51",
        desc = "Drinks your best healing potion",
        how = "Drinks the best healing potion in your bags that you can use, for an emergency in a fight.",
        Body = ns.PotionBody, body = ns.PotionBody() }
    list[#list + 1] = { name = "Hearth", general = true, icon = "INV_Misc_Rune_01",
        desc = "Uses your Hearthstone",
        how = "Uses your Hearthstone to go back to your inn, with no bag to open.",
        body = ("#showtooltip item:%d\n/use item:%d"):format(HEARTHSTONE, HEARTHSTONE) }
    list[#list + 1] = { name = "Save Gear", general = true, icon = "INV_Chest_Chain",
        desc = "Saves what you are wearing as a gear set",
        how = "Saves everything you are wearing as the gear set \"" .. GEAR_SET .. "\", replacing what was saved before. Wear Gear puts it back on.",
        needs = NoGearSets,
        body = "/run local s=C_EquipmentSet local i=s.GetEquipmentSetID(\"" .. GEAR_SET .. "\") "
            .. "if i then s.SaveEquipmentSet(i) else s.CreateEquipmentSet(\"" .. GEAR_SET .. "\") end "
            .. "print(\"GamepadMacros: gear saved.\")" }
    list[#list + 1] = { name = "Wear Gear", general = true, icon = "INV_Shoulder_02",
        desc = "Puts your saved gear set back on",
        how = "Equips the gear set Save Gear saved, every piece at once. Not in combat: the game does not allow it.",
        needs = NoGearSets, body = "/equipset " .. GEAR_SET }
    list[#list + 1] = { name = "Leave Group", general = true, icon = "Ability_Rogue_Sprint",
        desc = "Leaves your party or raid", how = "Leaves the party or raid you are in, with no menu to find.",
        needs = NoLeaveParty, body = "/run C_PartyInfo.LeaveParty()" }
    list[#list + 1] = { name = "Hello", general = true, icon = "INV_Misc_Toy_10",
        desc = "Waves at your target", how = "Waves (the /wave emote), at your target if you have one.", body = "/wave" }
    list[#list + 1] = { name = "Thanks", general = true, icon = "INV_Misc_Gift_01",
        desc = "Thanks your target", how = "Thanks your target (the /thank emote), for a buff or a hand in a fight.", body = "/thank" }
    list[#list + 1] = { name = "Follow Me", general = true, icon = "Ability_Tracking",
        desc = "Asks others to follow you", how = "Waves others on to follow you (the /followme emote).", body = "/followme" }
    list[#list + 1] = { name = "Need Help", general = true, icon = "Spell_Holy_SealOfProtection",
        desc = "Calls for help", how = "Calls out for help (the /helpme emote).", body = "/helpme" }
    return list
end
