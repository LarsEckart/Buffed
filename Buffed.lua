local _, class = UnitClass("player")

-- Aura IDs verified at https://nether.wowhead.com/forever/tooltip/spell/{ID}
-- (each listed rank checked; verification details in AGENTS.md).
-- English names remain for spellbook/casting and aura APIs without spell IDs.
-- Group prayers satisfy the requirement; buttons cast single-target spells.
local buffs = {
    -- Umbrella aura only; individual camp benefits are not checked.
    -- https://nether.wowhead.com/forever/tooltip/spell/1229741
    { key = "camp", name = "Camp Benefits", auraIDs = { 1229741 }, reminderOnly = true,
        icon = "Interface\\Icons\\inv_camelot_camping_campbenefits" },
    { key = "mark", name = "Mark of the Wild", alternate = "Gift of the Wild",
        auraIDs = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 } },
    { key = "thorns", name = "Thorns", auraIDs = { 467, 782, 1075, 8914, 9756, 9910 } },
    -- Each rank verified at the Forever spell endpoint; cooldown fields tested in-client.
    { key = "grasp", name = "Nature's Grasp", cooldown = true,
        auraIDs = { 16689, 16810, 16811, 16812, 16813, 17329 } },
    -- https://nether.wowhead.com/forever/tooltip/spell/1259686
    -- Racial availability is gated by the learned spell, not a race token.
    -- No resulting aura ID is exposed; this reminder checks cooldown only.
    { key = "skysight", name = "Skysight", cooldown = true, racial = true,
        auraIDs = {}, icon = "Interface\\Icons\\ability_skyreach_lens_flare" },
    { key = "fortitude", name = "Power Word: Fortitude", alternate = "Prayer of Fortitude",
        auraIDs = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
    { key = "spirit", name = "Divine Spirit", alternate = "Prayer of Spirit",
        auraIDs = { 14752, 14818, 14819, 27841, 27681 } },
    { key = "fire", name = "Inner Fire", auraIDs = { 588, 7128, 602, 1006, 10951, 10952 } },
    { key = "shadowguard", name = "Shadowguard", auraIDs = { 18137, 19308, 19309, 19310, 19311, 19312 } },
    -- Each Well Fed ID's Forever buffspells explicitly includes +5% kill XP.
    -- Sources: https://nether.wowhead.com/forever/tooltip/spell/{ID}
    -- Full supported-food audit and mapping limitations: AGENTS.md.
    { key = "food", name = "Well Fed XP Boost",
        auraIDs = { 1243969, 1248406, 1248420, 1248421, 1248422, 1248688,
            1249519, 1249520, 1249521, 1249523 },
        item = true, icon = "Interface\\Icons\\INV_Misc_Food_18" },
    -- Client-observed; verified: https://nether.wowhead.com/forever/tooltip/spell/429959
    { key = "sleepingbag", name = "Well-Rested", auraIDs = { 429959 },
        item = true, icon = "Interface\\Icons\\INV_Misc_Bag_BigBagofEnchantments" },
    -- Informational only: no automatic equipment changes or click action.
    -- https://nether.wowhead.com/forever/tooltip/item/9452
    { key = "hydrocane", name = "Hydrocane", gear = true, reminderOnly = true,
        icon = "Interface\\Icons\\INV_Staff_15" },
    { key = "intellect", name = "Intellect", item = true, alternate = "Arcane Intellect", other = "Arcane Brilliance",
        auraIDs = { 8096, 8097, 8098, 12176, 1459, 1460, 1461, 10156, 10157, 23028 } },
}

