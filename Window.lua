local addonName, ns = ...

-- The Gamepad macros window: one row per macro (icon, name, what it does,
-- whether you have it) with an Add button; macros you have can be dragged,
-- or clicked up, onto the action bars. Hover a row for how it works.
-- Drawn from plain colours and the game's own icons.

local ACCENT_R, ACCENT_G, ACCENT_B = 0.50, 0.78, 1.00
local WIDTH = 440
local PADDING = 14
local ROW_HEIGHT = 36
local LIST_TOP = 74
local FOOTER_HEIGHT = 46
local QUESTION_MARK = 134400

local window, intro, addAllButton, removeButton
local rows = {}

local function Fill(frame, r, g, b, a)
    local texture = frame:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints()
    texture:SetColorTexture(r, g, b, a)
    return texture
end

local function Outline(frame, alpha)
    local function Edge(point1, point2, isVertical)
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(ACCENT_R, ACCENT_G, ACCENT_B, alpha)
        edge:SetPoint(point1)
        edge:SetPoint(point2)
        if isVertical then edge:SetWidth(1) else edge:SetHeight(1) end
    end
    Edge("TOPLEFT", "TOPRIGHT", false)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", false)
    Edge("TOPLEFT", "BOTTOMLEFT", true)
    Edge("TOPRIGHT", "BOTTOMRIGHT", true)
end

local function Label(parent, font, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetJustifyH(justify or "LEFT")
    return text
end

local function TextButton(parent, width, text, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, 24)
    Fill(button, 1, 1, 1, 0.06)
    Outline(button, 0.4)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.08)
    button.label = Label(button, "GameFontHighlightSmall", "CENTER")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    button:SetScript("OnClick", function(self)
        if self.active ~= false then onClick(self) end
    end)
    function button.SetActive(self, active)
        self.active = active
        self.label:SetTextColor(active and 1 or 0.5, active and 1 or 0.5, active and 1 or 0.5)
    end
    return button
end

local function Icon(macro)
    if macro.icon then return "Interface\\Icons\\" .. macro.icon end
    local spell = macro.spells and macro.spells[1]
    if spell and C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spell)
        if ok and icon then return icon end
    end
    return QUESTION_MARK
end

-- Puts a macro on the cursor, ready to drop onto an action bar.
local function PickUp(macro)
    if not macro or not ns.Exists(macro.name) then return end
    pcall(PickupMacro, macro.name)
end

local function ShowTooltip(row)
    local macro = row.macro
    if not macro then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(macro.name)
    GameTooltip:AddLine(macro.how or macro.desc, 1, 1, 1, true)
    GameTooltip:AddLine(" ")
    local body = macro.Body and macro.Body() or macro.body
    for line in (body .. "\n"):gmatch("(.-)\n") do
        GameTooltip:AddLine(line, 0.6, 0.8, 1)
    end
    GameTooltip:AddLine(" ")
    local status, missing = ns.Status(macro)
    if status == "have" then
        GameTooltip:AddLine("Drag onto your action bars, or click to pick it up.", 0.25, 1, 0.25, true)
    elseif status == "ready" then
        GameTooltip:AddLine("Click Add to put it in your macros.", 1, 0.82, 0, true)
    else
        GameTooltip:AddLine("Needs " .. missing .. ".", 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, window)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", PADDING, -(LIST_TOP + (index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", -PADDING, -(LIST_TOP + (index - 1) * ROW_HEIGHT))
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.06)
    if index % 2 == 0 then Fill(row, 1, 1, 1, 0.025) end
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = Label(row, "GameFontHighlight")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.desc = Label(row, "GameFontDisableSmall")
    row.desc:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
    row.desc:SetWidth(WIDTH - PADDING * 2 - 40 - 70)
    row.status = Label(row, "GameFontHighlightSmall", "RIGHT")
    row.status:SetPoint("TOPRIGHT", -70, -4)
    row.add = TextButton(row, 56, "Add", function() ns.AddOne(row.macro) end)
    row.add:SetPoint("RIGHT", -4, 0)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() PickUp(row.macro) end)
    row:SetScript("OnClick", function() PickUp(row.macro) end)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
    return row
end

local function Refresh()
    local inCombat = InCombatLockdown()
    local list = ns.List()
    local addable, made = 0, false
    for index, macro in ipairs(list) do
        local row = rows[index] or CreateRow(index)
        row.macro = macro
        row.icon:SetTexture(Icon(macro))
        row.name:SetText(macro.name)
        row.desc:SetText(macro.desc or "")
        local status, missing = ns.Status(macro)
        if status == "have" then
            row.status:SetText("|cff40ff40In your macros|r")
            row.icon:SetDesaturated(false)
            row.add:Hide()
        elseif status == "ready" then
            addable = addable + 1
            row.status:SetText("|cffffd100Ready to add|r")
            row.icon:SetDesaturated(false)
            row.add:Show()
            row.add:SetActive(not inCombat)
        else
            row.status:SetText("|cff808080Needs " .. missing .. "|r")
            row.icon:SetDesaturated(true)
            row.add:Hide()
        end
        row:Show()
        if ns.Made(macro.name) then made = true end
    end
    for index = #list + 1, #rows do rows[index]:Hide() end
    window:SetHeight(LIST_TOP + #list * ROW_HEIGHT + FOOTER_HEIGHT + 8)
    addAllButton.label:SetText(addable > 0 and ("Add all (" .. addable .. ")") or "Add all")
    addAllButton:SetActive(addable > 0 and not inCombat)
    removeButton:SetActive(made and not inCombat)
end

local function CreateWindow()
    window = CreateFrame("Frame", addonName .. "Window", UIParent)
    window:SetWidth(WIDTH)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    Fill(window, 0.05, 0.05, 0.06, 0.97)
    Outline(window, 0.55)
    tinsert(UISpecialFrames, addonName .. "Window")

    local title = Label(window, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PADDING, -12)
    title:SetText("Gamepad macros")

    local close = CreateFrame("Button", nil, window)
    close:SetSize(30, 30)
    close:SetPoint("TOPRIGHT", -2, -2)
    local closeHover = close:CreateTexture(nil, "HIGHLIGHT")
    closeHover:SetAllPoints()
    closeHover:SetColorTexture(0.9, 0.2, 0.2, 0.45)
    local closeLabel = Label(close, "GameFontHighlightLarge", "CENTER")
    closeLabel:SetPoint("CENTER")
    closeLabel:SetText("x")
    close:SetScript("OnClick", function() window:Hide() end)

    intro = Label(window, "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", PADDING, -38)
    intro:SetWidth(WIDTH - PADDING * 2)
    intro:SetWordWrap(true)
    intro:SetText("Click Add, then drag a macro onto your gamepad's action bar. Hover over one to see how it works.")

    addAllButton = TextButton(window, 150, "Add all", function() ns.AddAll() end)
    addAllButton:SetPoint("BOTTOMLEFT", PADDING, 14)
    removeButton = TextButton(window, 200, "Remove GamepadMacros' macros", function() ns.Remove() end)
    removeButton:SetPoint("BOTTOMRIGHT", -PADDING, 14)
end

function ns.ToggleWindow()
    if not ns.db then return end
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        Refresh()
        window:Show()
    end
end

function ns.WindowShown()
    return window ~= nil and window:IsShown()
end

function ns.RefreshWindow()
    if window and window:IsShown() then Refresh() end
end
