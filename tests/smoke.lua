-- Standalone mock smoke test; not loaded by the addon.
local frames, active, learned = {}, {}, {}
local combat, dead, mounted = false, false, false
local bags, level = {}, 22
local speed = 0
local inInstance, instanceType = false, "none"
function IsInInstance() return inInstance, instanceType end
function GetUnitSpeed(unit) assert(unit == "player"); return speed end
local mutations, scans = 0, 0
local function recordScan()
    assert(not combat and not dead and not mounted, "unnecessary or restricted scan while suppressed")
    scans = scans + 1
end
local mirrorTimers, mainHand = {}, nil
function GetMirrorTimerInfo(index)
    recordScan()
    return mirrorTimers[index] or "UNKNOWN", 0, 0, 0, 0, "", 0
end
function GetInventoryItemID(unit, slot)
    recordScan()
    assert(unit == "player" and slot == 16)
    return mainHand
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
local spellIDs = { ["Power Word: Fortitude"] = 1244, ["Inner Fire"] = 588, ["Shadowguard"] = 18137, ["Divine Spirit"] = 14752 }
Enum = { SpellBookSpellBank = { Player = 0 } }
local cooldownInfo = { startTime = 0, duration = 0, isEnabled = true }
local now = 2000
function GetTime() return now end
C_Spell = {
    GetSpellInfo = function(name) return { iconID = 123, spellID = spellIDs[name] } end,
    GetSpellCooldown = function(name)
        recordScan()
        assert(name == "Nature's Grasp")
        return cooldownInfo
    end,
}
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
local fortitude, spirit, fire, guard, food, intellect
for _, frame in ipairs(frames) do
    if frame.spell == "Power Word: Fortitude" then fortitude = frame
    elseif frame.spell == "Divine Spirit" then spirit = frame
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
assert(fortitude and spirit and fire and guard and food and intellect)
bags[0] = {}
event("BAG_UPDATE_DELAYED")
assert(fortitude.shown and fire.shown, "missing buffs should appear")
assert(fortitude.unit == "player" and not guard.shown, "unlearned Shadowguard should hide")
assert(not spirit.shown, "unlearned Divine Spirit should hide")
learned["Divine Spirit"] = true
event("SPELLS_CHANGED")
assert(spirit.shown and spirit.unit == "player" and spirit.type == "spell",
    "learning Divine Spirit should enable a self-cast reminder")
assert(BuffedDB.enabled.spirit, "Divine Spirit should default on")
for _, name in ipairs({ "Divine Spirit", "Prayer of Spirit" }) do
    active = { name }
    event("UNIT_AURA", "player")
    assert(not spirit.shown, "Spirit name fallback should hide the reminder")
end
active = { { name = "Divine Spirit", spellId = 1 } }
event("UNIT_AURA", "player")
assert(spirit.shown, "an unknown Spirit ID must not match by name")
SlashCmdList.BUFFED("spirit")
assert(not spirit.shown and not BuffedDB.enabled.spirit)
SlashCmdList.BUFFED("spirit")
assert(spirit.shown and BuffedDB.enabled.spirit)
for _, command in ipairs({ "shadow", "form" }) do
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
    { button = spirit, ids = { 14752, 14818, 14819, 27841, 27681 } },
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
-- Reproduce combat entry arriving before InCombatLockdown becomes true.
combat = false
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

-- Hydrocane is an informational bag/equipment/breath-timer reminder, not an aura.
assert(BuffedDB.enabled.hydrocane)
assert(frames[1].events.MIRROR_TIMER_START and frames[1].events.MIRROR_TIMER_STOP
    and frames[1].events.PLAYER_EQUIPMENT_CHANGED)
level, bags[0], mirrorTimers[2] = 27, { 9452 }, "BREATH"
event("MIRROR_TIMER_START", "BREATH")
local hydrocane
for _, frame in ipairs(frames) do
    if frame.icon and frame.icon.SetTextureArgs and frame.icon.SetTextureArgs[1] == 109452 then
        hydrocane = frame
    end