-- Items, informational reminders and learned racials are shared across classes.
local spellClasses = {
    mark = "DRUID", thorns = "DRUID", grasp = "DRUID",
    fortitude = "PRIEST", spirit = "PRIEST", fire = "PRIEST", shadowguard = "PRIEST",
}
local classBuffs = {}
for _, buff in ipairs(buffs) do
    if buff.item or buff.reminderOnly or buff.racial or spellClasses[buff.key] == class then
        classBuffs[#classBuffs + 1] = buff
    end
end
buffs = classBuffs

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
local cachedHydrocaneNeeded
local CreateStatusWindow

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
    for i = 1, 255 do
        local name, spellID
        if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
            local aura = C_UnitAuras.GetBuffDataByIndex("player", i)
            name = aura and aura.name
            spellID = aura and aura.spellId
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
    return active, details
end

-- IDs avoid depending on cached item-name data. List order breaks equal-level ties.
-- Food entries explicitly list +5% kill XP in Wowhead Forever's tooltip:
-- https://nether.wowhead.com/forever/tooltip/item/<id>
-- Prefer the highest usable required character level; stat bonuses are not ranked.
-- This is a verified allowlist, not an exhaustive list of Forever foods.
local consumables = {
    -- Required character level, not the linked effect's spell level.
    -- https://nether.wowhead.com/forever/tooltip/item/9452
    hydrocane = { { id = 9452, level = 27, name = "Hydrocane" } },
    -- No character-level requirement listed (item level 40 is not a use level).
    -- https://nether.wowhead.com/forever/tooltip/item/211527
    -- https://nether.wowhead.com/forever/tooltip/spell/429961
    sleepingbag = {
        { id = 211527, level = 1, name = "Cozy Sleeping Bag" },
    },
    food = {
        { id = 2681, level = 1, name = "Roasted Boar Meat" },
        { id = 2680, level = 1, name = "Spiced Wolf Meat" },
        { id = 2682, level = 1, name = "Cooked Crab Claw" },
        { id = 5472, level = 1, name = "Kaldorei Spider Kabob" },
        { id = 5474, level = 1, name = "Roasted Kodo Meat" },
        { id = 5477, level = 1, name = "Strider Stew" },
        { id = 3663, level = 1, name = "Murloc Fin Soup" },
        { id = 6290, level = 1, name = "Brilliant Smallfish" },
        -- https://nether.wowhead.com/forever/tooltip/item/787
        { id = 787, level = 1, name = "Slitherskin Mackerel" },
        { id = 6888, level = 1, name = "Herb Baked Egg" },
        { id = 6890, level = 1, name = "Smoked Bear Meat" },
        -- https://nether.wowhead.com/forever/tooltip/item/249865
        { id = 249865, level = 1, name = "Peace Tea" },
        { id = 733, level = 5, name = "Westfall Stew" },
        { id = 2683, level = 5, name = "Crab Cake" },
        { id = 2684, level = 5, name = "Coyote Steak" },
        { id = 2687, level = 5, name = "Dry Pork Ribs" },
        { id = 3220, level = 5, name = "Blood Sausage" },
        { id = 3662, level = 5, name = "Crocolisk Steak" },
        { id = 3726, level = 5, name = "Big Bear Steak" },
        { id = 4592, level = 5, name = "Longjaw Mud Snapper" },
        { id = 5095, level = 5, name = "Rainbow Fin Albacore" },
        { id = 5476, level = 5, name = "Fillet of Frenzy" },
        { id = 6316, level = 5, name = "Loch Frenzy Delight" },
        { id = 12213, level = 5, name = "Carrion Surprise" },
        -- https://nether.wowhead.com/forever/tooltip/item/250077
        { id = 250077, level = 5, name = "Twice-Spiced Raptor Slice" },
        -- https://nether.wowhead.com/forever/tooltip/item/249866
        { id = 249866, level = 5, name = "Royal Tea" },
        { id = 21072, level = 10, name = "Smoked Sagefish" },
        { id = 1017, level = 15, name = "Seasoned Wolf Kabob" },
        { id = 2685, level = 15, name = "Succulent Pork Ribs" },
        { id = 3664, level = 15, name = "Crocolisk Gumbo" },
        { id = 3665, level = 15, name = "Curiously Tasty Omelet" },
        { id = 3666, level = 15, name = "Gooey Spider Cake" },
        { id = 3727, level = 15, name = "Hot Lion Chops" },
        { id = 3729, level = 15, name = "Soothing Turtle Bisque" },
        { id = 12209, level = 15, name = "Lean Wolf Steak" },
        { id = 12210, level = 15, name = "Roast Raptor" },
        { id = 12214, level = 15, name = "Mystery Stew" },
        -- https://nether.wowhead.com/forever/tooltip/item/249867
        { id = 249867, level = 15, name = "Root Tea" },
        { id = 3728, level = 25, name = "Tasty Lion Steak" },
        { id = 4457, level = 25, name = "Barbecued Buzzard Wing" },
        { id = 12215, level = 25, name = "Heavy Kodo Stew" },
        { id = 12216, level = 25, name = "Spiced Chili Crab" },
        -- https://nether.wowhead.com/forever/tooltip/item/8364
        { id = 8364, level = 25, name = "Mithril Head Trout" },
        -- https://nether.wowhead.com/forever/tooltip/item/274971
        { id = 274971, level = 25, name = "Briny Seafood Stew" },
        -- https://nether.wowhead.com/forever/tooltip/item/249868
        { id = 249868, level = 25, name = "Triage Tea" },
        -- https://nether.wowhead.com/forever/tooltip/item/21217
        { id = 21217, level = 30, name = "Sagefish Delight" },
        { id = 6887, level = 35, name = "Spotted Yellowtail" },
        { id = 12212, level = 35, name = "Jungle Stew" },
        { id = 12218, level = 35, name = "Monster Omelet" },
        { id = 13927, level = 35, name = "Cooked Glossy Mightfish" },
        { id = 13928, level = 35, name = "Grilled Squid" },
        { id = 13929, level = 35, name = "Hot Smoked Bass" },
        { id = 13930, level = 35, name = "Filet of Redgill" },
        { id = 13931, level = 35, name = "Nightfin Soup" },
        { id = 13932, level = 35, name = "Poached Sunscale Salmon" },
        { id = 18045, level = 35, name = "Tender Wolf Steak" },
        -- XP-bearing drink; same XP reminder and secure item-use path.
        -- https://nether.wowhead.com/forever/tooltip/item/249869
        { id = 249869, level = 35, name = "Sunny Tea" },
        { id = 13933, level = 45, name = "Lobster Stew" },
        { id = 13934, level = 45, name = "Mightfish Steak" },
        -- https://nether.wowhead.com/forever/tooltip/item/13935
        { id = 13935, level = 45, name = "Baked Salmon" },
        -- https://nether.wowhead.com/forever/tooltip/item/249870
        { id = 249870, level = 45, name = "Sage's Tea" },
    },
    -- Required character levels (not item levels), verified on Wowhead Forever:
    -- https://www.wowhead.com/forever/item=955
    -- https://www.wowhead.com/forever/item=2290
    -- https://www.wowhead.com/forever/item=4419
    -- https://www.wowhead.com/forever/item=10308
    intellect = {
        { id = 10308, level = 50, name = "Scroll of Intellect IV" },
        { id = 4419, level = 35, name = "Scroll of Intellect III" },
        { id = 2290, level = 20, name = "Scroll of Intellect II" },
        { id = 955, level = 5, name = "Scroll of Intellect" },
    },
}

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

local function HydrocaneNeeded()
    -- User verified BREATH while underwater, UNKNOWN after the bar disappears.
    -- IsSubmerged/IsSwimming both stayed true at the surface in this client.
    -- Only called out of combat; no timer values or aura data are inspected.
    if not GetMirrorTimerInfo or not GetInventoryItemID then return false end
    if GetInventoryItemID("player", 16) == 9452 then return false end
    for index = 1, 3 do
        local timer = GetMirrorTimerInfo(index)
        if timer == "BREATH" then return true end
    end
    return false
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

local function HasBuff(active, buff)
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
    if UnitIsDeadOrGhost("player") or IsMounted() then
        for _, button in ipairs(buttons) do button:Hide() end
        anchor.label:SetShown(BuffedDB.unlocked)
        anchor:EnableMouse(BuffedDB.unlocked)
        return
    end
    local active = ActiveBuffs()
    cachedHydrocaneNeeded = HydrocaneNeeded()
    -- User verified IsInInstance() returns true, "party" inside a Forever dungeon.
    local inInstance, instanceType = IsInInstance()
    local inDungeon = inInstance and instanceType == "party"
    local visible = 0
    for i, buff in ipairs(buffs) do
        local button = buttons[i]
        local item = (buff.item or buff.gear) and FindConsumable(buff)
        local available
        if buff.item or buff.gear then available = item ~= nil
        elseif buff.reminderOnly then available = true
        else available = not not Known(buff.name) end
        availability[buff.key] = available
        if buff.item then
            button:SetAttribute("item", item and ("item:" .. item.id) or nil)
            button.displayName = item and item.name or buff.name
        end
        local needed
        if buff.gear then needed = cachedHydrocaneNeeded
        elseif buff.racial then needed = true -- cooldown-ready reminder, no aura mapping assumed
        else needed = not HasBuff(active, buff) end
        local ready = not buff.cooldown or CooldownReady(buff, available)
        local missing = BuffedDB.enabled[buff.key] and available and needed and ready
        local dungeonSuppressed = inDungeon and (buff.key == "camp" or buff.key == "sleepingbag")
        if missing and not dungeonSuppressed and not (buff.key == "food" and moving) then
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", visible * 42, -4)
            button.icon:SetTexture(item and ItemTexture(item.id, buff.icon) or buff.icon or SpellTexture(buff.name) or 136243)
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
    if type(BuffedDB.enabled) ~= "table" then BuffedDB.enabled = {} end
    for _, buff in ipairs(buffs) do
        if BuffedDB.enabled[buff.key] == nil then
            BuffedDB.enabled[buff.key] = true
        end
    end

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
            if buff.gear then
                GameTooltip:AddLine("Breath timer active. Equip Hydrocane for 50% longer underwater breath. This icon is not clickable.", 1, 1, 1)
            elseif buff.reminderOnly then
                GameTooltip:AddLine("Camp Benefits missing. Visit a camp to refresh it. This icon is not clickable.", 1, 1, 1)
            elseif buff.key == "food" then
                GameTooltip:AddLine("Click to eat. Remain seated for at least 10 seconds for +5% kill XP.", 1, 1, 1)
            elseif buff.key == "sleepingbag" then
                GameTooltip:AddLine("Click to unroll. Rest inside for at least one minute to gain Well-Rested.", 1, 1, 1)
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
        local keys = {}
        for _, buff in ipairs(buffs) do keys[#keys + 1] = buff.key end
        Print("Toggle a reminder: /buffed " .. table.concat(keys, " | "))
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
            AddLine("Breath/equipment state below is also cached, not live.")
            if not hasAuraSnapshot then AddLine("No out-of-combat aura snapshot available.") end
        end
        if not CombatLocked() then cachedHydrocaneNeeded = HydrocaneNeeded() end
        for _, buff in ipairs(buffs) do
            local available = availability[buff.key]
            if not CombatLocked() then
                if buff.item or buff.gear then available = FindConsumable(buff) ~= nil
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
            AddLine(buff.name .. ": " .. (BuffedDB.enabled[buff.key] and "on" or "off")
                .. (available == nil and ", availability/learned state unknown"
                    or ((buff.item or buff.gear) and (available and ", usable item in bags" or ", no supported usable item")
                        or buff.reminderOnly and ", reminder only"
                        or (available and ", learned" or ", not learned")))
                .. (buff.gear and (cachedHydrocaneNeeded == nil and ", breath/equipment state unknown"
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
    if CombatLocked() then
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
    if (event == "MIRROR_TIMER_START" or event == "MIRROR_TIMER_STOP") and not CombatLocked() then
        -- Timer events can precede GetMirrorTimerInfo's updated state. Recheck
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
