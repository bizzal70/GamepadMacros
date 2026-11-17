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

-- The heal each class can cast on itself, from level 1. A priest learns
-- Heal later: the first line casts it once known, else Lesser Heal goes off.
local HEALS = {
    PALADIN = { spell = "Holy Light", body = "#showtooltip Holy Light\n/cast [@player] Holy Light" },
    PRIEST = { spell = "Lesser Heal", body = "#showtooltip\n/cast [@player] Heal\n/cast [@player] Lesser Heal" },
    DRUID = { spell = "Healing Touch", body = "#showtooltip Healing Touch\n/cast [@player] Healing Touch" },
    SHAMAN = { spell = "Healing Wave", body = "#showtooltip Healing Wave\n/cast [@player] Healing Wave" },
}

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
local DRINK = { ["Drink"] = true, ["Refreshment"] = true }
-- Food: what casts "Food", or anything in the Food & Drink category that is
-- not a drink, whatever this client calls eating.
local function FOOD(id, spell)
    if spell == "Food" or spell == "Refreshment" then return true end
    return not DRINK[spell] and IsFoodOrDrink(id)
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
-- Whether the player has the buff an item gives while being used (sitting
-- down eating or drinking). Looked up by the item's spell, by ID and else by
-- name; only out of combat, where buffs are not hidden from addons.
local function Using(itemID)
    if not (C_UnitAuras and C_Item and C_Item.GetItemSpell) then return false end
    local ok, name, spellID = pcall(C_Item.GetItemSpell, itemID)
    if not ok then return false end
    if type(spellID) == "number" and C_UnitAuras.GetPlayerAuraBySpellID then
        local okAura, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if okAura and aura then return true end
    end
    if type(name) == "string" and C_UnitAuras.GetAuraDataBySpellName then
        local okAura, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if okAura and aura then return true end
    end
    return false
end

-- Food first, then drink, one per press, the button showing which comes
-- next. In Forever eating starts with a short cast, and using the drink in
-- the same press cancels it, so only the drink happened (found 2026-11-17);
-- drinking once already eating keeps both. A /castsequence did the two
-- presses, but its icon did not follow the steps, so instead the macro is
-- rewritten as you sit down: the food until you are eating, then the drink,
-- and the food again once you get up (UNIT_AURA).
function ns.EatDrinkBody()
    local food, drink = ns.BestBagItem(FOOD), ns.BestBagItem(DRINK)
    if food and drink and food ~= drink then
        if Using(food) and not Using(drink) then
            return UseItem(drink, "drink")
        end
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
            how = "Heals you, without changing your target and without aiming at your own frame. It always heals you, even with a friend targeted.",
            spells = { heal.spell }, body = heal.body }
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
        how = "Press once to sit down with your best food. Once you are eating, the button turns into your best drink: press again to drink as well, and you keep eating, getting health and mana back together. When you get up it turns back into the food. (Both in one press does not work: the drink cancels the food's short cast.) With only one of them in your bags, it uses that.",
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
