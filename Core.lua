local addonName, ns = ...

-- Adds the gamepad macros (Pack.lua) to the macro lists when asked: from
-- the window, or /gpm add. Never by itself. A macro is only ever added
-- under a name not already in use, so macros you made are never touched.

local ICON = 134400      -- the question mark: with #showtooltip, the macro shows what it uses

local accountDefaults = {
    minimapButton = true,
    -- Lower right on the rim (radians, 0 = east), clear of the author's
    -- other addons' buttons.
    minimapAngle = -1.2,
    generalMade = {},    -- name -> true for each account-wide macro this addon added
}
local charDefaults = {
    made = {},           -- name -> true for each character macro this addon added (Heal Me)
}

function ns.Print(msg)
    print("|cff7fc8ffGamepadMacros|r: " .. tostring(msg))
end

-- Whether this character knows a spell, by name. If the client cannot say,
-- the answer is yes, so nothing is held back for good.
function ns.Knows(name)
    if not (C_Spell and C_Spell.GetSpellInfo) then return true end
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    if not ok then return true end
    if type(info) ~= "table" or not info.spellID then return false end
    if type(IsPlayerSpell) == "function" then
        local ok2, known = pcall(IsPlayerSpell, info.spellID)
        if ok2 and known ~= nil then return known and true or false end
    end
    return true
end

function ns.Exists(name)
    local ok, index = pcall(GetMacroIndexByName, name)
    return ok and type(index) == "number" and index > 0
end

-- Free macro slots: account-wide General ones, or the character's own.
local function FreeSlots(general)
    local max = general and (MAX_ACCOUNT_MACROS or 120) or (MAX_CHARACTER_MACROS or 18)
    local ok, account, perCharacter = pcall(GetNumMacros)
    local used = general and account or perCharacter
    if not ok or type(used) ~= "number" then return max end
    return max - used
end

-- Where a macro stands: "have" (in the macro lists), "needs" (a spell or a
-- game feature is missing; also returns what) or "ready" (can be added).
function ns.Status(macro)
    if ns.Exists(macro.name) then return "have" end
    for _, spell in ipairs(macro.spells or {}) do
        if not ns.Knows(spell) then return "needs", spell end
    end
    local missing = macro.needs and macro.needs()
    if missing then return "needs", missing end
    return "ready"
end

-- Adds one macro. With quiet, says nothing when it works. Returns whether
-- it was added.
function ns.AddOne(macro, quiet)
    if InCombatLockdown() then
        ns.Print("Macros cannot be added in combat.")
        return false
    end
    if ns.Status(macro) ~= "ready" then return false end
    if FreeSlots(macro.general) <= 0 then
        ns.Print("Your " .. (macro.general and "General" or "character") .. " macros are full, so " .. macro.name .. " was not added.")
        return false
    end
    local body = macro.Body and macro.Body() or macro.body
    local ok, index = pcall(CreateMacro, macro.name, macro.icon or ICON, body, not macro.general)
    if not (ok and index) and macro.icon then
        -- An icon this client does not know: the question mark instead.
        ok, index = pcall(CreateMacro, macro.name, ICON, body, not macro.general)
    end
    if ok and index then
        if macro.general then ns.db.generalMade[macro.name] = true else ns.char.made[macro.name] = true end
        if not quiet then ns.Print("Added " .. macro.name .. ". Drag it from the window or /macro to your bars.") end
        ns.RefreshWindow()
        return true
    end
    ns.Print("The game would not create " .. macro.name .. ".")
    return false
end