end
assert(hydrocane and hydrocane.shown)
assert(hydrocane.type == nil and hydrocane.item == nil and hydrocane.spell == nil,
    "Hydrocane must have no equip/cast/click action")
level = 26
event("PLAYER_LEVEL_UP")
assert(not hydrocane.shown, "Hydrocane requires level 27")
level = 27
event("PLAYER_LEVEL_UP")
assert(hydrocane.shown)
mainHand = 9452
event("PLAYER_EQUIPMENT_CHANGED", 16)
assert(not hydrocane.shown, "equipped Hydrocane must hide the reminder")
mainHand = 123
for index = 1, 3 do
    mirrorTimers = { [index] = "BREATH" }
    event("MIRROR_TIMER_START", "BREATH")
    assert(hydrocane.shown, "BREATH need not occupy slot 2")
end
mirrorTimers = { "FATIGUE", "FEIGNDEATH" }
event("MIRROR_TIMER_STOP", "BREATH")
assert(not hydrocane.shown, "surface/other timers must not trigger Hydrocane")
mirrorTimers[2] = "BREATH"
event("MIRROR_TIMER_START", "BREATH")
SlashCmdList.BUFFED("hydrocane")
assert(not hydrocane.shown and not BuffedDB.enabled.hydrocane)
SlashCmdList.BUFFED("hydrocane")
assert(hydrocane.shown)
bags[0] = {}
event("BAG_UPDATE_DELAYED")
assert(not hydrocane.shown, "no carried Hydrocane means no reminder")
bags[0] = { 9452 }
event("BAG_UPDATE_DELAYED")
assert(hydrocane.shown)
mounted = true
event("PLAYER_MOUNT_DISPLAY_CHANGED")
assert(not hydrocane.shown)
mounted, dead = false, true
event("PLAYER_DEAD")
assert(not hydrocane.shown)
dead = false
event("PLAYER_UNGHOST")
assert(hydrocane.shown)
before, previousScans = mutations, scans
event("PLAYER_REGEN_DISABLED")
combat = true
mirrorTimers = {}
event("MIRROR_TIMER_STOP", "BREATH")
event("PLAYER_EQUIPMENT_CHANGED", 16)
SlashCmdList.BUFFED("status")
assert(scans == previousScans and mutations == before,
    "combat timer/equipment events and diagnostics must not read live data or mutate secure UI")
assert(combatStatusBox.SetTextArgs[1]:find("Breath/equipment state below is also cached, not live.", 1, true))
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not hydrocane.shown, "post-combat refresh must re-read the breath timer")
-- Reproduce the timer API updating only AFTER the event: no movement needed.
local function nextFrame()
    local update = frames[1].OnUpdate
    assert(update, "timer event should schedule a one-shot refresh")
    update(frames[1], 0.016)
    assert(not frames[1].OnUpdate, "one-shot handler must remove itself")
end
mirrorTimers[2] = "BREATH"
event("MIRROR_TIMER_START", "BREATH")
nextFrame()
assert(hydrocane.shown)
event("MIRROR_TIMER_STOP", "BREATH")
assert(hydrocane.shown, "mock timer API is deliberately stale during stop event")
mirrorTimers = {}
nextFrame()
assert(not hydrocane.shown, "must hide without a movement/other event after timer API updates")
event("MIRROR_TIMER_START", "BREATH")
mirrorTimers[2] = "BREATH"
nextFrame()
assert(hydrocane.shown, "deferred refresh also handles stale start events")
-- If combat starts between event and callback, the callback must not scan/mutate.
event("MIRROR_TIMER_STOP", "BREATH")
event("PLAYER_REGEN_DISABLED")
combat = true
before, previousScans = mutations, scans
mirrorTimers = {}
nextFrame()
assert(scans == previousScans and mutations == before)
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not hydrocane.shown)
level, mainHand, bags[0] = 22, nil, {}

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

