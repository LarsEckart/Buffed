local _, class = UnitClass("player")
if class ~= "PRIEST" then return end

-- Names intentionally target the English client. Group prayers satisfy the
-- same requirement, but reminders cast the single-target spell on yourself.
local buffs = {
    { key = "fortitude", name = "Power Word: Fortitude", alternate = "Prayer of Fortitude" },
    { key = "fire", name = "Inner Fire" },
    { key = "spirit", name = "Divine Spirit", alternate = "Prayer of Spirit" },
    { key = "shadow", name = "Shadow Protection", alternate = "Prayer of Shadow Protection", optional = true },
    { key = "form", name = "Shadowform", optional = true },
    { key = "shadowguard", name = "Shadowguard" },
    { key = "food", name = "Well Fed", reminderOnly = true, icon = "Interface\\Icons\\INV_Misc_Food_15" },
}

local events = CreateFrame("Frame")
local anchor, initialized
local buttons = {}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffaad8ffBuffed:|r " .. message)
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
    local active = {}
    for i = 1, 255 do
        local name
        if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
            local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
            name = aura and aura.name
        elseif UnitBuff then
            name = UnitBuff("player", i)
        end
        if not name then break end
        active[name] = true
    end
    return active
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
    if not initialized or InCombatLockdown() then return end
    local active = ActiveBuffs()
    local visible = 0
    local suppressed = UnitIsDeadOrGhost("player") or IsMounted()
    for i, buff in ipairs(buffs) do
        local button = buttons[i]
        local missing = BuffedDB.enabled[buff.key] and (buff.reminderOnly or Known(buff.name))
            and not active[buff.name] and not active[buff.alternate]
        if missing and not suppressed then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", visible * 42, -4)
            button.icon:SetTexture(buff.icon or SpellTexture(buff.name) or 136243)
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
    if InCombatLockdown() then return end
    if type(BuffedDB) ~= "table" then BuffedDB = {} end
    if type(BuffedDB.enabled) ~= "table" then BuffedDB.enabled = {} end
    for _, buff in ipairs(buffs) do
        if BuffedDB.enabled[buff.key] == nil then
            BuffedDB.enabled[buff.key] = not buff.optional
        end
    end

    anchor = CreateFrame("Frame", "BuffedAnchor", UIParent, "SecureHandlerStateTemplate")
    anchor:SetSize(206, 20)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:RegisterForDrag("LeftButton")
    anchor:SetScript("OnDragStart", function(self)
        if BuffedDB.unlocked and not InCombatLockdown() then self:StartMoving() end
    end)
    anchor:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        BuffedDB.position = { point = point, relativePoint = relativePoint, x = x, y = y }
    end)
    anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchor.label:SetPoint("LEFT", 0, 0)
    RestorePosition()

    for i, buff in ipairs(buffs) do
        local button = CreateFrame("Button", "BuffedButton" .. i, anchor, "SecureActionButtonTemplate")
        button:SetSize(36, 36)
        button:RegisterForClicks("AnyUp", "AnyDown")
        if not buff.reminderOnly then
            button:SetAttribute("type", "spell")
            button:SetAttribute("spell", buff.name)
            button:SetAttribute("unit", "player")
        end
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(buff.name)
            if buff.reminderOnly then
                GameTooltip:AddLine("Eat buff food from your bags until Well Fed appears.", 1, 1, 1)
                GameTooltip:AddLine("Reminder only; this icon does not use food.", 1, 1, 1)
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
    initialized = true
    Refresh()
end

SLASH_BUFFED1 = "/buffed"
SlashCmdList.BUFFED = function(message)
    if not initialized then
        Print("Not ready yet. Leave combat and try again.")
        return
    end
    local command = message:lower():match("^%s*(.-)%s*$")
    if command == "" or command == "help" then
        Print("/buffed unlock | lock | reset | status")
        Print("Toggle a reminder: /buffed fortitude | fire | spirit | shadow | form | shadowguard | food")
        return
    end
    if command == "status" then
        local active = ActiveBuffs()
        Print("Combat: " .. tostring(InCombatLockdown()) .. ", mounted: " .. tostring(IsMounted())
            .. ", dead/ghost: " .. tostring(UnitIsDeadOrGhost("player")))
        for _, buff in ipairs(buffs) do
            Print(buff.name .. ": " .. (BuffedDB.enabled[buff.key] and "on" or "off")
                .. (buff.reminderOnly and ", reminder only" or (Known(buff.name) and ", learned" or ", not learned"))
                .. ((active[buff.name] or active[buff.alternate]) and ", active" or ", missing"))
        end
        return
    end
    if InCombatLockdown() then
        Print("Settings cannot be changed during combat.")
        return
    end
    if command == "unlock" or command == "lock" then
        BuffedDB.unlocked = command == "unlock"
    elseif command == "reset" then
        BuffedDB.position = nil
        RestorePosition()
    else
        local found = false
        for _, buff in ipairs(buffs) do
            if command == buff.key then
                BuffedDB.enabled[buff.key] = not BuffedDB.enabled[buff.key]
                Print(buff.name .. ": " .. (BuffedDB.enabled[buff.key] and "on" or "off"))
                found = true
                break
            end
        end
        if not found then Print("Unknown command. Use /buffed help.") end
    end
    Refresh()
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UNIT_AURA")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_UNGHOST")
events:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    if not initialized then Initialize() else Refresh() end
end)
