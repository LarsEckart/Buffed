local _, addon = ...

-- IDs avoid depending on cached item-name data. List order breaks equal-level ties.
-- Food entries explicitly list +5% kill XP in Wowhead Forever's tooltip:
-- https://nether.wowhead.com/forever/tooltip/item/<id>
-- Prefer the highest usable required character level; stat bonuses are not ranked.
-- This is a verified allowlist, not an exhaustive list of Forever foods.
addon.consumables = {
    -- Verified individually: https://nether.wowhead.com/forever/tooltip/item/{ID}
    -- Ownership only; fishing skill is not checked. Informational, not clickable.
    fishing = {
        { id = 6532, level = 1, name = "Bright Baubles" },
        { id = 6529, level = 1, name = "Shiny Bauble" },
        { id = 6530, level = 1, name = "Nightcrawlers" },
        { id = 6533, level = 1, name = "Aquadynamic Fish Attractor" },
        { id = 6811, level = 1, name = "Aquadynamic Fish Lens" },
        { id = 7307, level = 1, name = "Flesh Eating Worm" },
    },
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