-- Camp Benefits is an unconditional informational reminder, not a cast/item.
local camp
for _, frame in ipairs(frames) do
    if frame.icon and frame.icon.SetTextureArgs
        and frame.icon.SetTextureArgs[1] == "Interface\\Icons\\inv_camelot_camping_campbenefits" then
        camp = frame
    end
end
assert(camp and camp.shown and BuffedDB.enabled.camp)
assert(camp.type == nil and camp.spell == nil and camp.item == nil)
active = { { name = "Camp Benefits", spellId = 1229741 } }
event("UNIT_AURA", "player")
assert(not camp.shown)
active = { { name = "Camp Benefits", spellId = 1 } }
event("UNIT_AURA", "player")
assert(camp.shown, "unverified IDs must not satisfy camp reminder")
active = { "Camp Benefits" }
event("UNIT_AURA", "player")
assert(not camp.shown)
active = {}
event("UNIT_AURA", "player")
assert(camp.shown)
SlashCmdList.BUFFED("camp")
assert(not camp.shown and not BuffedDB.enabled.camp)
SlashCmdList.BUFFED("camp")
assert(camp.shown)
SlashCmdList.BUFFED("status")
assert(combatStatusBox.SetTextArgs[1]:find("Camp Benefits: on, reminder only, missing", 1, true))
combatStatusBox.OnEscapePressed()

-- World entry updates dungeon suppression; other reminders remain available.
bags[0] = { 211527, 2681, 2290 }
event("BAG_UPDATE_DELAYED")
assert(camp.shown and sleepingbag.shown)
inInstance, instanceType = true, "party"
event("PLAYER_ENTERING_WORLD")
assert(not camp.shown and not sleepingbag.shown, "camp and bag must hide in dungeons")
assert(fortitude.shown and food.shown and intellect.shown, "other reminders must remain unchanged")
event("UNIT_AURA", "player")
assert(not camp.shown and not sleepingbag.shown, "normal refreshes must preserve suppression")
inInstance, instanceType = false, "none"
event("PLAYER_ENTERING_WORLD")
assert(camp.shown and sleepingbag.shown, "missing reminders return outside dungeons")
-- Dungeon transitions in combat defer all scans and secure mutations.
combat = true
local beforeDungeonMutations, beforeDungeonScans = mutations, scans
inInstance, instanceType = true, "party"
event("PLAYER_ENTERING_WORLD")
assert(mutations == beforeDungeonMutations and scans == beforeDungeonScans)
combat = false
event("PLAYER_REGEN_ENABLED")
assert(not camp.shown and not sleepingbag.shown)
combat = true
beforeDungeonMutations, beforeDungeonScans = mutations, scans
inInstance, instanceType = false, "none"
event("PLAYER_ENTERING_WORLD")
assert(mutations == beforeDungeonMutations and scans == beforeDungeonScans)
combat = false
event("PLAYER_REGEN_ENABLED")
assert(camp.shown and sleepingbag.shown)
bags[0] = {}
event("BAG_UPDATE_DELAYED")

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
for _, id in ipairs({ 1248406, 1248420, 1248421, 1248422, 1248688,
    1249519, 1249520, 1249521, 1249523 }) do
    active = { { name = "Well Fed", spellId = id } }
    event("UNIT_AURA", "player")
    assert(not food.shown, "verified XP-bearing Well Fed must hide food: " .. id)
end
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
bags[0] = { 250077 }
level = 4
event("BAG_UPDATE_DELAYED")
assert(not food.shown, "Twice-Spiced Raptor Slice requires level 5")
level = 5
event("BAG_UPDATE_DELAYED")
assert(food.shown and food.item == "item:250077", "select Twice-Spiced Raptor Slice at level 5")
for _, entry in ipairs({ { 6290, 1 }, { 787, 1 }, { 4592, 5 },
    { 8364, 25 }, { 13927, 35 }, { 13932, 35 }, { 13934, 45 },
    { 5095, 5 }, { 21072, 10 }, { 21217, 30 }, { 274971, 25 },
    { 13931, 35 }, { 13935, 45 }, { 249869, 35 }, { 249865, 1 },
    { 249866, 5 }, { 249867, 15 }, { 249868, 25 }, { 13933, 45 },
    { 249870, 45 } }) do
    local id, requiredLevel = entry[1], entry[2]
    bags[0] = { id }
    if requiredLevel > 1 then
        level = requiredLevel - 1
        event("BAG_UPDATE_DELAYED")
        assert(not food.shown, "food must hide below required level: " .. id)
    end
    level = requiredLevel
    event("BAG_UPDATE_DELAYED")
    assert(food.shown and food.item == "item:" .. id, "food must be selectable: " .. id)
