local addonName, ns = ...

-- The Gamepad macros window: one row per macro (icon, name, what it does,
-- whether you have it) with an Add button; macros you have can be dragged,
-- or clicked up, onto the action bars. Hover a row for how it works.
-- Drawn from plain colours and the game's own icons.
--
-- Nothing in it has a fixed size. Every time it is shown, each piece of
-- text is measured and the rows, buttons and window are sized to fit it,
-- so a bigger text size, a different font or a small screen (a handheld)
-- never makes text overlap. If the whole window is still taller or wider
-- than the screen, it is scaled down to fit.

local ACCENT_R, ACCENT_G, ACCENT_B = 0.50, 0.78, 1.00
local BASE_WIDTH = 440      -- the window's width at the game's usual text size
local BASE_FONT = 12        -- GameFontHighlight's usual size
local PADDING = 14
local GAP = 8
local QUESTION_MARK = 134400

local window, title, close, closeLabel, intro, addAllButton, removeButton
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
    text.fontName = font
    return text
end

---------------------------------------------------------------------------
-- Measuring text
---------------------------------------------------------------------------

-- The size of one of the game's fonts, as this player has it.
local function FontSize(fontName)
    local font = fontName and _G[fontName]
    if font and font.GetFont then
        local ok, _, size = pcall(font.GetFont, font)
        if ok and type(size) == "number" and size > 0 then return size end
    end
    return BASE_FONT
end

local function Plain(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

-- How wide a piece of text is, as drawn; estimated from its length if the
-- game cannot say.
local function TextWidth(label)
    local ok, width = pcall(label.GetStringWidth, label)
    if ok and type(width) == "number" and width > 0 then return width end
    local text = label.GetText and label:GetText()
    return #Plain(text) * FontSize(label.fontName) * 0.55
end

-- How tall a piece of text is, wrapped at the width it was given.
local function TextHeight(label)
    local ok, height = pcall(label.GetStringHeight, label)
    if ok and type(height) == "number" and height > 0 then return height end
    return FontSize(label.fontName) * 1.25
end

local function ScreenSize()
    local ok, width, height = pcall(function() return UIParent:GetWidth(), UIParent:GetHeight() end)
    if ok and type(width) == "number" and width > 0 and type(height) == "number" and height > 0 then
        return width, height
    end
end

---------------------------------------------------------------------------

local function TextButton(parent, text, font, onClick)
    local button = CreateFrame("Button", nil, parent)
    Fill(button, 1, 1, 1, 0.06)
    Outline(button, 0.4)
    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.08)
    button.label = Label(button, font or "GameFontHighlightSmall", "CENTER")
    button.label:SetPoint("CENTER")
    button.label:SetText(text)
    button:SetScript("OnClick", function(self)
        if self.active ~= false then onClick(self) end
    end)
    function button.SetActive(self, active)
        self.active = active
        self.label:SetTextColor(active and 1 or 0.5, active and 1 or 0.5, active and 1 or 0.5)
    end
    -- Sizes the button to its label: room around the text, and never too
    -- small to tap.
    function button.Fit(self)
        local height = math.max(26, TextHeight(self.label) + 12)
        self.width = math.max(56, TextWidth(self.label) + 28)
        self.height = height
        self:SetSize(self.width, self.height)
        return self.width, self.height
    end
    button:Fit()
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
    -- The macro as it really is in the macro list; what it would be if not added yet.
    local body = macro.Body and macro.Body() or macro.body
    local okIndex, index = pcall(GetMacroIndexByName, macro.name)
    if okIndex and type(index) == "number" and index > 0 then
        local okInfo, _, _, current = pcall(GetMacroInfo, index)
        if okInfo and type(current) == "string" then body = current end
    end
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

-- A row's parts are anchored to each other here; their sizes and the row's
-- place in the list are set by Layout, once the text is known.
local function CreateRow(index)
    local row = CreateFrame("Button", nil, window)
    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.06)
    if index % 2 == 0 then Fill(row, 1, 1, 1, 0.025) end
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = Label(row, "GameFontHighlight")
    row.name:SetWordWrap(true)
    row.desc = Label(row, "GameFontDisableSmall")
    row.desc:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.desc:SetWordWrap(true)
    row.status = Label(row, "GameFontHighlightSmall", "RIGHT")
    row.status:SetPoint("RIGHT", -4, 0)
    row.status:SetWordWrap(true)
    row.add = TextButton(row, "Add", "GameFontHighlightSmall", function() ns.AddOne(row.macro) end)
    row.add:SetPoint("RIGHT", -4, 0)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() PickUp(row.macro) end)
    row:SetScript("OnClick", function() PickUp(row.macro) end)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[index] = row
    return row
end

