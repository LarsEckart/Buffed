local _, addon = ...

-- Buffed.lua only calls these checks out of combat.
function addon.FishingNeeded()
    -- User verified false without a lure, true with one (enchant ID 265).
    -- Any temporary main-hand enchant suppresses this reminder.
    if not GetInventoryItemID or not GetWeaponEnchantInfo then return nil end
    if GetInventoryItemID("player", 16) ~= 6256 then return false end
    local enchanted = GetWeaponEnchantInfo()
    if enchanted == nil then return nil end
    return not enchanted
end

-- Any existing temporary enchant is left untouched, regardless of its ID.
function addon.PoisonNeeded()
    if not GetWeaponEnchantInfo or not GetInventoryItemID then
        return nil, "weapon enchant API unavailable"
    end
    local mh, _, _, mid, oh, _, _, oid = GetWeaponEnchantInfo()
    local needed, states = nil, {}
    for _, hand in ipairs({ {16, mh, mid}, {17, oh, oid} }) do
        local slot, enchanted, id = hand[1], hand[2], hand[3]
        local state
        if not GetInventoryItemID("player", slot) then
            state = "empty"
        elseif enchanted == false then
            needed = needed or slot
            state = "missing"
        elseif enchanted == true then
            state = "enchanted" .. (id and " (ID " .. id .. ")" or "")
        else
            state = "enchant state unknown"
        end
        states[#states + 1] = slot .. " " .. state
    end
    return needed, table.concat(states, "; ")
end

function addon.HydrocaneNeeded()
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