end
level = 22
for _, id in ipairs({ 2682, 5477, 2683, 21072, 12210, 3665, 250077 }) do
    bags[0] = { id }
    event("BAG_UPDATE_DELAYED")
    assert(food.shown and food.item == "item:" .. id)
end
for _, id in ipairs({ 2679, 5525, 5527, 17197, 17198, 6657, 12217, 13933 }) do
    bags[0] = { id }
    event("BAG_UPDATE_DELAYED")
    assert(not food.shown, "non-XP or unusable food must not be selected")
end
bags[0] = { 12210, 2681, 2683, 8364 }
event("BAG_UPDATE_DELAYED")
assert(food.item == "item:12210", "prefer highest usable level, excluding level-25 food at level 22")
level = 25
event("BAG_UPDATE_DELAYED")
assert(food.item == "item:8364", "prefer newly usable higher-level food")
bags[0] = { 2683, 2681 }
event("BAG_UPDATE_DELAYED")
assert(food.item == "item:2683", "fall back to the highest remaining usable food")
bags[0] = { 787, 6290 }
event("BAG_UPDATE_DELAYED")
assert(food.item == "item:6290", "equal-level ties use list order, not bag order")
level = 22
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
-- Fresh druid session: shared reminders plus druid spells, never priest spells.
frames, active, learned, bags = {}, {}, {}, {}
BuffedDB = nil
function UnitClass() return "Druid", "DRUID" end
spellIDs["Mark of the Wild"] = 1126
spellIDs.Thorns = 467
spellIDs["Nature's Grasp"] = 16689
assert(loadfile("Buffed.lua"))("Buffed")
event("PLAYER_ENTERING_WORLD")
local mark, thorns, grasp, druidFood, druidCamp
local secureButtons = 0
for _, frame in ipairs(frames) do
    if frame.type == "spell" then
        if frame.spell == "Mark of the Wild" then mark = frame
        elseif frame.spell == "Thorns" then thorns = frame
        elseif frame.spell == "Nature's Grasp" then grasp = frame
        else error("druids must not get priest spells") end
    elseif frame.type == "item" then druidFood = druidFood or frame
    elseif frame.icon and frame.icon.SetTextureArgs
        and frame.icon.SetTextureArgs[1] == "Interface\\Icons\\inv_camelot_camping_campbenefits" then
        druidCamp = frame
    end
    if frame.type then secureButtons = secureButtons + 1 end
end
assert(secureButtons == 6 and mark and thorns and grasp and druidFood and druidCamp,
    "druid scope includes Nature's Grasp and all shared reminders")
assert(frames[1].events.SPELL_UPDATE_COOLDOWN)
assert(not grasp.shown and BuffedDB.enabled.grasp)
learned["Nature's Grasp"] = true
event("SPELLS_CHANGED")
assert(grasp.shown and grasp.unit == "player" and grasp.type == "spell")
cooldownInfo = { startTime = 1949.686, duration = 60, isEnabled = true }
event("SPELL_UPDATE_COOLDOWN")
assert(not grasp.shown)
now = 2010
event("SPELL_UPDATE_COOLDOWN")
assert(grasp.shown, "expired cooldown must restore reminder")
cooldownInfo = { startTime = 0, duration = 0, isEnabled = false }
event("SPELL_UPDATE_COOLDOWN")
assert(not grasp.shown)
cooldownInfo = nil
event("SPELL_UPDATE_COOLDOWN")
assert(not grasp.shown, "unavailable cooldown data must not claim ready")
cooldownInfo = { startTime = 0, duration = 0, isEnabled = true }
for _, id in ipairs({ 16689, 16810, 16811, 16812, 16813, 17329 }) do
    active = { { name = "client aura", spellId = id } }
    event("UNIT_AURA", "player")
    assert(not grasp.shown)
