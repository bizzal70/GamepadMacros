-- GamepadMacros: added only on request; account-wide macros except the
-- class heal; the Quest Item macro follows the bags; the minimap button
-- only once a controller is used.

-- What this test adds to the fake game: bags, gear sets, leaving a party,
-- editing a macro, and controllers.
BAGS = {}            -- [bag][slot] = { itemID =, questID =, isActive =, isQuestItem = }
C_Container = {
    GetContainerNumSlots = function(bag) return bag <= 4 and 16 or 0 end,
    GetContainerItemInfo = function(bag, slot) local i = BAGS[bag] and BAGS[bag][slot]; return i and { itemID = i.itemID } end,
    GetContainerItemQuestInfo = function(bag, slot)
        local i = BAGS[bag] and BAGS[bag][slot]
        return { isQuestItem = i and i.isQuestItem or false, questID = i and i.questID, isActive = i and i.isActive or false }
    end,
}
ITEM_SPELLS = {}
C_Item = { GetItemSpell = function(id) return ITEM_SPELLS[id] end }
C_EquipmentSet = { CreateEquipmentSet = function() end, SaveEquipmentSet = function() end, GetEquipmentSetID = function() end }
C_PartyInfo = { LeaveParty = function() end }
C_GamePad = {}
EditMacro = function(index, name, icon, body)
    assert(not IN_COMBAT, "EditMacro in combat")
    MACROS[index].body = body
end
local function Body(name) return MACROS[GetMacroIndexByName(name)].body end

local ns = LoadAddon(ADDON_DIR, "GamepadMacros")
local function check(cond, what) if not cond then error("CHECK FAILED: " .. what, 2) end; io.write("pass  ", what, "\n") end
local function Has(name) return GetMacroIndexByName(name) > 0 end

SPEC = nil
Learn("Holy Light")
-- MacroKit 0.6 added Hello for this account before the pack moved here.
CreateMacro("Hello", 1, "/wave", false)
MacroKitDB = { generalMade = { Hello = true, Seal = true } }
Fire("ADDON_LOADED", "GamepadMacros")
Fire("PLAYER_LOGIN")
check(not Has("Heal Me") and not Has("Thanks"), "nothing is added by itself")
check(ns.db.generalMade.Hello and not MacroKitDB.generalMade.Hello and MacroKitDB.generalMade.Seal,
    "the macros MacroKit 0.6 added are taken over, and nothing else of MacroKit's")