-- Adds every macro this character can use that is missing.
function ns.AddAll()
    if InCombatLockdown() then
        ns.Print("Macros cannot be added in combat.")
        return
    end
    local added, waiting = {}, {}
    for _, macro in ipairs(ns.List()) do
        local status, missing = ns.Status(macro)
        if status == "ready" then
            if ns.AddOne(macro, true) then added[#added + 1] = macro.name end
        elseif status == "needs" then
            waiting[#waiting + 1] = macro.name .. " (" .. missing .. ")"
        end
    end
    if #added > 0 then
        ns.Print("Added: " .. table.concat(added, ", ") .. ". Put them on your gamepad's bars from the window or /macro.")
    else
        ns.Print("You already have every gamepad macro this character can use.")
    end
    if #waiting > 0 then
        ns.Print("Not added: " .. table.concat(waiting, ", ") .. ".")
    end
    ns.RefreshWindow()
end

-- Deletes the macros this addon added. Any you made yourself stay.
function ns.Remove()
    if InCombatLockdown() then
        ns.Print("Macros cannot be removed in combat.")
        return
    end
    local removed = {}
    for _, made in ipairs({ ns.char.made, ns.db.generalMade }) do
        for name in pairs(made) do
            if ns.Exists(name) and pcall(DeleteMacro, GetMacroIndexByName(name)) then
                removed[#removed + 1] = name
            end
            made[name] = nil
        end
    end
    table.sort(removed)
    ns.RefreshWindow()
    if #removed > 0 then
        ns.Print("Removed: " .. table.concat(removed, ", ") .. ".")
    else
        ns.Print("There were no GamepadMacros macros to remove.")
    end
end

-- Whether this addon made the macro of this name.
function ns.Made(name)
    return (ns.char and ns.char.made[name]) or (ns.db and ns.db.generalMade[name]) or false
end

-- Whether a macro's text has exactly the shape this addon writes for the
-- macros that use something from the bags. Used to recognise our own macro
-- when the record that we made it has been lost: saved settings are only
-- written when the game closes normally, so after a crash the macro exists
-- but the record does not, and it was never kept up to date again (Eat &
-- Drink stuck on water only, found 2026-11-17).
local OUR_SHAPES = {
    "^#showtooltip item:%d+\n/use item:%d+$",
    "^#showtooltip item:%d+\n/use item:%d+\n/use item:%d+$",
    "^#showtooltip\n/castsequence reset=%d+ item:%d+, item:%d+$",
    '^/run print%("GamepadMacros: no [^"]*"%)$',
}
-- The game can hand back a macro's text with a line break (or a carriage
-- return) after it that was never typed; it is ignored when comparing.
local function Trim(text)
    return (text:gsub("\r", ""):gsub("%s+$", ""))
end
ns.Trim = Trim

function ns.LooksMade(body)
    if type(body) ~= "string" then return false end
    body = Trim(body)
    for _, shape in ipairs(OUR_SHAPES) do
        if body:find(shape) then return true end
    end
    return false
end

-- Keeps the macros that use something from the bags (Quest Item, Bandage,
-- Eat & Drink, Potion) on the right item, whenever the bags change. Only
-- touches a macro this addon made (or one in exactly its shape), and never
-- in combat (the game does not allow it).
function ns.UpdateItemMacros()
    if InCombatLockdown() or not ns.db then return end
    for _, macro in ipairs(ns.List()) do
        if macro.Body then
            local ok, index = pcall(GetMacroIndexByName, macro.name)
            if ok and type(index) == "number" and index > 0 then
                local okInfo, _, _, current = pcall(GetMacroInfo, index)
                if not ns.db.generalMade[macro.name] and okInfo and ns.LooksMade(current) then
                    ns.db.generalMade[macro.name] = true
                end
                if ns.db.generalMade[macro.name] then
                    local body = macro.Body()
                    if not (okInfo and type(current) == "string" and Trim(current) == body) then
                        local okEdit, problem = pcall(EditMacro, index, nil, nil, body)
                        ns.lastEdit = ns.lastEdit or {}
                        ns.lastEdit[macro.name] = okEdit and "edited" or ("refused: " .. tostring(problem))
                    end
                end
            end
        end
    end
end

-- MacroKit 0.6.0 to 0.6.2 carried these macros. Ones it added are taken
-- over, so this addon keeps the quest item up to date and can remove them.
local function AdoptFromMacroKit()
    local old = MacroKitDB and MacroKitDB.generalMade
    if type(old) ~= "table" then return end
    for _, macro in ipairs(ns.List()) do
        if old[macro.name] then
            ns.db.generalMade[macro.name] = true
            old[macro.name] = nil
        end
    end
end

SLASH_GAMEPADMACROS1 = "/gamepadmacros"
SLASH_GAMEPADMACROS2 = "/gpm"
SlashCmdList.GAMEPADMACROS = function(msg)
    local command = (msg or ""):lower():match("^%s*(%S*)")
    if command == "" or command == "window" then
        ns.ToggleWindow()
    elseif command == "add" then
        ns.AddAll()
    elseif command == "remove" then
        ns.Remove()
    elseif command == "debug" then
        -- What the game reports for each macro that follows the bags.
        ns.UpdateItemMacros()
        for _, macro in ipairs(ns.List()) do
            if macro.Body then
                local okIndex, index = pcall(GetMacroIndexByName, macro.name)
                local current
                if okIndex and type(index) == "number" and index > 0 then
                    current = select(3, GetMacroInfo(index))
                end
                ns.Print(("%s: index %s, made %s, our shape %s, last edit %s"):format(macro.name, tostring(index),
                    tostring(ns.db.generalMade[macro.name] or false), tostring(ns.LooksMade(current)),
                    tostring(ns.lastEdit and ns.lastEdit[macro.name] or "none")))
                ns.Print("  now: " .. (current and ("%q"):format(current) or "none"))
                ns.Print("  wanted: " .. ("%q"):format(macro.Body()))
            end
        end
    elseif command == "button" then
        ns.db.minimapButton = not ns.db.minimapButton
        ns.UpdateMinimapButton()
        ns.Print("Minimap button " .. (ns.db.minimapButton and "on (it shows once you use a controller)." or "off. Type /gpm button to bring it back."))
    else
        ns.Print("/gpm - open the GamepadMacros window")
        ns.Print("/gpm add - add every gamepad macro you are missing")
        ns.Print("/gpm remove - delete the macros GamepadMacros added")
        ns.Print("/gpm button - minimap button on or off")
    end
end

-- Entry in the minimap's addon list.
function GamepadMacros_OnAddonCompartmentClick()
    ns.ToggleWindow()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= addonName then return end
        GamepadMacrosDB = GamepadMacrosDB or {}
        for key, value in pairs(accountDefaults) do
            if GamepadMacrosDB[key] == nil then GamepadMacrosDB[key] = type(value) == "table" and {} or value end
        end
        ns.db = GamepadMacrosDB
        GamepadMacrosCharDB = GamepadMacrosCharDB or {}
        for key, value in pairs(charDefaults) do
            if GamepadMacrosCharDB[key] == nil then GamepadMacrosCharDB[key] = type(value) == "table" and {} or value end
        end
        ns.char = GamepadMacrosCharDB
        self:UnregisterEvent("ADDON_LOADED")
        -- Registering an event this client does not have throws, hence pcall.
        for _, name in ipairs({ "PLAYER_LOGIN", "GAME_PAD_ACTIVE_CHANGED", "BAG_UPDATE_DELAYED", "QUEST_ACCEPTED",
                "QUEST_REMOVED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "UPDATE_MACROS", "SPELLS_CHANGED",
                "GET_ITEM_INFO_RECEIVED" }) do
            pcall(self.RegisterEvent, self, name)
        end
        ns.UpdateMinimapButton()
    elseif event == "PLAYER_LOGIN" then
        AdoptFromMacroKit()
        ns.UpdateItemMacros()
    elseif event == "GAME_PAD_ACTIVE_CHANGED" then
        -- The first controller button or stick: the minimap button shows
        -- for the rest of the session.
        if arg and not ns.controllerUsed then
            ns.controllerUsed = true
            ns.UpdateMinimapButton()
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "UPDATE_MACROS" or event == "SPELLS_CHANGED" then
        ns.RefreshWindow()
    else
        -- Bags, quests, combat over, or an item's details arriving: the
        -- items the macros use may have changed.
        ns.UpdateItemMacros()
        ns.RefreshWindow()
    end
end)