end
active = { "Nature's Grasp" }
event("UNIT_AURA", "player")
assert(not grasp.shown)
active = { { name = "Nature's Grasp", spellId = 999999 } }
event("UNIT_AURA", "player")
assert(grasp.shown)
active = {}
SlashCmdList.BUFFED("grasp")
assert(not grasp.shown and not BuffedDB.enabled.grasp)
SlashCmdList.BUFFED("grasp")
assert(grasp.shown)
assert(druidCamp.shown and BuffedDB.enabled.camp)
assert(druidCamp.type == nil and druidCamp.spell == nil and druidCamp.item == nil)
active = { { name = "Camp Benefits", spellId = 1229741 } }
event("UNIT_AURA", "player")
assert(not druidCamp.shown)
active = {}
event("UNIT_AURA", "player")
assert(druidCamp.shown)
SlashCmdList.BUFFED("camp")
assert(not druidCamp.shown and not BuffedDB.enabled.camp)
SlashCmdList.BUFFED("camp")
assert(druidCamp.shown and BuffedDB.enabled.camp)
inInstance, instanceType = true, "party"
event("PLAYER_ENTERING_WORLD")
assert(not druidCamp.shown, "druid camp reminder must hide in dungeons")
inInstance, instanceType = false, "none"
event("PLAYER_ENTERING_WORLD")
assert(druidCamp.shown)
assert(not thorns.shown, "unlearned Thorns must hide")
learned.Thorns = true
event("SPELLS_CHANGED")
assert(thorns.shown and thorns.unit == "player" and thorns.type == "spell" and BuffedDB.enabled.thorns)
for _, id in ipairs({ 467, 782, 1075, 8914, 9756, 9910 }) do
    active = { { name = "client aura", spellId = id } }
    event("UNIT_AURA", "player")
    assert(not thorns.shown, "verified Thorns ID must count: " .. id)
end
active = { "Thorns" }
event("UNIT_AURA", "player")
assert(not thorns.shown, "Thorns name fallback must count")
active = { { name = "Thorns", spellId = 999999 } }
event("UNIT_AURA", "player")
assert(thorns.shown, "unknown Thorns IDs must not match by name")
SlashCmdList.BUFFED("thorns")
assert(not thorns.shown and not BuffedDB.enabled.thorns)
SlashCmdList.BUFFED("thorns")
assert(thorns.shown and BuffedDB.enabled.thorns)
active = {}
assert(not mark.shown and not druidFood.shown, "unlearned Mark and absent food should hide")
learned["Mark of the Wild"] = true
event("SPELLS_CHANGED")
assert(mark.shown and mark.unit == "player" and BuffedDB.enabled.mark)
for _, id in ipairs({ 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 }) do
    active = { { name = "client aura", spellId = id } }
    event("UNIT_AURA", "player")
    assert(not mark.shown, "verified Mark/Gift ID must count: " .. id)
end
for _, name in ipairs({ "Mark of the Wild", "Gift of the Wild" }) do
    active = { name }
    event("UNIT_AURA", "player")
    assert(not mark.shown, "Mark/Gift name fallback should count")
