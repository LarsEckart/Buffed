local _, class = UnitClass("player")
if class ~= "PRIEST" then return end

-- Names intentionally target the English client. Group prayers satisfy the
-- same requirement, but reminders cast the single-target spell on yourself.
local buffs = {
    { key = "fortitude", name = "Power Word: Fortitude", alternate = "Prayer of Fortitude" },
    { key = "fire", name = "Inner Fire" },
    { key = "shadowguard", name = "Shadowguard" },
    { key = "food", name = "Well Fed XP Boost", item = true, icon = "Interface\\Icons\\INV_Misc_Food_18" },
    { key = "intellect", name = "Intellect", item = true, alternate = "Arcane Intellect", other = "Arcane Brilliance" },
}

local events = CreateFrame("Frame")
local anchor, initialized
local moving = false
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

-- Highest priority first. IDs avoid depending on cached item-name data.
-- Food entries explicitly list +5% kill XP in Wowhead Forever's tooltip:
-- https://nether.wowhead.com/forever/tooltip/item/<id>
-- Prefer Roasted Boar Meat, then low-level foods; stat bonuses are irrelevant.
-- This is a verified allowlist, not an exhaustive list of Forever foods.
local consumables = {
    food = {
        { id = 2681, level = 1, name = "Roasted Boar Meat" },
        { id = 2680, level = 1, name = "Spiced Wolf Meat" },
        { id = 2682, level = 1, name = "Cooked Crab Claw" },
        { id = 5472, level = 1, name = "Kaldorei Spider Kabob" },
        { id = 5474, level = 1, name = "Roasted Kodo Meat" },
        { id = 5477, level = 1, name = "Strider Stew" },
        { id = 3663, level = 1, name = "Murloc Fin Soup" },
        { id = 6290, level = 1, name = "Brilliant Smallfish" },
        { id = 6888, level = 1, name = "Herb Baked Egg" },
        { id = 6890, level = 1, name = "Smoked Bear Meat" },
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
        { id = 3728, level = 25, name = "Tasty Lion Steak" },
        { id = 4457, level = 25, name = "Barbecued Buzzard Wing" },
        { id = 12215, level = 25, name = "Heavy Kodo Stew" },
        { id = 12216, level = 25, name = "Spiced Chili Crab" },
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
        { id = 13933, level = 45, name = "Lobster Stew" },
        { id = 13934, level = 45, name = "Mightfish Steak" },
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
    for _, item in ipairs(consumables[buff.key]) do
        if carried[item.id] and UnitLevel("player") >= item.level then return item end
    end
end

local function ItemTexture(id, fallback)
    local icon = C_Item and C_Item.GetItemIconByID or GetItemIcon
    return (icon and icon(id)) or fallback or "Interface\\Icons\\INV_Scroll_01"
end

local function HasBuff(active, buff)
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
    if not initialized or InCombatLockdown() then return end
    local active = ActiveBuffs()
    local visible = 0
    local suppressed = UnitIsDeadOrGhost("player") or IsMounted()
    for i, buff in ipairs(buffs) do
        local button = buttons[i]
        local item = buff.item and FindConsumable(buff)
        local available
        if buff.item then available = item ~= nil
        else available = Known(buff.name) end
        if buff.item then
            button:SetAttribute("item", item and ("item:" .. item.id) or nil)
            button.displayName = item and item.name or buff.name
        end
        local missing = BuffedDB.enabled[buff.key] and available and not HasBuff(active, buff)
        if missing and not suppressed and not (buff.key == "food" and moving) then
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
    if InCombatLockdown() then return end
    if type(BuffedDB) ~= "table" then BuffedDB = {} end
    if type(BuffedDB.enabled) ~= "table" then BuffedDB.enabled = {} end
    for _, buff in ipairs(buffs) do
        if BuffedDB.enabled[buff.key] == nil then
            BuffedDB.enabled[buff.key] = true
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
        if buff.item then
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
            if buff.key == "food" then
                GameTooltip:AddLine("Click to eat. Remain seated for at least 10 seconds for +5% kill XP.", 1, 1, 1)
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
        Print("Toggle a reminder: /buffed fortitude | fire | shadowguard | food | intellect")
        return
    end
    if command == "status" then
        local active = ActiveBuffs()
        Print("Combat: " .. tostring(InCombatLockdown()) .. ", mounted: " .. tostring(IsMounted())
            .. ", dead/ghost: " .. tostring(UnitIsDeadOrGhost("player")) .. ", moving: " .. tostring(moving))
        for _, buff in ipairs(buffs) do
            Print(buff.name .. ": " .. (BuffedDB.enabled[buff.key] and "on" or "off")
                .. (buff.item and (FindConsumable(buff) and ", usable item in bags" or ", no supported usable item")
                    or (Known(buff.name) and ", learned" or ", not learned"))
                .. (HasBuff(active, buff) and ", active" or ", missing"))
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
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_UNGHOST")
events:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
events:RegisterEvent("PLAYER_STARTED_MOVING")
events:RegisterEvent("PLAYER_STOPPED_MOVING")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    -- Track transitions even in combat, without touching secure frames there.
    -- Events are authoritative: speed can still reflect the previous state
    -- during the movement callback. Sample it only on login/world entry.
    if event == "PLAYER_STARTED_MOVING" then moving = true
    elseif event == "PLAYER_STOPPED_MOVING" then moving = false
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        moving = GetUnitSpeed("player") > 0
    end
    if not initialized then Initialize() else Refresh() end
end)
