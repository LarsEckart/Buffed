-- Standalone mock smoke test; not loaded by the addon.
local frames, active, learned = {}, {}, {}
local combat, dead, mounted = false, false, false
local bags, level = {}, 22
function UnitLevel() return level end
C_Container = {
    GetContainerNumSlots = function(bag) return #(bags[bag] or {}) end,
    GetContainerItemID = function(bag, slot) return bags[bag][slot] end,
}
C_Item = { GetItemIconByID = function(id) return id + 100000 end }
local mutations = 0
local function protectedMutation()
    assert(not combat, "secure frame mutated in combat")
    mutations = mutations + 1
end
local methods = {}
for _, name in ipairs({ "SetSize", "SetMovable", "SetClampedToScreen", "RegisterForDrag",
    "SetScript", "RegisterEvent", "SetTexture", "SetAllPoints", "SetHighlightTexture",
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
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
SlashCmdList = {}
function UnitClass() return "Priest", "PRIEST" end
function UnitIsDeadOrGhost() return dead end
function IsMounted() return mounted end
function InCombatLockdown() return combat end
function RegisterStateDriver(_, state, condition)
    assert(state == "visibility" and condition == "[combat] hide; show")
end
local spellIDs = {
    ["Power Word: Fortitude"] = 1244,
    ["Inner Fire"] = 588,
    ["Divine Spirit"] = 14752,
    ["Shadow Protection"] = 976,
    ["Shadowform"] = 15473,
    ["Shadowguard"] = 18137,
}
Enum = { SpellBookSpellBank = { Player = 0 } }
C_Spell = { GetSpellInfo = function(name)
    return { iconID = 123, spellID = spellIDs[name] }
end }
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
learned["Power Word: Fortitude"] = true
learned["Inner Fire"] = true
learned["Shadowform"] = true
event("PLAYER_LOGIN")
assert(BuffedButton1.shown and BuffedButton2.shown, "missing buffs should appear")
assert(not BuffedButton3.shown, "unlearned spirit should not appear")
assert(not BuffedButton5.shown, "optional form defaults off")
assert(BuffedButton1.unit == "player" and BuffedButton1.spell == "Power Word: Fortitude")
active = { "Prayer of Fortitude", "Inner Fire" }
event("UNIT_AURA", "player")
assert(not BuffedButton1.shown and not BuffedButton2.shown, "active buffs should hide")
active = {}
event("UNIT_AURA", "target")
assert(not BuffedButton1.shown, "other units should not refresh")
event("UNIT_AURA", "player")
assert(BuffedButton1.shown)
combat = true
local before = mutations
event("UNIT_AURA", "player")
SlashCmdList.BUFFED("fire")
assert(mutations == before and BuffedDB.enabled.fire, "combat must not mutate settings or buttons")
combat = false
event("PLAYER_REGEN_ENABLED")
mounted = true
event("PLAYER_MOUNT_DISPLAY_CHANGED")
assert(not BuffedButton1.shown)
mounted, dead = false, true
event("PLAYER_DEAD")
assert(not BuffedButton1.shown)
dead = false
event("PLAYER_UNGHOST")
assert(BuffedButton1.shown)
SlashCmdList.BUFFED("fire")
assert(not BuffedButton2.shown and not BuffedDB.enabled.fire)
SlashCmdList.BUFFED("form")
assert(BuffedButton5.shown)
assert(not BuffedButton6.shown, "unlearned Shadowguard should not appear")
learned["Shadowguard"] = true
event("SPELLS_CHANGED")
assert(BuffedButton6.shown and BuffedDB.enabled.shadowguard, "learned Shadowguard defaults on")
assert(BuffedButton6.unit == "player" and BuffedButton6.spell == "Shadowguard")
active = { "Shadowguard" }
event("UNIT_AURA", "player")
assert(not BuffedButton6.shown, "active Shadowguard should hide")
active = {}
event("UNIT_AURA", "player")
assert(BuffedButton6.shown, "expired or depleted Shadowguard should reappear")
SlashCmdList.BUFFED("shadowguard")
assert(not BuffedButton6.shown and not BuffedDB.enabled.shadowguard)

assert(BuffedDB.enabled.food and not BuffedButton7.shown, "no supported food means no Well Fed reminder")
bags[0] = { 2679 }
event("BAG_UPDATE_DELAYED")
assert(not BuffedButton7.shown, "unlisted food must not trigger a reminder")
bags[0] = { 2681 }
event("BAG_UPDATE_DELAYED")
assert(BuffedButton7.shown and BuffedButton7.item == "item:2681", "carried Roasted Boar Meat should appear")
assert(BuffedButton7.type == "item" and BuffedButton7.unit == "player", "food must be clickable")
assert(BuffedButton7.icon.SetTextureArgs[1] == 102681, "show the food's actual icon")
active = { "Well Fed" }
event("UNIT_AURA", "player")
assert(BuffedButton7.shown, "non-XP Well Fed must not hide the XP food reminder")
active = { "Well Fed XP Boost" }
event("UNIT_AURA", "player")
assert(not BuffedButton7.shown, "Forever's XP buff should also satisfy Well Fed")
active = { "Food" }
event("UNIT_AURA", "player")
assert(BuffedButton7.shown, "eating without Well Fed should not satisfy the reminder")
active = {}
event("UNIT_AURA", "player")
assert(BuffedButton7.shown, "expired Well Fed should show the reminder")
SlashCmdList.BUFFED("food")
assert(not BuffedButton7.shown and not BuffedDB.enabled.food)
SlashCmdList.BUFFED("food")
assert(BuffedButton7.shown)
combat = true
bags[0] = {}
before = mutations
event("BAG_UPDATE_DELAYED")
assert(mutations == before, "food bag updates must not mutate buttons in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not BuffedButton7.shown and BuffedButton7.item == nil, "removing last food clears reminder and action")
for _, id in ipairs({ 2682, 5477, 2683, 21072, 12210, 3665 }) do
    bags[0] = { id }
    event("BAG_UPDATE_DELAYED")
    assert(BuffedButton7.shown and BuffedButton7.item == "item:" .. id, "verified XP food should be selected")
end
for _, id in ipairs({ 5525, 5527, 17197, 17198, 6657, 12217 }) do
    bags[0] = { id }
    event("BAG_UPDATE_DELAYED")
    assert(not BuffedButton7.shown, "food without verified XP must not be selected")
end
bags[0] = { 13933 }
event("BAG_UPDATE_DELAYED")
assert(not BuffedButton7.shown, "high-level XP food should not appear at level 22")
bags[0] = { 12210, 2681, 2683 }
event("BAG_UPDATE_DELAYED")
assert(BuffedButton7.item == "item:2681", "prefer existing boar meat over stat bonuses")
bags[0] = {}
event("BAG_UPDATE_DELAYED")

assert(not BuffedButton8.shown, "no scroll in bags means no Intellect reminder")
bags[0] = { 955, 2290, 4419 }
event("BAG_UPDATE_DELAYED")
assert(BuffedButton8.shown and BuffedButton8.item == "item:2290", "prefer highest usable rank at level 22")
assert(BuffedButton8.type == "item" and BuffedButton8.unit == "player")
assert(BuffedButton8.icon.SetTextureArgs[1] == 102290, "use the carried scroll's icon")
for _, name in ipairs({ "Intellect", "Arcane Intellect", "Arcane Brilliance" }) do
    active = { name }
    event("UNIT_AURA", "player")
    assert(not BuffedButton8.shown, name .. " should suppress the scroll")
end
active = {}
event("UNIT_AURA", "player")
assert(BuffedButton8.shown)
combat = true
bags[0] = {}
before = mutations
event("BAG_UPDATE_DELAYED")
assert(mutations == before, "bag updates must not mutate secure buttons in combat")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not BuffedButton8.shown and BuffedButton8.item == nil, "remove stale item action when scroll is gone")
bags[0] = { 4419 }
event("BAG_UPDATE_DELAYED")
assert(not BuffedButton8.shown, "unusable high rank should not appear")
level = 35
event("PLAYER_LEVEL_UP")
assert(BuffedButton8.shown and BuffedButton8.item == "item:4419")
for _, rank in ipairs({ { id = 955, level = 5 }, { id = 2290, level = 20 },
    { id = 4419, level = 35 }, { id = 10308, level = 50 } }) do
    bags[0] = { rank.id }
    level = rank.level - 1
    event("BAG_UPDATE_DELAYED")
    assert(not BuffedButton8.shown, "scroll must hide below required level " .. rank.level)
    level = rank.level
    event("PLAYER_LEVEL_UP")
    assert(BuffedButton8.shown and BuffedButton8.item == "item:" .. rank.id,
        "scroll must appear at required level " .. rank.level)
end
SlashCmdList.BUFFED("intellect")
assert(not BuffedButton8.shown)
SlashCmdList.BUFFED("intellect")
-- Check the legacy bag API path too.
GetContainerNumSlots = C_Container.GetContainerNumSlots
GetContainerItemID = C_Container.GetContainerItemID
C_Container = nil
bags[0] = { 955, 2681 }
event("BAG_UPDATE_DELAYED")
assert(BuffedButton8.shown and BuffedButton8.item == "item:955")
assert(BuffedButton7.shown and BuffedButton7.item == "item:2681", "legacy bag API should also find food")
bags[0] = {}
event("BAG_UPDATE_DELAYED")

-- The learned rank can differ from the ID returned by a name lookup.
GetNumSpellTabs = function() return 1 end
GetSpellTabInfo = function() return "Discipline", nil, 0, 1 end
GetSpellBookItemName = function(slot, book)
    assert(slot == 1 and book == "spell")
    return "Power Word: Fortitude", "Rank 3"
end
learned["Power Word: Fortitude"] = false
event("SPELLS_CHANGED")
assert(BuffedButton1.shown, "ranked spellbook names should be recognized")
assert(not BuffedButton5.shown, "spellbook scan should reject unlearned names")
GetNumSpellTabs, GetSpellTabInfo, GetSpellBookItemName = nil, nil, nil
C_SpellBook.GetNumSpellBookSkillLines = function() return 1 end
C_SpellBook.GetSpellBookSkillLineInfo = function()
    return { itemIndexOffset = 0, numSpellBookItems = 1 }
end
C_SpellBook.GetSpellBookItemName = function(slot, bank)
    assert(slot == 1 and bank == 0)
    return "Power Word: Fortitude"
end
event("SPELLS_CHANGED")
assert(BuffedButton1.shown, "modern spellbook names should recognize ranked spells")
print("Buffed mock smoke tests passed")
