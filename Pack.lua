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
