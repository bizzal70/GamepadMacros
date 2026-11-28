local addonName, ns = ...

-- "To bar": puts a macro on the first empty action button that is on
-- screen now, so it needs no dragging (the hardest step with a controller).
-- The buttons are found by what they are, any button with an action slot,
-- so this works with the default bars, the controller layout's buttons and
-- bar addons alike. The same file is in MacroKit.

local LAST_SLOT = 200

local function SlotOf(frame)
    local value = rawget(frame, "action")
    if value == nil and frame.GetAttribute then value = frame:GetAttribute("action") end
    return tonumber(value)
end

-- The action slots of the action buttons on screen now, lowest first.
function ns.ShownActionSlots()
    local slots, seen = {}, {}
    if type(EnumerateFrames) ~= "function" then return slots end
    local frame = EnumerateFrames()
    while frame do
        local ok, slot = pcall(function()
            if not (frame:IsObjectType("CheckButton") or frame:IsObjectType("Button")) then return nil end
            if not frame:IsVisible() then return nil end
            return SlotOf(frame)
        end)
        if ok and slot and slot >= 1 and not seen[slot] then
            seen[slot] = true
            slots[#slots + 1] = slot
        end
        frame = EnumerateFrames(frame)
    end
    table.sort(slots)
    return slots
end

-- Macro name -> true for each macro on an action bar.
function ns.MacrosOnBars()
    local on = {}
    if type(GetActionInfo) ~= "function" then return on end
    for slot = 1, LAST_SLOT do
        local ok, kind, id = pcall(GetActionInfo, slot)
        if ok and kind == "macro" then
            local okText, text = pcall(GetActionText, slot)
            if okText and type(text) == "string" and text ~= "" then
                on[text] = true
            elseif type(id) == "number" then
                local okInfo, name = pcall(GetMacroInfo, id)
                if okInfo and type(name) == "string" then on[name] = true end
            end
        end
    end
    return on
end

-- Puts the named macro on the first empty action button on screen.
-- Returns whether it did.
function ns.ToBar(name)
    if InCombatLockdown() then
        ns.Print("Action bars can't be changed in combat.")
        return false
    end
    if not ns.Exists(name) then return false end
    if ns.MacrosOnBars()[name] then
        ns.Print(name .. " is already on your action bars.")
        return false
    end
    for _, slot in ipairs(ns.ShownActionSlots()) do
        local okHas, has = pcall(HasAction, slot)
        if okHas and not has then
            pcall(ClearCursor)
            pcall(PickupMacro, name)
            local placed = pcall(PlaceAction, slot)
            pcall(ClearCursor)
            if placed then
                ns.Print("Put " .. name .. " on the first empty button of your action bars.")
                ns.RefreshWindow()
                return true
            end
            break
        end
    end
    ns.Print("There's no empty action button on screen for " .. name .. ". Clear one, or drag the macro from the window onto a button.")
    return false
end
