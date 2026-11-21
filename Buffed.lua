local _, addon = ...
local _, class = UnitClass("player")
local consumables = addon.consumables
local FishingNeeded, HydrocaneNeeded = addon.FishingNeeded, addon.HydrocaneNeeded

local buffs = {}
for _, buff in ipairs(addon.reminders) do
    if not buff.class or buff.class == class then
        buffs[#buffs + 1] = buff
    end
end

local events = CreateFrame("Frame")
local anchor, initialized
local enteredWorld = false
local combatEventActive = false
local function CombatLocked()
    -- Combat entry can precede the lockdown flag; block scans and secure
    -- changes from the entry event until combat ends.
    return combatEventActive or InCombatLockdown()
end
local moving = false
local buttons = {}
local availability = {}
local cachedActive, cachedDetails = {}, {}
local hasAuraSnapshot = false
local cachedCooldownReady = {}
local cachedFishingNeeded
local cachedHydrocaneNeeded
local CreateStatusWindow
local sleepingBagTimer
local sleepingBagWarning = 15 * 60

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffaad8ffBuffed:|r " .. message)
end

local lastRuntimeError, pendingRuntimeError
local function RunSafely(context, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok then
        if not pendingRuntimeError then
            lastRuntimeError = context .. ": " .. tostring(err)
        end
        pendingRuntimeError = true
    end
    if pendingRuntimeError and not CombatLocked() then
        Print("Runtime error (please share): " .. lastRuntimeError)
        pendingRuntimeError = false
    end
end

local function SpellTexture(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        return info and info.iconID
    end
    if GetSpellInfo then return select(3, GetSpellInfo(name)) end
end

local function Known(name)
    -- Scan names where possible: a name lookup can resolve to a different
    -- rank's ID than the one currently displayed in the player's spellbook.
    if GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, GetNumSpellTabs() do
            local _, _, offset, count = GetSpellTabInfo(tab)
            for slot = offset + 1, offset + count do
                if GetSpellBookItemName(slot, BOOKTYPE_SPELL or "spell") == name then
                    return true
                end
            end
        end
        return false
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if bank and C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemName then
        for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
            if info then
                for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                    if C_SpellBook.GetSpellBookItemName(slot, bank) == name then return true end
                end
            end
        end
        return false
    end
    local id
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(name)
        id = info and info.spellID
    elseif GetSpellInfo then
        id = select(7, GetSpellInfo(name))
    end
    if not id then return false end
    -- This API requires an ID and an explicit player spell bank, not a name.
    if bank and C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        return C_SpellBook.IsSpellInSpellBook(id, bank, true)
    end
    return IsSpellKnown and IsSpellKnown(id) or false
end

local function ActiveBuffs()
    -- Forever rejects aura access while secret in combat. Never call either
    -- aura API then; diagnostics may only use the last out-of-combat snapshot.
    if CombatLocked() then return cachedActive, cachedDetails end
    local active, details = {}, {}
    local wellRestedExpiration
    for i = 1, 255 do
        local name, spellID
        if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
            local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
            name = aura and aura.name
            spellID = aura and aura.spellId
            if spellID == 429959 or (not spellID and name == "Well-Rested") then
                local expiration = aura.expirationTime
                if not (issecretvalue and issecretvalue(expiration))
                    and type(expiration) == "number" and expiration > 0 then
                    wellRestedExpiration = expiration
                end
            end
        elseif UnitBuff then
            local aura = { UnitBuff("player", i) }
            name, spellID = aura[1], aura[10]
        end
        if not name then break end
        -- Prefer verified IDs. Only fall back to names if the API omits the ID;
        -- an unknown ID with a familiar name must not silently count as verified.
        if spellID then active[spellID] = true
        else active[name] = true end
        details[#details + 1] = name .. " (spell ID: " .. tostring(spellID or "unavailable") .. ")"
    end
    cachedActive, cachedDetails = active, details
    hasAuraSnapshot = true
    return active, details, wellRestedExpiration
end

local function FindConsumable(buff)
    local slots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots
    local itemID = C_Container and C_Container.GetContainerItemID or GetContainerItemID
    if not slots or not itemID then return nil end
    local carried = {}
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, slots(bag) do
            local id = itemID(bag, slot)
            if id then carried[id] = true end
        end
    end
    local selected
    local level = UnitLevel("player")
    for _, item in ipairs(consumables[buff.key]) do
        if carried[item.id] and level >= item.level
            and (not selected or item.level > selected.level) then
            selected = item
        end
    end
    return selected
end

local function ItemTexture(id, fallback)
    local icon = C_Item and C_Item.GetItemIconByID or GetItemIcon
    return (icon and icon(id)) or fallback or "Interface\\Icons\\INV_Scroll_01"
end

local function CooldownReady(buff, available)
    if not CombatLocked() then
        local info = available and C_Spell and C_Spell.GetSpellCooldown
            and C_Spell.GetSpellCooldown(buff.name)
        -- Only the out-of-combat API/fields confirmed in Forever are used.
        cachedCooldownReady[buff.key] = not not (info and info.isEnabled
            and (info.duration == 0 or info.startTime + info.duration <= GetTime()))
    end
    return cachedCooldownReady[buff.key]
end

local poisonSlot, poisonState
local function RefreshPoison()
    if class == "ROGUE" then poisonSlot, poisonState = addon.PoisonNeeded() end
end

local function HasBuff(active, buff)
    if buff.poison then return poisonSlot == nil end
    for _, id in ipairs(buff.auraIDs) do
        if active[id] then return true end
    end
    return active[buff.name] or active[buff.alternate] or active[buff.other]
end

local function RestorePosition()
    anchor:ClearAllPoints()
    local position = BuffedDB.position
    if position then
        anchor:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    else
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
    end
end

local function Refresh()
    -- Never mutate secure buttons in combat. Their parent is hidden by a
    -- secure state driver, then we rebuild once combat ends.
    if not initialized or CombatLocked() then return end
    if sleepingBagTimer then
        sleepingBagTimer:Cancel()
        sleepingBagTimer = nil
    end
    if UnitIsDeadOrGhost("player") or IsMounted() then
        for _, button in ipairs(buttons) do button:Hide() end
        anchor.label:SetShown(BuffedDB.unlocked)
        anchor:EnableMouse(BuffedDB.unlocked)
        return
    end
    local active, _, wellRestedExpiration = ActiveBuffs()
    cachedHydrocaneNeeded = HydrocaneNeeded()
    cachedFishingNeeded = FishingNeeded()
    RefreshPoison()
    -- User verified IsInInstance() returns true, "party" inside a Forever dungeon.
    local inInstance, instanceType = IsInInstance()
    local inDungeon = inInstance and instanceType == "party"
    local visible = 0
    for i, buff in ipairs(buffs) do
        local button = buttons[i]
        local item = (buff.item or buff.gear or buff.supplies) and FindConsumable(buff)
        local available
        if buff.item or buff.gear or buff.supplies then available = item ~= nil
        elseif buff.reminderOnly then available = true
        else available = not not Known(buff.name) end
        availability[buff.key] = available
        if buff.poison then
            button:SetAttribute("macrotext", item and poisonSlot
                and ("/use item:" .. item.id .. "\n/use " .. poisonSlot) or nil)
            button.displayName = item and poisonSlot and (item.name .. " (" .. (poisonSlot == 17 and "off hand" or "main hand") .. ")") or buff.name
        elseif buff.item then
            button:SetAttribute("item", item and ("item:" .. item.id) or nil)
            button.displayName = item and item.name or buff.name
        end
        local needed
        if buff.supplies then needed = cachedFishingNeeded
        elseif buff.gear then needed = cachedHydrocaneNeeded
        elseif buff.racial then needed = true -- cooldown-ready reminder, no aura mapping assumed
        else needed = not HasBuff(active, buff) end
        local ready = not buff.cooldown or CooldownReady(buff, available)
        local dungeonSuppressed = inDungeon and (buff.key == "camp" or buff.key == "sleepingbag")
        if buff.key == "sleepingbag" and available and not dungeonSuppressed and wellRestedExpiration then
            local untilWarning = wellRestedExpiration - GetTime() - sleepingBagWarning
            if untilWarning < 0 then
                needed = true
            elseif C_Timer and C_Timer.NewTimer then
                -- Refresh once just past the strict threshold, even when idle.
                sleepingBagTimer = C_Timer.NewTimer(untilWarning + 0.01, function()
                    sleepingBagTimer = nil
                    RunSafely("Well-Rested warning", Refresh)
                end)
            end
        end
        local missing = (available or buff.supplies) and needed and ready
        if missing and not dungeonSuppressed and not (buff.key == "food" and moving) then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", visible * 42, -4)
            button.noLure = buff.supplies and not item
            button.displayName = buff.supplies and (item and item.name or "Fishing Pole") or button.displayName
            button.icon:SetTexture(buff.supplies and not item and ItemTexture(6256, "Interface\\Icons\\INV_Fishingpole_02")
                or item and ItemTexture(item.id, buff.icon) or buff.icon or SpellTexture(buff.name) or 136243)
            button:Show()
            visible = visible + 1
        else
            button:Hide()
        end
    end
    anchor.label:SetText(BuffedDB.unlocked and "Buffed (drag here)" or "Buffed")
    anchor.label:SetShown(visible > 0 or BuffedDB.unlocked)
    anchor:EnableMouse(BuffedDB.unlocked)
end

local function Initialize()
    if initialized then return end
    if CombatLocked() then return end
    if type(BuffedDB) ~= "table" then BuffedDB = {} end
    BuffedDB.enabled = nil -- Retire legacy reminder toggles; keep bar settings.

    anchor = CreateFrame("Frame", "BuffedAnchor", UIParent, "SecureHandlerStateTemplate")
    anchor:SetSize(#buffs * 42 - 4, 20)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function(self)
        if BuffedDB.unlocked and not CombatLocked() then self:StartMoving() end
    end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        BuffedDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
        RestorePosition()
    end)
    anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchor.label:SetPoint("LEFT", 0, 0)
    RestorePosition()

    for i, buff in ipairs(buffs) do
        local button = CreateFrame("Button", "BuffedButton" .. i, anchor, "SecureActionButtonTemplate")
        button:SetSize(36, 36)
        button:RegisterForClicks("AnyUp", "AnyDown")
        if buff.reminderOnly then
            -- No secure action: this is an informational reminder, not a cast.
        elseif buff.poison then
            button:SetAttribute("type", "macro")
        elseif buff.item then
            button:SetAttribute("type", "item")
            button:SetAttribute("unit", "player")
        else
            button:SetAttribute("type", "spell")
            button:SetAttribute("spell", buff.name)
            button:SetAttribute("unit", "player")
        end
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.displayName or buff.name)
            if buff.supplies then
                GameTooltip:AddLine(self.noLure
                    and "Fishing Pole equipped without a temporary enchant; no supported lure in bags. Remember your staff! This icon is not clickable."
                    or "Fishing Pole equipped without a temporary enchant; lure in bags. Check its Fishing skill requirement. Remember your staff! This icon is not clickable.", 1, 1, 1)
            elseif buff.gear then
                GameTooltip:AddLine("Breath timer active. Equip Hydrocane for 50% longer underwater breath. This icon is not clickable.", 1, 1, 1)
            elseif buff.reminderOnly then
                GameTooltip:AddLine("Camp Benefits missing. Visit a camp to refresh it. This icon is not clickable.", 1, 1, 1)
            elseif buff.poison then
                GameTooltip:AddLine("Click to poison the missing hand. If both are missing, click again after application. Existing temporary enchants are left unchanged.", 1, 1, 1)
            elseif buff.key == "food" then
                GameTooltip:AddLine("Click to eat. Remain seated for at least 10 seconds for +5% kill XP.", 1, 1, 1)
            elseif buff.key == "sleepingbag" then
                GameTooltip:AddLine("Well-Rested is missing or has less than 15 minutes left. Click to unroll, then rest inside for at least one minute.", 1, 1, 1)
            elseif buff.item then
                GameTooltip:AddLine("Missing Intellect. Click to use this scroll on yourself.", 1, 1, 1)
            else
                GameTooltip:AddLine("Missing self-buff. Click to cast on yourself.", 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:Hide()
        buttons[i] = button
    end
    RegisterStateDriver(anchor, "visibility", "[combat] hide; show")
    CreateStatusWindow()
    initialized = true
    Refresh()
end

local statusWindow, statusText
CreateStatusWindow = function()
    if not statusWindow then
        statusWindow = CreateFrame("Frame", nil, UIParent)
        statusWindow:SetSize(600, 360)
        statusWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        statusWindow:SetFrameStrata("DIALOG")
        local background = statusWindow:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0.95)
        local title = statusWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("Buffed status — Ctrl+C to copy; Escape to close")
        local close = CreateFrame("Button", nil, statusWindow, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", statusWindow, "TOPRIGHT", 0, 0)
        close:SetScript("OnClick", function() statusWindow:Hide() end)
        local scroll = CreateFrame("ScrollFrame", nil, statusWindow, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", statusWindow, "TOPLEFT", 16, -44)
        scroll:SetPoint("BOTTOMRIGHT", statusWindow, "BOTTOMRIGHT", -36, 16)
        statusText = CreateFrame("EditBox", nil, scroll)
        statusText:SetSize(540, 280)
        statusText:SetMultiLine(true)
        statusText:SetFontObject("ChatFontNormal")
        statusText:SetAutoFocus(false)
        statusText:SetScript("OnEscapePressed", function() statusWindow:Hide() end)
        scroll:SetScrollChild(statusText)
        statusWindow:SetScript("OnHide", function() statusText:ClearFocus() end)
        statusWindow:Hide()
    end
end

local function ShowStatus(lines)
    statusText:SetText(table.concat(lines, "\n"))
    statusWindow:Show()
    statusText:SetFocus()
    statusText:HighlightText()
end

SLASH_BUFFED1 = "/buffed"
local function HandleCommand(message)
    if not initialized then
        Print("Not ready yet. Leave combat and try again.")
        return
    end
    local command = message:lower():match("^%s*(.-)%s*$")
    if command == "" or command == "help" then
        Print("/buffed unlock | lock | reset | status")
        return
    end
    if command == "status" then
        local active, details = ActiveBuffs()
        local lines = {}
        local function AddLine(line)
            lines[#lines + 1] = line
            Print(line)
        end
        if lastRuntimeError then AddLine("Last runtime error: " .. lastRuntimeError) end
        AddLine("Combat: " .. tostring(CombatLocked()) .. ", mounted: " .. tostring(IsMounted())
            .. ", dead/ghost: " .. tostring(UnitIsDeadOrGhost("player")) .. ", moving: " .. tostring(moving))
        if CombatLocked() then
            AddLine("Combat aura access blocked by client; conditional combat reminders disabled.")
            AddLine("Aura states, item availability and learned spells below are cached, not live.")
            AddLine("Breath/equipment/enchant state below is also cached, not live.")
            if not hasAuraSnapshot then AddLine("No out-of-combat aura snapshot available.") end
        end
        if not CombatLocked() then
            cachedHydrocaneNeeded = HydrocaneNeeded()
            cachedFishingNeeded = FishingNeeded()
            RefreshPoison()
        end
        if class == "ROGUE" then
            AddLine("Weapon enchants" .. (CombatLocked() and " (cached, not live)" or "") .. ": " .. (poisonState or "unknown"))
        end
        for _, buff in ipairs(buffs) do
            local available = availability[buff.key]
            if not CombatLocked() then
                if buff.item or buff.gear or buff.supplies then available = FindConsumable(buff) ~= nil
                elseif buff.reminderOnly then available = true
                else available = not not Known(buff.name) end
                availability[buff.key] = available
            end
            local cooldownState
            if buff.cooldown then
                local ready = CooldownReady(buff, available)
                cooldownState = ready == nil and ", cooldown unknown"
                    or ready and ", cooldown ready" or ", cooldown not ready"
                if CombatLocked() then cooldownState = cooldownState .. " (cached, not live)" end
            end
            AddLine(buff.name .. ": "
                .. (available == nil and "availability/learned state unknown"
                    or (buff.supplies and (available and "lure in bags (skill not checked)" or "no supported lure in bags")
                        or (buff.item or buff.gear) and (available and "usable item in bags" or "no supported usable item")
                        or buff.reminderOnly and "reminder only"
                        or (available and "learned" or "not learned")))
                .. (buff.supplies and (cachedFishingNeeded == nil and ", pole/enchant state unknown"
                        or cachedFishingNeeded and ", pole equipped without temporary enchant" or ", not needed")
                    or buff.gear and (cachedHydrocaneNeeded == nil and ", breath/equipment state unknown"
                        or cachedHydrocaneNeeded and ", breath timer active, unequipped" or ", not needed")
                    or not hasAuraSnapshot and ", aura unknown"
                    or (HasBuff(active, buff) and ", active" or ", missing"))
                .. (cooldownState or ""))
        end
        AddLine((CombatLocked() and "Cached player buffs via " or "Player buffs via ")
            .. (C_UnitAuras and C_UnitAuras.GetBuffDataByIndex
            and "C_UnitAuras.GetBuffDataByIndex" or "UnitBuff") .. ":")
        if #details == 0 then
            AddLine(CombatLocked() and "(none in cached snapshot)" or "(none returned)")
        end
        for _, detail in ipairs(details) do AddLine(detail) end
        ShowStatus(lines)
        return
    end
    if command ~= "unlock" and command ~= "lock" and command ~= "reset" then
        Print("Unknown command. Use /buffed help.")
        return
    end
    if CombatLocked() then
        Print("Settings cannot be changed during combat.")
        return
    end
    if command == "reset" then
        BuffedDB.position = nil
        RestorePosition()
    else
        BuffedDB.unlocked = command == "unlock"
    end
    Refresh()
end

SlashCmdList.BUFFED = function(message)
    RunSafely("/buffed " .. message, HandleCommand, message)
end

events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_UNGHOST")
events:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
events:RegisterEvent("PLAYER_STARTED_MOVING")
events:RegisterEvent("PLAYER_STOPPED_MOVING")
events:RegisterEvent("MIRROR_TIMER_START")
events:RegisterEvent("MIRROR_TIMER_STOP")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("UNIT_INVENTORY_CHANGED")
local function HandleEvent(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then combatEventActive = true
    elseif event == "PLAYER_REGEN_ENABLED" then combatEventActive = false end
    if event == "PLAYER_ENTERING_WORLD" then
        enteredWorld = true
        moving = GetUnitSpeed("player") > 0
    end
    -- Spell/bag/aura events can arrive before the player enters the world.
    -- If world entry occurs in combat, initialization waits until combat ends.
    if not enteredWorld then return end
    if event == "UNIT_AURA" then
        -- Avoid inspecting restricted event payloads as well as the aura APIs.
        if CombatLocked() then return end
        if unit ~= "player" then return end
    end
    if (event == "MIRROR_TIMER_START" or event == "MIRROR_TIMER_STOP"
        or (event == "UNIT_INVENTORY_CHANGED" and unit == "player")) and not CombatLocked() then
        -- Timer and inventory events can precede the updated API state. Recheck
        -- once next frame, then remove the handler (no continuous polling).
        events:SetScript("OnUpdate", function(self)
            self:SetScript("OnUpdate", nil)
            RunSafely("Deferred breath timer refresh", Refresh)
        end)
    end
    -- Track transitions even in combat, without touching secure frames there.
    if event == "PLAYER_STARTED_MOVING" then moving = true
    elseif event == "PLAYER_STOPPED_MOVING" then moving = false end
    if not initialized then Initialize() else Refresh() end
end

events:SetScript("OnEvent", function(self, event, unit)
    RunSafely(event, HandleEvent, self, event, unit)
end)