-- Sizes and places everything to fit its text.
local function Layout(count)
    -- Wider when the game's text is bigger than usual.
    local width = math.floor(BASE_WIDTH * math.max(1, FontSize("GameFontHighlight") / BASE_FONT) + 0.5)
    local inner = width - PADDING * 2
    window:SetWidth(width)

    -- Title and close button.
    local titleHeight = TextHeight(title)
    local closeSize = math.max(30, TextHeight(closeLabel) + 12)
    close:SetSize(closeSize, closeSize)
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", PADDING, -12)
    title:SetWidth(inner - closeSize)
    local y = 12 + math.max(titleHeight, closeSize - 10) + GAP

    -- The line under the title, wrapped to the window's width.
    intro:ClearAllPoints()
    intro:SetPoint("TOPLEFT", PADDING, -y)
    intro:SetWidth(inner)
    y = y + TextHeight(intro) + GAP + 2

    -- Each row as tall as its text needs.
    local nameSize = FontSize("GameFontHighlight")
    local iconSize = math.max(28, math.floor(nameSize * 2.4 + 0.5))
    local statusMax = math.floor(inner * 0.34)
    for index = 1, count do
        local row = rows[index]
        row.icon:SetSize(iconSize, iconSize)
        local addWidth, addHeight = row.add:Fit()
        -- The right-hand side: the Add button, or the status, wrapped if long.
        local rightWidth, rightHeight
        if row.add:IsShown() then
            rightWidth, rightHeight = addWidth, addHeight
            row.status:SetText("")
        else
            row.status:SetWidth(0)
            rightWidth = math.min(TextWidth(row.status), statusMax)
            row.status:SetWidth(rightWidth)
            rightHeight = TextHeight(row.status)
        end
        local textLeft = 4 + iconSize + GAP
        local textWidth = math.max(60, inner - textLeft - rightWidth - GAP - 4)
        row.name:ClearAllPoints()
        row.name:SetWidth(textWidth)
        row.desc:SetWidth(textWidth)
        local textHeight = TextHeight(row.name) + 2 + TextHeight(row.desc)
        local height = math.ceil(math.max(iconSize + 8, textHeight + 12, rightHeight + 10))
        row.name:SetPoint("TOPLEFT", textLeft, -math.floor((height - textHeight) / 2))
        row:ClearAllPoints()
        row:SetHeight(height)
        row:SetPoint("TOPLEFT", PADDING, -y)
        row:SetPoint("TOPRIGHT", -PADDING, -y)
        y = y + height
    end

    -- The buttons along the bottom: side by side if they fit, else stacked.
    local addAllWidth, buttonHeight = addAllButton:Fit()
    local removeWidth = removeButton:Fit()
    addAllButton:ClearAllPoints()
    removeButton:ClearAllPoints()
    local footer
    if addAllWidth + GAP + removeWidth <= inner then
        addAllButton:SetPoint("BOTTOMLEFT", PADDING, 14)
        removeButton:SetPoint("BOTTOMRIGHT", -PADDING, 14)
        footer = buttonHeight + 28
    else
        removeButton:SetPoint("BOTTOMLEFT", PADDING, 14)
        addAllButton:SetPoint("BOTTOMLEFT", PADDING, 14 + buttonHeight + GAP)
        footer = buttonHeight * 2 + GAP + 28
    end
    local height = math.ceil(y + GAP + footer)
    window:SetHeight(height)

    -- Still bigger than the screen: scale the whole window down to fit.
    local screenWidth, screenHeight = ScreenSize()
    local scale = 1
    if screenWidth then
        scale = math.min(1, (screenWidth * 0.95) / width, (screenHeight * 0.92) / height)
    end
    window:SetScale(scale)
    return width, height, scale
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
    addAllButton.label:SetText(addable > 0 and ("Add all (" .. addable .. ")") or "Add all")
    addAllButton:SetActive(addable > 0 and not inCombat)
    removeButton:SetActive(made and not inCombat)
    local ok, problem = pcall(Layout, #list)
    if not ok and ns.Print then ns.Print("Could not lay out the window: " .. tostring(problem)) end
end

local function CreateWindow()
    window = CreateFrame("Frame", addonName .. "Window", UIParent)
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
    ns.CloseWithPadB(_G[addonName .. "Window"], addonName .. "Window")

    title = Label(window, "GameFontNormalLarge")
    title:SetText("Gamepad macros")

    close = CreateFrame("Button", nil, window)
    close:SetPoint("TOPRIGHT", -2, -2)
    local closeHover = close:CreateTexture(nil, "HIGHLIGHT")
    closeHover:SetAllPoints()
    closeHover:SetColorTexture(0.9, 0.2, 0.2, 0.45)
    closeLabel = Label(close, "GameFontHighlightLarge", "CENTER")
    closeLabel:SetPoint("CENTER")
    closeLabel:SetText("x")
    close:SetScript("OnClick", function() window:Hide() end)

    intro = Label(window, "GameFontHighlightSmall")
    intro:SetWordWrap(true)
    intro:SetText("Click Add, then drag a macro onto your gamepad's action bar. Hover over one to see how it works.")

    addAllButton = TextButton(window, "Add all", "GameFontHighlightSmall", function() ns.AddAll() end)
    removeButton = TextButton(window, "Remove GamepadMacros' macros", "GameFontHighlightSmall", function() ns.Remove() end)

    -- The screen or the game's interface scale changing: lay out again.
    window:SetScript("OnEvent", function(self) if self:IsShown() then Refresh() end end)
    for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        pcall(window.RegisterEvent, window, event)
    end
end

function ns.ToggleWindow()
    if not ns.db then return end
    if not window then CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        Refresh()
        window:Show()
        -- Text is measured once it is on screen, too, in case a font was
        -- not ready the first time.
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() if window:IsShown() then Refresh() end end)
        end
    end
end

function ns.WindowShown()
    return window ~= nil and window:IsShown()
end

function ns.RefreshWindow()
    if window and window:IsShown() then Refresh() end
end

-- For the tests: lays out the window as it is now.
function ns.LayoutWindow()
    if window then return Layout(#ns.List()) end
end