end
active = { { name = "Mark of the Wild", spellId = 999999 } }
event("UNIT_AURA", "player")
assert(mark.shown, "unknown Mark IDs must not match by name")
SlashCmdList.BUFFED("mark")
assert(not mark.shown and not BuffedDB.enabled.mark)
SlashCmdList.BUFFED("mark")
assert(mark.shown)
bags[0] = { 2681 }
event("BAG_UPDATE_DELAYED")
assert(druidFood.shown and druidFood.item == "item:2681" and druidFood.unit == "player")
active = { { name = "Well Fed", spellId = 1249519 } }
event("UNIT_AURA", "player")
assert(not druidFood.shown and mark.shown)
active, bags = {}, {}
event("BAG_UPDATE_DELAYED")
assert(not druidFood.shown, "removing food must hide the druid reminder")
local beforeCombat = scans
combat = true
event("PLAYER_REGEN_DISABLED")
event("UNIT_AURA", "player")
event("SPELL_UPDATE_COOLDOWN")
SlashCmdList.BUFFED("status")
assert(scans == beforeCombat, "druid combat diagnostics must use cached data")
combat = false
event("PLAYER_REGEN_ENABLED")
mounted = true
event("PLAYER_MOUNT_DISPLAY_CHANGED", "player")
assert(not mark.shown and not thorns.shown)
mounted = false
event("PLAYER_MOUNT_DISPLAY_CHANGED", "player")
assert(mark.shown and thorns.shown)
dead = true
event("PLAYER_DEAD")
assert(not mark.shown and not thorns.shown)
dead = false
event("PLAYER_ALIVE")
assert(mark.shown and thorns.shown)
-- Shared reminders work for every class, independent of learned class spells.
for _, classToken in ipairs({ "PRIEST", "DRUID", "WARRIOR", "MAGE", "ROGUE",
    "HUNTER", "WARLOCK", "PALADIN", "SHAMAN" }) do
    frames, active, learned, bags = {}, {}, {}, {}
    BuffedDB = nil
    level = 60
    function UnitClass() return classToken, classToken end
    assert(loadfile("Buffed.lua"))("Buffed")
    event("PLAYER_ENTERING_WORLD")
    local itemButtons, spellButtons, sharedCamp = {}, {}, nil
    for _, frame in ipairs(frames) do
        if frame.type == "item" then
            itemButtons[#itemButtons + 1] = frame
            assert(not frame.shown, "absent items must hide: " .. classToken)
        elseif frame.type == "spell" then
            spellButtons[#spellButtons + 1] = frame
            local druidSpell = frame.spell == "Mark of the Wild" or frame.spell == "Thorns"
                or frame.spell == "Nature's Grasp"
            assert((classToken == "DRUID" and druidSpell)
                or (classToken == "PRIEST" and not druidSpell), "class spell leaked")
        elseif frame.icon and frame.icon.SetTextureArgs
            and frame.icon.SetTextureArgs[1] == "Interface\\Icons\\inv_camelot_camping_campbenefits" then
            sharedCamp = frame
        end
    end
    assert(#itemButtons == 3 and sharedCamp and sharedCamp.shown)
    assert(#spellButtons == (classToken == "PRIEST" and 4 or classToken == "DRUID" and 3 or 0))
    bags[0] = { 2681, 955, 211527 }
    event("BAG_UPDATE_DELAYED")
    local selected = {}
    for _, button in ipairs(itemButtons) do
        assert(button.shown and button.unit == "player")
        selected[button.item] = true
    end
    assert(selected["item:2681"] and selected["item:955"] and selected["item:211527"])
    active = { { name = "Well Fed XP Boost", spellId = 1243969 },
        { name = "Intellect", spellId = 8096 },
        { name = "Well-Rested", spellId = 429959 },
        { name = "Camp Benefits", spellId = 1229741 } }
    event("UNIT_AURA", "player")
    for _, button in ipairs(itemButtons) do assert(not button.shown) end
    assert(not sharedCamp.shown)
    active, bags = {}, {}
    event("BAG_UPDATE_DELAYED")
    for _, button in ipairs(itemButtons) do assert(not button.shown) end
    assert(sharedCamp.shown)
    SlashCmdList.BUFFED("sleepingbag")
    assert(not BuffedDB.enabled.sleepingbag)
    SlashCmdList.BUFFED("intellect")
    assert(not BuffedDB.enabled.intellect)
end
print("Buffed mock smoke tests passed")