-- What is in it.
local names = {}
for _, macro in ipairs(ns.List()) do
    names[#names + 1] = macro.name
    check(#macro.name <= 16, macro.name .. " fits the game's name limit")
    local body = macro.Body and macro.Body() or macro.body
    check(#body <= 255, macro.name .. " fits the game's macro size")
end
check(table.concat(names, ",") == "Heal Me,Quest Item,Bandage,Eat & Drink,Potion,Hearth,Save Gear,Wear Gear,Leave Group,Hello,Thanks,Follow Me,Need Help",
    "a paladin's macros: " .. table.concat(names, ","))
CLASS = "WARRIOR"
check(ns.List()[1].name == "Quest Item", "a class with no heal gets them without Heal Me")
CLASS = "PALADIN"

-- The minimap button waits for a controller.
local mb = ns.MinimapButton()
check(not mb:IsShown(), "the minimap button stays hidden until a controller is used")
Fire("GAME_PAD_ACTIVE_CHANGED", false)
check(not mb:IsShown(), "mouse and keyboard keep it hidden")
Fire("GAME_PAD_ACTIVE_CHANGED", true)
check(mb:IsShown(), "using a controller shows it")
Fire("GAME_PAD_ACTIVE_CHANGED", false)
check(mb:IsShown(), "and it stays for the session")
SlashCmdList.GAMEPADMACROS("button"); check(not mb:IsShown(), "/gpm button turns it off")
SlashCmdList.GAMEPADMACROS("button"); check(mb:IsShown(), "and on")

-- Adding them.
local _, charBefore = GetNumMacros()
SlashCmdList.GAMEPADMACROS("add")
for _, name in ipairs(names) do check(Has(name), name .. " is added by /gpm add") end
local account, character = GetNumMacros()
check(character == charBefore + 1, "only Heal Me takes a character macro slot")
check(account == 12, "the other twelve are account-wide General macros")
check(Body("Heal Me"):find("/cast [@player] Holy Light", 1, true), "Heal Me heals yourself with the paladin's heal")
SlashCmdList.GAMEPADMACROS("add")
check(GetNumMacros() == 12, "asking again adds nothing twice")

-- The quest item macro follows the bags.
check(Body("Quest Item"):find("no quest item", 1, true), "with no quest item it says so when pressed")
BAGS[1] = { [3] = { itemID = 5000, isQuestItem = true } }
ITEM_SPELLS[5000] = "Use: dig"
Fire("BAG_UPDATE_DELAYED")
check(Body("Quest Item") == "#showtooltip item:5000\n/use item:5000", "a quest item with a use goes in when it reaches the bags")
BAGS[2] = { [1] = { itemID = 6000, questID = 77, isActive = false } }
Fire("BAG_UPDATE_DELAYED")
check(Body("Quest Item"):find("item:6000", 1, true), "an item that starts a quest comes first")
IN_COMBAT = true
BAGS[2] = nil
Fire("BAG_UPDATE_DELAYED")
check(Body("Quest Item"):find("item:6000", 1, true), "in combat the macro is left alone")
IN_COMBAT = false
Fire("PLAYER_REGEN_ENABLED")
check(Body("Quest Item"):find("item:5000", 1, true), "and brought up to date when combat ends")
ns.db.generalMade["Quest Item"] = nil
BAGS[1] = nil
Fire("BAG_UPDATE_DELAYED")
check(Body("Quest Item"):find("item:5000", 1, true), "a Quest Item macro this addon did not make is left alone")
ns.db.generalMade["Quest Item"] = true

-- Bandage, Eat & Drink and Potion follow the bags too, picking the best
-- item this character can use.
ITEM_LEVELS = {}     -- itemID -> { itemLevel, minLevel }
UnitLevel = function() return 20 end
C_Item.GetItemInfo = function(id)
    local l = ITEM_LEVELS[id]
    if l then return "item" .. id, "link", 1, l[1], l[2] end
end
check(Body("Bandage"):find("no bandage", 1, true) and Body("Eat & Drink"):find("no food or drink", 1, true)
    and Body("Potion"):find("no healing potion", 1, true), "with nothing in the bags, each says so when pressed")
BAGS[0] = {
    [1] = { itemID = 1251 }, [2] = { itemID = 2581 }, [3] = { itemID = 8545 },   -- bandages: linen, heavy linen, heavy mageweave
    [4] = { itemID = 117 }, [5] = { itemID = 159 }, [6] = { itemID = 4536 },     -- tough jerky, refreshing spring water, apple
    [7] = { itemID = 118 }, [8] = { itemID = 929 },                               -- minor and healing potion
}
for _, id in ipairs({ 1251, 2581, 8545 }) do ITEM_SPELLS[id] = "First Aid" end
ITEM_SPELLS[117], ITEM_SPELLS[4536], ITEM_SPELLS[159] = "Food", "Food", "Drink"
ITEM_SPELLS[118], ITEM_SPELLS[929] = "Healing Potion", "Healing Potion"
ITEM_LEVELS[1251], ITEM_LEVELS[2581], ITEM_LEVELS[8545] = { 1, 1 }, { 20, 1 }, { 50, 1 }
ITEM_LEVELS[117], ITEM_LEVELS[4536] = { 5, 1 }, { 15, 5 }
ITEM_LEVELS[118], ITEM_LEVELS[929] = { 5, 1 }, { 25, 22 }   -- the healing potion needs level 22
Fire("BAG_UPDATE_DELAYED")
check(Body("Bandage") == "#showtooltip item:8545\n/use item:8545", "Bandage uses the best bandage")
check(Body("Eat & Drink") == "#showtooltip item:4536\n/use item:4536\n/use item:159", "Eat & Drink eats the best food and drinks the water in one press")
check(Body("Potion") == "#showtooltip item:118\n/use item:118", "Potion skips one the character is too low to drink")
BAGS[0][4], BAGS[0][6] = nil, nil
Fire("BAG_UPDATE_DELAYED")
check(Body("Eat & Drink") == "#showtooltip item:159\n/use item:159", "with only a drink left, it uses the drink")
check(Body("Hearth") == "#showtooltip item:6948\n/use item:6948", "Hearth uses the Hearthstone")

-- Food whose details the game has not loaded yet reports no spell; it is
-- asked for, and picked up once it arrives. And food is recognised by its
-- Food & Drink category, whatever the client calls eating.
CATEGORY = { [2287] = { 0, 5 }, [159] = { 0, 5 }, [118] = { 0, 1 } }
C_Item.GetItemInfoInstant = function(id) local c = CATEGORY[id]; if c then return id, "Consumable", "Food & Drink", "", 0, c[1], c[2] end end
local requested = {}
C_Item.RequestLoadItemDataByID = function(id) requested[id] = true end
BAGS[0][4] = { itemID = 2287 }       -- haunch of meat, details not loaded yet
ITEM_LEVELS[2287] = { 15, 5 }
Fire("BAG_UPDATE_DELAYED")
check(Body("Eat & Drink") == "#showtooltip item:159\n/use item:159" and requested[2287], "food the game has not loaded yet is asked for")
ITEM_SPELLS[2287] = "Eating"
Fire("GET_ITEM_INFO_RECEIVED", 2287, true)
check(Body("Eat & Drink") == "#showtooltip item:2287\n/use item:2287\n/use item:159",
    "when it arrives, Eat & Drink eats it too; food is known by its category, not only a spell called Food")
check(Body("Potion") == "#showtooltip item:118\n/use item:118", "a potion is not taken for food")
BAGS[0] = nil

-- A client without gear sets.
DeleteMacro(GetMacroIndexByName("Save Gear")); ns.db.generalMade["Save Gear"] = nil
C_EquipmentSet = nil
local saveGear
for _, macro in ipairs(ns.List()) do if macro.name == "Save Gear" then saveGear = macro end end
local status, missing = ns.Status(saveGear)
check(status == "needs" and missing == "gear sets in this game", "without gear sets, Save Gear waits and says why")
SlashCmdList.GAMEPADMACROS("add")
check(not Has("Save Gear"), "and is not added")

-- The window.
SlashCmdList.GAMEPADMACROS("")
check(GamepadMacrosWindow:IsShown(), "/gpm opens the window")
local found = {}
for _, r in ipairs(regions) do if r.__text then found[#found + 1] = r.__text end end
check(table.concat(found, "|"):find("Gamepad macros", 1, true), "titled Gamepad macros")
local shown = {}
for _, f in ipairs(Frames()) do
    if rawget(f, "macro") and rawget(f, "status") and f.__shown then shown[#shown + 1] = f.macro.name end
end
check(#shown == 13, "it lists every macro: " .. table.concat(shown, ","))
local saveRow
for _, f in ipairs(Frames()) do if rawget(f, "macro") and f.macro.name == "Save Gear" then saveRow = f end end
check(saveRow.status.__text:find("Needs gear sets", 1, true) and not saveRow.add.__shown, "a waiting macro says what it needs")
mb.__scripts.OnClick(mb)
check(not GamepadMacrosWindow:IsShown(), "the minimap button toggles the window")
GamepadMacros_OnAddonCompartmentClick()
check(GamepadMacrosWindow:IsShown(), "and so does the minimap's addon list")

-- Remove takes away only what this addon added.
CreateMacro("Mine", 1, "/say mine", true)
SlashCmdList.GAMEPADMACROS("remove")
check(not Has("Hello") and not Has("Heal Me") and not Has("Thanks") and Has("Mine"), "/gpm remove deletes its macros and only those")
check(next(ns.db.generalMade) == nil and next(ns.char.made) == nil, "and forgets them")
SlashCmdList.GAMEPADMACROS("help")
