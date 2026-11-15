-- Standalone mock smoke test; not loaded by the addon.
local frames, active, learned = {}, {}, {}
local combat, dead, mounted = false, false, false
local bags, level = {}, 22
local speed = 0
function GetUnitSpeed(unit) assert(unit == "player"); return speed end
local mutations, scans = 0, 0
local function recordScan()
    assert(not combat and not dead and not mounted, "unnecessary or restricted scan while suppressed")
    scans = scans + 1
end
-- Conservative protection model: reject mutations through secure parents or
-- relative anchors too.
local function protected(frame)
    if not frame or type(frame) ~= "table" then return false end
    return frame.secure or protected(frame.parent)
        or (frame.point and protected(frame.point[2])) or false
end
local function protectedMutation(frame)
    if not protected(frame) then return end
    assert(not combat, "secure frame/dependent mutated in combat")
    mutations = mutations + 1
end
local methods = {}
for _, name in ipairs({ "SetSize", "SetMovable", "SetClampedToScreen", "RegisterForDrag",
    "RegisterEvent", "SetTexture", "SetAllPoints", "SetHighlightTexture",
    "RegisterForClicks", "StartMoving", "StopMovingOrSizing", "SetText", "SetShown",
    "SetFrameStrata", "SetColorTexture", "SetMultiLine", "SetFontObject", "SetAutoFocus",
    "SetScrollChild", "SetFocus", "ClearFocus", "HighlightText" }) do
    methods[name] = function(self, ...)
        protectedMutation(self)
        self[name .. "Args"] = { ... }
    end
end
function methods:SetScript(name, fn) self[name] = fn end
function methods:RegisterEvent(name)
    self.events = self.events or {}
    self.events[name] = true
end
function methods:Show()
    protectedMutation(self)
    self.shown = true
end
function methods:Hide()
    protectedMutation(self)
    self.shown = false
end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown end
function methods:GetCenter() return 400, 300 end
function methods:SetAttribute(key, value) protectedMutation(self); self[key] = value end
function methods:SetPoint(...) protectedMutation(self); self.point = { ... } end
function methods:GetPoint() return (unpack or table.unpack)(self.point) end
function methods:ClearAllPoints() protectedMutation(self); self.point = nil end
function methods:EnableMouse() protectedMutation(self) end
function methods:CreateTexture() return setmetatable({ parent = self }, { __index = methods }) end
methods.CreateFontString = methods.CreateTexture
function CreateFrame(_, name, parent, template)
    assert(not combat, "UI frames must be pre-created before combat")
    local frame = setmetatable({ parent = parent,
        secure = template and template:find("Secure", 1, true) ~= nil }, { __index = methods })
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
    GetContainerNumSlots = function(bag) recordScan(); return #(bags[bag] or {}) end,
    GetContainerItemID = function(bag, slot) return bags[bag][slot] end,
}
C_Item = { GetItemIconByID = function(id) return id + 100000 end }
local spellIDs = { ["Power Word: Fortitude"] = 1244, ["Inner Fire"] = 588, ["Shadowguard"] = 18137 }
Enum = { SpellBookSpellBank = { Player = 0 } }
C_Spell = { GetSpellInfo = function(name) return { iconID = 123, spellID = spellIDs[name] } end }
C_SpellBook = { IsSpellInSpellBook = function(id, bank, overrides)
    recordScan()
    assert(type(id) == "number", "spellbook lookup requires an ID, not a name")
    assert(bank == 0 and overrides == true, "player spell bank must be explicit")
    for name, spellID in pairs(spellIDs) do
        if spellID == id then return learned[name] end
    end
end }
C_UnitAuras = { GetBuffDataByIndex = function(_, index)
    recordScan()
    local aura = active[index]
    return type(aura) == "table" and aura or (aura and { name = aura })
end }

