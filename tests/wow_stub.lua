-- Minimal fake of the WoW API: just enough to run MacroKit end to end.
local frames = {}
local printed = {}
_G.PRINTED = printed

local function Stub()
    local o = { __scripts = {}, __events = {} }
    return setmetatable(o, { __index = function(_, k)
        if type(k) ~= "string" or not k:match("^%u") then return nil end
        if k == "SetScript" then return function(self, ev, fn) self.__scripts[ev] = fn end end
        if k == "RegisterEvent" then return function(self, ev)
            assert(not UNKNOWN_EVENTS or not UNKNOWN_EVENTS[ev], "no such event " .. ev)
            self.__events[ev] = true
        end end
        if k == "UnregisterEvent" then return function(self, ev) self.__events[ev] = nil end end
        -- Enough widget behaviour for the window tests to read back.
        if k == "Show" then return function(self) self.__shown = true end end
        if k == "Hide" then return function(self) self.__shown = false end end
        if k == "IsShown" then return function(self) return self.__shown ~= false and self.__shown ~= nil end end
        if k == "SetShown" then return function(self, v) assert(type(v) == "boolean", "SetShown needs a boolean"); self.__shown = v end end
        if k == "SetText" then return function(self, t) self.__text = t end end
        if k == "GetText" then return function(self) return self.__text end end
        if k == "SetTextColor" then return function(self, ...) self.__color = { ... } end end
        if k == "SetTexture" then return function(self, t) self.__texture = t end end
        if k == "SetDesaturated" then return function(self, v) self.__desaturated = v end end
        if k == "CreateTexture" or k == "CreateFontString" or k == "CreateLine" then
            return function(self) local child = Stub(); child.__parent = self; regions[#regions + 1] = child; return child end
        end
        return function() end
    end })
end

regions = {}         -- every texture and font string made, for the tests to search
function CreateFrame(_, name, parent) local f = Stub(); f.__parent = parent; frames[#frames + 1] = f; if name then _G[name] = f end; return f end
function Frames() return frames end
UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap")
Minimap.GetWidth = function() return 140 end
Minimap.GetCenter = function() return 100, 100 end
Minimap.GetEffectiveScale = function() return 1 end
GetCursorPosition = function() return 100, 200 end
UISpecialFrames = {}
tinsert = table.insert
TOOLTIP = {}
GameTooltip = CreateFrame("Frame", "GameTooltip")
GameTooltip.SetOwner = function() TOOLTIP = {} end
GameTooltip.AddLine = function(_, line) TOOLTIP[#TOOLTIP + 1] = line end
RAID_CLASS_COLORS = { PALADIN = { r = 0.96, g = 0.55, b = 0.73 }, WARRIOR = { r = 0.78, g = 0.61, b = 0.43 } }
PICKED = nil
PickupMacro = function(name) PICKED = name end
-- Like the game's: the hook runs after the original, with the same arguments.
function hooksecurefunc(object, method, hook)
    local original = object[method]
    object[method] = function(...) local results = { original(...) }; hook(...); return unpack(results) end
end
GameTooltip.SetAction = function(self, slot) TOOLTIP = { "spell tooltip for slot " .. slot } end
-- Action slots: slot -> { kind =, id =, text = }
ACTIONS = {}
GetActionInfo = function(slot) local a = ACTIONS[slot]; if a then return a.kind, a.id end end
GetActionText = function(slot) local a = ACTIONS[slot]; return a and a.text end
GetMacroInfo = function(id) local m = MACROS[id]; if m then return m.name, m.icon, m.body end end
SlashCmdList = {}
print = function(m) printed[#printed + 1] = m end
IN_COMBAT = false
InCombatLockdown = function() return IN_COMBAT end

AFTERS = {}          -- delayed callbacks, run by the tests with RunAfters()
C_Timer = { After = function(_, fn) AFTERS[#AFTERS + 1] = fn end }
function RunAfters()
    local list = AFTERS
    AFTERS = {}
    for _, fn in ipairs(list) do fn() end
end

-- The character.
CLASS, SPEC = "PALADIN", 70
CLASS_NAMES = { PALADIN = "Paladin", WARRIOR = "Warrior", MAGE = "Mage" }
UnitClass = function() return CLASS_NAMES[CLASS] or CLASS, CLASS, 2 end
GetSpecialization = function() return SPEC and 1 or nil end
SPEC_NAMES = { [65] = "Holy", [66] = "Protection", [70] = "Retribution" }
GetSpecializationInfo = function() return SPEC, SPEC_NAMES[SPEC] or "Spec" end

-- Spells: SPELL_IDS are spells the client has heard of; KNOWN are the ones
-- this character has learned.
SPELL_IDS, KNOWN = {}, {}
C_Spell = { GetSpellInfo = function(name)
    local id = SPELL_IDS[name]
    if id then return { name = name, spellID = id } end
end, GetSpellTexture = function(name)
    local id = SPELL_IDS[name]
    return id and ("icon-" .. name) or nil
end }
IsPlayerSpell = function(id) return KNOWN[id] or false end
local nextID = 1000
function Learn(...)
    for _, name in ipairs({ ... }) do
        if not SPELL_IDS[name] then nextID = nextID + 1; SPELL_IDS[name] = nextID end
        KNOWN[SPELL_IDS[name]] = true
    end
end

-- Macros, like the game: account-wide and per-character lists, looked up
-- by name, not allowed to change in combat.
MACROS = {}
MAX_CHARACTER_MACROS = 18
GetNumMacros = function()
    local account, character = 0, 0
    for _, m in ipairs(MACROS) do
        if m.perCharacter then character = character + 1 else account = account + 1 end
    end
    return account, character
end
GetMacroIndexByName = function(name)
    for i, m in ipairs(MACROS) do if m.name == name then return i end end
    return 0
end
CreateMacro = function(name, icon, body, perCharacter)
    assert(not IN_COMBAT, "CreateMacro in combat")
    assert(#name <= 16, "macro name too long: " .. name)
    assert(#body <= 255, "macro body too long: " .. name)
    local _, character = GetNumMacros()
    assert(not perCharacter or character < MAX_CHARACTER_MACROS, "character macros full")
    MACROS[#MACROS + 1] = { name = name, icon = icon, body = body, perCharacter = perCharacter }
    return #MACROS
end
DeleteMacro = function(index)
    assert(not IN_COMBAT, "DeleteMacro in combat")
    assert(MACROS[index], "no macro at " .. tostring(index))
    table.remove(MACROS, index)
end
function MacroNames()
    local names = {}
    for _, m in ipairs(MACROS) do names[#names + 1] = m.name end
    return table.concat(names, ",")
end

function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end

-- The files an addon's TOC lists, in order, so a file missing from the TOC
-- is caught here rather than in game.
function TocFiles(dir, name)
    local files = {}
    local toc = assert(io.open(dir .. "/" .. name .. ".toc", "r"), "no TOC for " .. name)
    for line in toc:lines() do
        line = line:gsub("\r", ""):match("^%s*(.-)%s*$")
        if line ~= "" and line:sub(1, 1) ~= "#" then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    toc:close()
    return files
end

function LoadAddon(dir, name)
    local ns = {}
    for _, file in ipairs(TocFiles(dir, name)) do
        local h = assert(io.open(dir .. "/" .. file, "r")); local src = h:read("*a"); h:close()
        assert(loadstring(src, "@" .. file))(name, ns)
    end
    return ns
end
