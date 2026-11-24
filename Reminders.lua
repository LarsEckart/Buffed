local _, addon = ...

-- Aura IDs verified at https://nether.wowhead.com/forever/tooltip/spell/{ID}
-- (each listed rank checked; verification details in AGENTS.md).
-- English names remain for spellbook/casting and aura APIs without spell IDs.
-- Group prayers satisfy the requirement; buttons cast single-target spells.
-- Entries without a class are shared; activated spells still have to be learned.
addon.reminders = {
    -- Umbrella aura only; individual camp benefits are not checked.
    -- https://nether.wowhead.com/forever/tooltip/spell/1229741
    { key = "camp", name = "Camp Benefits", auraIDs = { 1229741 }, reminderOnly = true,
        icon = "Interface\\Icons\\inv_camelot_camping_campbenefits" },
    { key = "mark", class = "DRUID", name = "Mark of the Wild", alternate = "Gift of the Wild",
        auraIDs = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 21849, 21850 } },
    { key = "thorns", class = "DRUID", name = "Thorns", auraIDs = { 467, 782, 1075, 8914, 9756, 9910 } },
    -- Each rank verified at the Forever spell endpoint; cooldown fields tested in-client.
    { key = "grasp", class = "DRUID", name = "Nature's Grasp", cooldown = true,
        auraIDs = { 16689, 16810, 16811, 16812, 16813, 17329 } },
    -- https://nether.wowhead.com/forever/tooltip/spell/1259686
    -- Racial availability is gated by the learned spell, not a race token.
    -- No resulting aura ID is exposed; this reminder checks cooldown only.
    { key = "skysight", name = "Skysight", cooldown = true, racial = true,
        auraIDs = {}, icon = "Interface\\Icons\\ability_skyreach_lens_flare" },
    { key = "poison", class = "ROGUE", name = "Weapon Poison", poison = true, item = true,
        icon = "Interface\\Icons\\ability_rogue_dualweild" },
    { key = "fortitude", class = "PRIEST", name = "Power Word: Fortitude", alternate = "Prayer of Fortitude",
        auraIDs = { 1243, 1244, 1245, 2791, 10937, 10938, 21562, 21564 } },
    { key = "spirit", class = "PRIEST", name = "Divine Spirit", alternate = "Prayer of Spirit",
        auraIDs = { 14752, 14818, 14819, 27841, 27681 } },
    { key = "fire", class = "PRIEST", name = "Inner Fire", auraIDs = { 588, 7128, 602, 1006, 10951, 10952 } },
    { key = "shadowguard", class = "PRIEST", name = "Shadowguard", auraIDs = { 18137, 19308, 19309, 19310, 19311, 19312 } },
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
    { key = "fishing", name = "Fishing lure", supplies = true, reminderOnly = true,
        icon = "Interface\\Icons\\INV_Misc_Gem_Variety_02" },
    { key = "intellect", name = "Intellect", item = true, alternate = "Arcane Intellect", other = "Arcane Brilliance",
        auraIDs = { 8096, 8097, 8098, 12176, 1459, 1460, 1461, 10156, 10157, 23028 } },
}
