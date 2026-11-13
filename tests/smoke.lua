-- Standalone mock smoke test; not loaded by the addon.
local frames, active, learned = {}, {}, {}
local combat, dead, mounted = false, false, false
local bags, level = {}, 22
local speed = 0
function GetUnitSpeed(unit) assert(unit == "player"); return speed end
local mutations = 0
local function protectedMutation()
    assert(not combat, "secure frame mutated in combat")
    mutations = mutations + 1
end
local methods = {}
for _, name in ipairs({ "SetSize", "SetMovable", "SetClampedToScreen", "RegisterForDrag",
    "RegisterEvent", "SetTexture", "SetAllPoints", "SetHighlightTexture",
    "RegisterForClicks", "StartMoving", "StopMovingOrSizing", "SetText", "SetShown" }) do
    methods[name] = function(self, ...) self[name .. "Args"] = { ... } end
end
function methods:SetScript(name, fn) self[name] = fn end
function methods:Show() protectedMutation(); self.shown = true end
function methods:Hide() protectedMutation(); self.shown = false end
function methods:SetAttribute(key, value) protectedMutation(); self[key] = value end
function methods:SetPoint(...) protectedMutation(); self.point = { ... } end
function methods:ClearAllPoints() protectedMutation() end
function methods:EnableMouse() protectedMutation() end
function methods:CreateTexture() return setmetatable({}, { __index = methods }) end
methods.CreateFontString = methods.CreateTexture
function CreateFrame(_, name)
    local frame = setmetatable({}, { __index = methods })
    frames[#frames + 1] = frame
    if name then _G[name] = frame end
    return frame
end
UIParent = {}
local messages = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, message) messages[#messages + 1] = message end }
SlashCmdList = {}
function UnitClass() return "Priest", "PRIEST" end
function UnitLevel() return level end
function UnitIsDeadOrGhost() return dead end
function IsMounted() return mounted end
function InCombatLockdown() return combat end
function RegisterStateDriver(_, state, condition)
    assert(state == "visibility" and condition == "[combat] hide; show")
end
C_Container = {
    GetContainerNumSlots = function(bag) return #(bags[bag] or {}) end,
    GetContainerItemID = function(bag, slot) return bags[bag][slot] end,
}
C_Item = { GetItemIconByID = function(id) return id + 100000 end }
local spellIDs = { ["Power Word: Fortitude"] = 1244, ["Inner Fire"] = 588, ["Shadowguard"] = 18137 }
Enum = { SpellBookSpellBank = { Player = 0 } }
C_Spell = { GetSpellInfo = function(name) return { iconID = 123, spellID = spellIDs[name] } end }
C_SpellBook = { IsSpellInSpellBook = function(id, bank, overrides)
    assert(type(id) == "number", "spellbook lookup requires an ID, not a name")
    assert(bank == 0 and overrides == true, "player spell bank must be explicit")
    for name, spellID in pairs(spellIDs) do
        if spellID == id then return learned[name] end
    end
end }
C_UnitAuras = { GetBuffDataByIndex = function(_, index)
    return active[index] and { name = active[index] }
end }

assert(loadfile("Buffed.lua"))("Buffed")
local function event(name, unit) frames[1].OnEvent(frames[1], name, unit) end
learned["Power Word: Fortitude"], learned["Inner Fire"] = true, true
event("PLAYER_LOGIN")
-- Use semantic aliases so test assertions do not depend on the button order.
local fortitude, fire, guard, food, intellect
for _, frame in ipairs(frames) do
    if frame.spell == "Power Word: Fortitude" then fortitude = frame
    elseif frame.spell == "Inner Fire" then fire = frame
    elseif frame.spell == "Shadowguard" then guard = frame end
end
-- Item buttons have no selected item until an eligible consumable is carried.
bags[0] = { 2681, 2290 }
event("BAG_UPDATE_DELAYED")
for _, frame in ipairs(frames) do
    if frame.item == "item:2681" then food = frame
    elseif frame.item == "item:2290" then intellect = frame end
end
assert(fortitude and fire and guard and food and intellect)
bags[0] = {}
event("BAG_UPDATE_DELAYED")
assert(fortitude.shown and fire.shown, "missing buffs should appear")
assert(fortitude.unit == "player" and not guard.shown, "unlearned Shadowguard should hide")
for _, command in ipairs({ "spirit", "shadow", "form" }) do
    SlashCmdList.BUFFED(command)
    assert(messages[#messages]:find("Unknown command", 1, true), "removed reminder must not be configurable")
    assert(BuffedDB.enabled[command] == nil)
end
active = { "Prayer of Fortitude", "Inner Fire" }
event("UNIT_AURA", "player")
assert(not fortitude.shown and not fire.shown, "active buffs should hide")
active = {}
event("UNIT_AURA", "target")
assert(not fortitude.shown, "other units should not refresh")
event("UNIT_AURA", "player")
assert(fortitude.shown)
combat = true
local before = mutations
event("UNIT_AURA", "player")
SlashCmdList.BUFFED("fire")
assert(mutations == before and BuffedDB.enabled.fire, "combat must not mutate settings or buttons")
combat = false
event("PLAYER_REGEN_ENABLED")
mounted = true
event("PLAYER_MOUNT_DISPLAY_CHANGED")
assert(not fortitude.shown)
mounted, dead = false, true
event("PLAYER_DEAD")
assert(not fortitude.shown)
dead = false
event("PLAYER_UNGHOST")
assert(fortitude.shown)
SlashCmdList.BUFFED("fire")
assert(not fire.shown and not BuffedDB.enabled.fire)
learned["Shadowguard"] = true
event("SPELLS_CHANGED")
assert(guard.shown and guard.unit == "player" and BuffedDB.enabled.shadowguard)
active = { "Shadowguard" }
event("UNIT_AURA", "player")
assert(not guard.shown)
active = {}
event("UNIT_AURA", "player")
assert(guard.shown, "depleted Shadowguard should reappear")
SlashCmdList.BUFFED("shadowguard")
assert(not guard.shown)

assert(BuffedDB.enabled.food and not food.shown)
bags[0] = { 2681 }
event("BAG_UPDATE_DELAYED")
assert(food.shown and food.item == "item:2681" and food.type == "item" and food.unit == "player")
assert(food.icon.SetTextureArgs[1] == 102681)
bags[0] = { 2681, 2290 }
event("BAG_UPDATE_DELAYED")
event("PLAYER_STARTED_MOVING")
assert(not food.shown and fortitude.shown and intellect.shown, "only food hides while moving")
event("BAG_UPDATE_DELAYED")
assert(not food.shown, "other refreshes must preserve movement suppression")
event("PLAYER_STOPPED_MOVING")
assert(food.shown, "food should return immediately when stopping")
speed = 7
event("PLAYER_ENTERING_WORLD")
assert(not food.shown, "reload/world entry while moving should hide food")
speed = 0
event("PLAYER_ENTERING_WORLD")
assert(food.shown)
combat = true
before = mutations
event("PLAYER_STARTED_MOVING")
assert(mutations == before, "movement must not mutate secure buttons in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not food.shown, "movement begun during combat should persist after combat")
combat = true
before = mutations
event("PLAYER_STOPPED_MOVING")
assert(mutations == before, "stopping in combat must not mutate secure buttons")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(food.shown, "stopping during combat should allow food after combat")
active = { "Well Fed" }
event("UNIT_AURA", "player")
assert(food.shown, "non-XP Well Fed must not hide the XP reminder")
active = { "Well Fed XP Boost" }
event("UNIT_AURA", "player")
assert(not food.shown)
active = { "Food" }
event("UNIT_AURA", "player")
assert(food.shown, "eating without the XP buff does not satisfy the reminder")
active = {}
SlashCmdList.BUFFED("food")
assert(not food.shown)
SlashCmdList.BUFFED("food")
assert(food.shown)
combat = true
bags[0] = {}
before = mutations
event("BAG_UPDATE_DELAYED")
assert(mutations == before)
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not food.shown and food.item == nil)
for _, id in ipairs({ 2682, 5477, 2683, 21072, 12210, 3665 }) do
    bags[0] = { id }
    event("BAG_UPDATE_DELAYED")
    assert(food.shown and food.item == "item:" .. id)
end
for _, id in ipairs({ 2679, 5525, 5527, 17197, 17198, 6657, 12217, 13933 }) do
    bags[0] = { id }
    event("BAG_UPDATE_DELAYED")
    assert(not food.shown, "non-XP or unusable food must not be selected")
end
bags[0] = { 12210, 2681, 2683 }
event("BAG_UPDATE_DELAYED")
assert(food.item == "item:2681", "prefer boar meat over stat bonuses")
bags[0] = {}
event("BAG_UPDATE_DELAYED")

assert(not intellect.shown)
bags[0] = { 955, 2290, 4419 }
event("BAG_UPDATE_DELAYED")
assert(intellect.shown and intellect.item == "item:2290", "prefer highest usable rank at level 22")
assert(intellect.type == "item" and intellect.unit == "player" and intellect.icon.SetTextureArgs[1] == 102290)
for _, name in ipairs({ "Intellect", "Arcane Intellect", "Arcane Brilliance" }) do
    active = { name }
    event("UNIT_AURA", "player")
    assert(not intellect.shown)
end
active = {}
event("UNIT_AURA", "player")
assert(intellect.shown)
combat = true
bags[0] = {}
before = mutations
event("BAG_UPDATE_DELAYED")
assert(mutations == before)
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not intellect.shown and intellect.item == nil)
for _, rank in ipairs({ { id = 955, level = 5 }, { id = 2290, level = 20 },
    { id = 4419, level = 35 }, { id = 10308, level = 50 } }) do
    bags[0] = { rank.id }
    level = rank.level - 1
    event("BAG_UPDATE_DELAYED")
    assert(not intellect.shown, "scroll must hide below required level " .. rank.level)
    level = rank.level
    event("PLAYER_LEVEL_UP")
    assert(intellect.shown and intellect.item == "item:" .. rank.id)
end
SlashCmdList.BUFFED("intellect")
assert(not intellect.shown)
SlashCmdList.BUFFED("intellect")
GetContainerNumSlots = C_Container.GetContainerNumSlots
GetContainerItemID = C_Container.GetContainerItemID
C_Container = nil
bags[0] = { 955, 2681 }
event("BAG_UPDATE_DELAYED")
assert(intellect.shown and intellect.item == "item:955" and food.shown and food.item == "item:2681")
bags[0] = {}
event("BAG_UPDATE_DELAYED")

-- A name lookup can resolve to a different rank ID than the learned rank.
GetNumSpellTabs = function() return 1 end
GetSpellTabInfo = function() return "Discipline", nil, 0, 1 end
GetSpellBookItemName = function(slot, book)
    assert(slot == 1 and book == "spell")
    return "Power Word: Fortitude", "Rank 2"
end
learned["Power Word: Fortitude"] = false
BuffedDB.enabled.shadowguard = true
event("SPELLS_CHANGED")
assert(fortitude.shown and not guard.shown, "legacy book scan must recognize only learned names")
GetNumSpellTabs, GetSpellTabInfo, GetSpellBookItemName = nil, nil, nil
C_SpellBook.GetNumSpellBookSkillLines = function() return 1 end
C_SpellBook.GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end
C_SpellBook.GetSpellBookItemName = function(slot, bank)
    assert(slot == 1 and bank == 0)
    return "Power Word: Fortitude"
end
event("SPELLS_CHANGED")
assert(fortitude.shown and not guard.shown, "modern book scan must recognize only learned names")
print("Buffed mock smoke tests passed")