assert(loadfile("Buffed.lua"))("Buffed")
local function event(name, unit) frames[1].OnEvent(frames[1], name, unit) end
learned["Power Word: Fortitude"], learned["Inner Fire"] = true, true
assert(not frames[1].events.PLAYER_LOGIN, "login event should not be registered")
for _, name in ipairs({ "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "UNIT_AURA", "PLAYER_REGEN_ENABLED" }) do
    event(name, "player")
end
assert(#frames == 1 and mutations == 0 and scans == 0 and BuffedDB == nil,
    "events before world entry must not initialize or scan")
combat = true
event("PLAYER_ENTERING_WORLD")
assert(#frames == 1 and scans == 0, "world entry in combat must defer initialization")
combat = false
event("PLAYER_REGEN_ENABLED")
assert(scans > 0, "deferred initialization should run after combat")
assert(not BuffedCombatShadowguard, "do not create a combat reminder dependent on secret auras")
BuffedAnchor:SetPoint("CENTER", UIParent, "CENTER", 80, -90)
BuffedAnchor.OnDragStop(BuffedAnchor)
assert(BuffedDB.position.x == 80 and BuffedDB.position.y == -90)
SlashCmdList.BUFFED("reset")
assert(BuffedAnchor.point[4] == 0 and BuffedAnchor.point[5] == -160)
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
-- IDs, not English names, identify every verified priest rank and prayer.
learned["Shadowguard"] = true
for _, group in ipairs({
    { button = fortitude, ids = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
    { button = fire, ids = { 588, 7128, 602, 1006, 10951, 10952 } },
    { button = guard, ids = { 18137, 19308, 19309, 19310, 19311, 19312 } },
}) do
    for _, id in ipairs(group.ids) do
        active = { { name = "Not an English spell name", spellId = id } }
        event("UNIT_AURA", "player")
        assert(not group.button.shown, "verified priest aura ID must count: " .. id)
    end
end
active = { { name = "Power Word: Fortitude", spellId = 1 }, { name = "Inner Fire", spellId = 2 } }
event("UNIT_AURA", "player")
assert(fortitude.shown and fire.shown, "unknown IDs must not match by English name")
learned["Shadowguard"] = nil
active = { "Prayer of Fortitude", "Inner Fire" }
event("UNIT_AURA", "player")
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
local previousScans = scans
for _, name in ipairs({ "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "UNIT_AURA" }) do event(name, "player") end
assert(scans == previousScans, "mounted events should skip data scans")
mounted, dead = false, true
event("PLAYER_DEAD")
assert(not fortitude.shown)
previousScans = scans
for _, name in ipairs({ "BAG_UPDATE_DELAYED", "SPELLS_CHANGED", "UNIT_AURA" }) do event(name, "player") end
assert(scans == previousScans, "dead events should skip data scans")
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
combat = true
before = mutations
local scansBeforeCombat = scans
local readBuffBeforeCombat = C_UnitAuras.GetBuffDataByIndex
C_UnitAuras.GetBuffDataByIndex = function() error("secret aura access forbidden in combat") end
UnitBuff = function() error("legacy aura access forbidden in combat") end
active = {}
for _, name in ipairs({ "PLAYER_REGEN_DISABLED", "UNIT_AURA", "PLAYER_STARTED_MOVING",
    "PLAYER_STOPPED_MOVING", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED" }) do event(name, "player") end
local frameCountInCombat = #frames
SlashCmdList.BUFFED("status")
assert(#frames == frameCountInCombat, "first status use in combat must not create UI frames")
local combatStatusBox, combatStatusPanel
for _, frame in ipairs(frames) do
    if frame.HighlightTextArgs then combatStatusBox = frame end
    if frame.SetFrameStrataArgs then combatStatusPanel = frame end
end
assert(combatStatusPanel.shown and combatStatusBox.SetFocusArgs)
assert(combatStatusBox.SetTextArgs[1]:find("Combat: true", 1, true))
assert(combatStatusBox.SetTextArgs[1]:find("cached, not live", 1, true))
assert(combatStatusBox.SetTextArgs[1]:find("Cached player buffs", 1, true))
assert(combatStatusBox.SetTextArgs[1]:find("Shadowguard: on, learned, active", 1, true),
    "combat status must preserve pre-combat auras, not infer current state")
combatStatusBox.OnEscapePressed()
assert(not combatStatusPanel.shown)
assert(scans == scansBeforeCombat, "combat events and status must perform no live scans")
assert(mutations == before, "combat status must not mutate secure frames")
C_UnitAuras.GetBuffDataByIndex = readBuffBeforeCombat
UnitBuff = nil
combat = false
event("PLAYER_REGEN_ENABLED")
assert(guard.shown, "normal clickable reminder resumes with fresh auras after combat")
SlashCmdList.BUFFED("status")
assert(combatStatusBox.SetTextArgs[1]:find("Shadowguard: on, learned, missing", 1, true))
assert(not combatStatusBox.SetTextArgs[1]:find("cached, not live", 1, true))
combatStatusBox.OnEscapePressed()
active = {}
event("UNIT_AURA", "player")
assert(guard.shown, "depleted Shadowguard should reappear")
SlashCmdList.BUFFED("shadowguard")
assert(not guard.shown)

-- Sleeping bag ownership and any Well-Rested stack use the normal item path.
assert(BuffedDB.enabled.sleepingbag)
bags[0] = { 211527 }
event("BAG_UPDATE_DELAYED")
local sleepingbag
for _, frame in ipairs(frames) do
    if frame.item == "item:211527" then sleepingbag = frame end
end
assert(sleepingbag and sleepingbag.shown and sleepingbag.type == "item")
assert(sleepingbag.icon.SetTextureArgs[1] == 311527)
for _, stacks in ipairs({ 1, 2, 3 }) do
    active = { { name = "Well-Rested", spellId = 429959, applications = stacks } }
    event("UNIT_AURA", "player")
    assert(not sleepingbag.shown, "any Well-Rested stack should hide the bag")
end
active = { { name = "Well-Rested", spellId = 1 } }
event("UNIT_AURA", "player")
assert(sleepingbag.shown, "unknown Well-Rested IDs must not match by name")
active = { "Well-Rested" }
event("UNIT_AURA", "player")
assert(not sleepingbag.shown, "name fallback applies only without an ID")
active = {}
event("UNIT_AURA", "player")
assert(sleepingbag.shown)
SlashCmdList.BUFFED("sleepingbag")
assert(not sleepingbag.shown and not BuffedDB.enabled.sleepingbag)
SlashCmdList.BUFFED("sleepingbag")
assert(sleepingbag.shown)
combat = true
before = mutations
active = { { name = "Well-Rested", spellId = 429959 } }
event("UNIT_AURA", "player")
assert(mutations == before)
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not sleepingbag.shown)
active, bags[0] = {}, {}
event("BAG_UPDATE_DELAYED")
assert(not sleepingbag.shown and sleepingbag.item == nil, "no bag means no reminder")

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
active = { { name = "Well Fed", spellId = 1243969 } }
event("UNIT_AURA", "player")
assert(not food.shown, "XP aura ID must satisfy food even when the client name differs")
active = { { name = "Well Fed", spellId = 1248422 } }
event("UNIT_AURA", "player")
assert(not food.shown, "client-observed Well Fed includes the verified XP effect")
event("PLAYER_STARTED_MOVING")
event("PLAYER_STOPPED_MOVING")
assert(not food.shown, "standing still again must not restore food with the XP-bearing aura")
active = { { name = "Well Fed", spellId = 1 } }
event("UNIT_AURA", "player")
assert(food.shown, "unverified Well Fed IDs must not satisfy the XP reminder")
active = { { name = "Well Fed", spellId = 1248422 } }
local modernAuras = C_UnitAuras
C_UnitAuras = nil
UnitBuff = function(_, index)
    local aura = active[index]
    if aura then return aura.name, nil, nil, nil, nil, nil, nil, nil, nil, aura.spellId end
end
event("UNIT_AURA", "player")
assert(not food.shown, "legacy aura ID must also satisfy food")
C_UnitAuras, UnitBuff = modernAuras, nil
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
for _, id in ipairs({ 8096, 8097, 8098, 12176, 1459, 1460, 1461, 10156, 10157, 23028 }) do
    active = { { name = "Not an English spell name", spellId = id } }
    event("UNIT_AURA", "player")
    assert(not intellect.shown, "verified Intellect aura ID must count: " .. id)
end
active = { { name = "Arcane Intellect", spellId = 1 } }
event("UNIT_AURA", "player")
assert(intellect.shown, "unknown Intellect IDs must not match by name")
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
-- Status remains in chat and is also selected for manual clipboard copying.
active = { { name = "Well Fed", spellId = 1243969 }, "Inner Fire" }
SlashCmdList.BUFFED("status")
local statusBox, statusPanel
for _, frame in ipairs(frames) do
    if frame.HighlightTextArgs then statusBox = frame end
    if frame.SetFrameStrataArgs then statusPanel = frame end
end
assert(statusBox and statusPanel.shown)
assert(statusBox.SetTextArgs[1]:find("Well Fed XP Boost", 1, true))
assert(statusBox.SetTextArgs[1]:find("Well Fed (spell ID: 1243969)", 1, true))
assert(statusBox.SetTextArgs[1]:find("Inner Fire (spell ID: unavailable)", 1, true))
assert(statusBox.SetTextArgs[1]:find("Player buffs via C_UnitAuras.GetBuffDataByIndex:", 1, true))
assert(statusBox.SetFocusArgs and statusBox.HighlightTextArgs)
statusPanel:Hide()
statusPanel.OnHide()
assert(statusBox.ClearFocusArgs)
local frameCount = #frames
SlashCmdList.BUFFED("status")
assert(#frames == frameCount and statusPanel.shown, "status window should be reused")
statusBox.OnEscapePressed()
assert(not statusPanel.shown)
for _, message in ipairs(messages) do
    assert(not message:find("Runtime error", 1, true), message)
end
-- A real client failure must not abort chat submission or require diagnostics
-- to work in combat. Retain the first failure and report it once combat ends.
C_SpellBook.GetNumSpellBookSkillLines = nil
C_SpellBook.GetSpellBookSkillLineInfo = nil
C_SpellBook.GetSpellBookItemName = nil
learned.Shadowguard = true
active = {}
event("SPELLS_CHANGED")
statusBox.SetText = function() error("simulated status display failure") end
combat = true
event("PLAYER_REGEN_DISABLED")
assert(pcall(SlashCmdList.BUFFED, "status"), "failed status must not escape the slash handler")
assert(not messages[#messages]:find("Runtime error", 1, true), "combat error report must be deferred")
statusBox.SetText = nil
combat = false
event("PLAYER_REGEN_ENABLED")
assert(messages[#messages]:find("/buffed status", 1, true))
assert(messages[#messages]:find("simulated status display failure", 1, true))
local reportCount = #messages
event("PLAYER_REGEN_ENABLED")
assert(#messages == reportCount, "deferred error must only print once")
SlashCmdList.BUFFED("status")
assert(statusBox.SetTextArgs[1]:find("Last runtime error:", 1, true))
assert(statusBox.SetTextArgs[1]:find("simulated status display failure", 1, true))
-- Reload while mounted, then enter combat before any aura scan: do not
-- manufacture 'missing' or 'unlearned' results from an absent snapshot.
local newEventsIndex = #frames + 1
mounted = true
assert(loadfile("Buffed.lua"))("Buffed")
local newEvents = frames[newEventsIndex]
newEvents.OnEvent(newEvents, "PLAYER_ENTERING_WORLD")
mounted, combat = false, true
SlashCmdList.BUFFED("status")
local emptySnapshotBox
for i = newEventsIndex, #frames do
    if frames[i].HighlightTextArgs then emptySnapshotBox = frames[i] end
end
assert(emptySnapshotBox)
assert(emptySnapshotBox.SetTextArgs[1]:find("No out-of-combat aura snapshot available.", 1, true))
assert(emptySnapshotBox.SetTextArgs[1]:find("aura unknown", 1, true))
assert(emptySnapshotBox.SetTextArgs[1]:find("availability/learned state unknown", 1, true))
combat = false
print("Buffed mock smoke tests passed")
