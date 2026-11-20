# Developer instructions

## Local patches to neighboring addons

These are user-requested local fixes outside Buffed. Addon updates can overwrite
them; inspect the updated code before reapplying. Do not automatically modify
neighboring addons as part of ordinary Buffed work.

### ForeverRecipes: protected tooltip text

- File: `../ForeverRecipes/ItemTooltip.lua`, function `HasEstimateLines`.
- Error: comparing local `text` (a secret string) at the original line 107 when
  hovering bag items or loot-roll items.
- Fix: replace the entire tooltip-text scan with the existing addon-owned marker:

  ```lua
  local function HasEstimateLines(tooltip)
      -- Do not read/compare Blizzard tooltip text: it may contain secret values.
      return appendedItems[tooltip] ~= nil
  end
  ```

- Retain `WatchTooltip`'s `OnTooltipCleared` reset and `AppendValues`'s assignment
  of `appendedItems[tooltip]` when rows are added. These prevent duplicate rows
  without inspecting protected text.
- Installed version 1.15.1 had the same affected file as the pre-patch backup;
  installing it overwrote the first fix. The error recurred and the fix was
  reapplied. CurseForge comments could not be checked due to a browser challenge.
- Mock tests passed for no tooltip-text scanning, duplicate suppression,
  clear/reset, and unavailable-then-available prices. Actual client behavior
  after reapplying still needs confirmation: `/reload`, hover bag and loot-roll
  items, and check for errors and duplicate estimate rows.

### WhereYouAt: protected group-leader location

- File: `../WhereYouAt/WhereYouAt.lua`, function `UpdateAreaName`.
- Error: comparing local `areaName` (a secret string) at the original line 22
  during `LFGBrowseSearchEntry_Update`.
- Fix: remove this entire conditional, including its `return`:

  ```lua
  if not areaName or areaName == "" then
      return
  end
  ```

  Keep the existing direct display calls:

  ```lua
  areaLabel:SetText(areaName)
  areaLabel:Show()
  ```

- Do not test, compare, concatenate, or format the location value. This patch
  passes it directly to the label rather than attempting to access its contents.
  Missing/empty text leaves a blank label.
- Mock tests passed for ordinary, empty, and missing locations. They cannot
  simulate client secret-value restrictions. Direct display of a protected
  location in Forever remains unverified: `/reload`, reopen the group finder,
  and request any new error before attempting further changes.

Pre-patch backups and temporary mock tests were saved under
`C:/Users/katri/AppData/Local/Temp/` (not durable repository fixtures):
`ForeverRecipes-ItemTooltip.before-secret-fix.lua`,
`forever-recipes-tooltip-test.lua`, `WhereYouAt.before-secret-fix.lua`, and
`whereyouat-secret-test.lua`. No neighboring-addon changes were committed or
pushed.

## Target WoW Forever, not Classic

This addon targets **World of Warcraft Forever**, English locale, interface
`16001`. Forever has just released. Treat training knowledge about WoW Classic,
Retail, and other versions as unverified and potentially incorrect here.

**Look up all item, spell, buff, recipe, talent, and related gameplay information
in Wowhead's Forever database before implementing or changing it.** Do not infer
Forever behavior from Classic names or IDs. An unchanged ID does not guarantee
unchanged effects, required levels, or interactions.

For example, Forever's Roasted Boar Meat grants a stat bonus and +5% experience
from kills. Some foods granting Well Fed do not grant the XP bonus. Verify the
specific effect; do not equate all Well Fed buffs with Well Fed XP Boost.

## How to look up Forever data

### Human-readable pages

Use the `/forever/` namespace explicitly:

- Item: `https://www.wowhead.com/forever/item=2681/roasted-boar-meat`
- Spell/recipe: `https://www.wowhead.com/forever/spell=2540/roasted-boar-meat`

The numeric ID is sufficient; the name slug is optional. Check the resulting
item as well as its crafting recipe: a recipe spell ID is not an item ID.

### Tooltip JSON endpoints

Normal Wowhead pages may return HTTP 403 to command-line tools. The following
Forever-specific tooltip endpoints have worked for this project:

```bash
curl -fL --max-time 20 -s 'https://nether.wowhead.com/forever/tooltip/item/2681'
curl -fL --max-time 20 -s 'https://nether.wowhead.com/forever/tooltip/spell/2540'
curl -fL --max-time 20 -s 'https://nether.wowhead.com/forever/tooltip/spell/1243969'
```

Responses are JSON, with HTML inside fields such as `tooltip` and `buff`.
Inspect `name`, `icon`, the use effect, required level, duration, and linked
spells/items. Follow those links to verify the actual buff or crafted result.
Fields vary by endpoint; an empty `spells` field does not mean the item has no
use effect. Read the tooltip HTML too.

An alternative endpoint verified here is:

```text
https://nether.wowhead.com/tooltip/item/2681?dataEnv=16&locale=0
```

Prefer the explicit `/forever/` endpoint. If using the alternative, confirm
links in the returned tooltip point to `/forever/`, not another game version.
Do not silently fall back to Classic or Retail when a request fails.

### Verification checklist

Before encoding an entry, verify:

1. Correct Forever item/spell ID and English name.
2. **Required character level**, not item level or cooking skill requirement.
3. Actual effect, buff name, duration, and any required eating/channel time.
4. For XP foods, explicit tooltip text stating experience gained from kills
   is increased by 5%; Well Fed alone is insufficient evidence.
5. Any ranks, alternative buffs, or interactions relied on by the code. Do not
   assume stacking or replacement rules merely because they applied in Classic.

Keep source URLs near encoded data or in project documentation. State which
facts were verified and which remain uncertain. If Wowhead data is inaccessible
or ambiguous, ask for an in-game tooltip/API result instead of guessing.

## Scope and implementation

- Build incrementally: only add features the user asks for. Do not preemptively
  add other classes, priest spells, consumables, or configuration systems.
- English only for now; no external libraries required.
- The food allowlist contains verified XP foods, not all food or all Well Fed
  items. Selection currently ignores stat bonuses.
- Use event-driven updates, not continuous polling.
- Never modify secure buttons or their layout in combat. Refresh after combat;
  the secure visibility state driver hides the bar during combat.
- Gameplay database lookups do not prove client API compatibility. Test
  Forever's actual APIs in-game; do not assume Classic/Retail API behavior.

## Client API verification workflow

- Reuse previously verified API paths for equivalent features. Adding another
  ordinary learned-spell/missing-aura reminder does not require repeating the
  same API probes. Verify its Forever gameplay data separately as usual.
- Ask for a small in-game probe when a feature introduces an unverified API or
  behavior, not for every new spell. Check these notes and existing code first.
- Make the first probe precise: print labelled fields needed by the code rather
  than dumping an entire table with unclear field/value ordering. Specify the
  conditions to test (for example, out of combat, ready and just after casting).
  Batch the necessary labelled fields into one command to avoid extra rounds.
- Cooldown precedent: the user verified
  `C_Spell.GetSpellCooldown("Nature's Grasp")` out of combat returns a table
  with `startTime`, `duration`, and `isEnabled`. Ready was 0/0/true; after
  casting it was 1949.686/60/true. Reuse this established path for equivalent
  out-of-combat reminders; do not ask to rediscover the table shape.
- This evidence does not establish in-combat access, every spell's behavior,
  cooldown rate modifiers, charges, global-cooldown handling, or event delivery
  at expiry. Test newly relevant behavior specifically rather than repeating
  already answered questions. SPELL_UPDATE_COOLDOWN expiry delivery still needs
  in-game validation for Nature's Grasp.

## Combat API limits and feasibility checks

**Check feasibility before implementing a feature, and push back explicitly when
it depends on restricted APIs.** Explain the restriction and offer supported
alternatives rather than promising a feature and repeatedly trying speculative
workarounds. If feasibility is unknown, say so and request a small in-game API
test before building the feature. Do not claim that every buff is inaccessible
just because a full aura scan failed.

### Confirmed in this Forever client

- In-combat aura enumeration through `C_UnitAuras.GetBuffDataByIndex` triggered
  a client error reporting that secret auras cannot be accessed while tainted
  by Buffed. It broke both the attempted Shadowguard combat reminder and
  `/buffed status`; a movement event also triggered the failing refresh path.
- Buffed therefore does not call aura-reading APIs or inspect `UNIT_AURA`
  payloads during combat. It refreshes live data after combat instead.
- `/buffed status` works during combat using cached out-of-combat aura states,
  names/IDs, learned spells, and item availability. The user confirmed the
  window opens with this implementation. These values must be labelled cached,
  not live, and must not drive claims about current combat buff state.
- Secure casting buttons, their attributes, visibility, and layout must not be
  changed by addon Lua in combat. The bar uses a preconfigured secure visibility
  state driver. A non-clickable indicator does not solve restricted aura access.
- Catching an error with `pcall` does not grant API access. Do not attempt to
  bypass secret-value or taint restrictions, reconstruct hidden state, or treat
  a spell ID instead of a name as a way around these restrictions.

### Still unverified

- The failed full scan does **not** establish that Shadowguard itself, or every
  other individual aura, is secret. A targeted lookup for a non-secret aura may
  be possible, but its API availability and behavior must be verified in Forever
  before proposing it as a working solution. There is currently no verified
  live "show Shadowguard only when missing" combat implementation here.
- Always-visible, preconfigured combat buttons are a possible alternative to
  discuss with the user, not permission to add them without being asked. They
  must not depend on reading restricted aura state.

Blizzard's generated aura API documentation marks `GetBuffDataByIndex` with
`RequiresUnitAuraAccess` and `SecretWhenUnitAuraRestricted`:
https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua
This is a community mirror of current Retail-generated documentation, **not**
Forever-specific compatibility evidence. Use it as context; the actual Forever
client error and in-game tests determine what this addon can safely do.

## Implementation and data notes

Keep `README.md` concise and end-user focused. Developer details, API caveats,
data sources, and test procedures belong here or beside the relevant code.

- Original implementation inspired by BuffCheck; no external libraries required.
- Aura detection prefers the verified IDs below. English-name fallback is used
  only when the aura API returns no spell ID. An unknown ID does not count just
  because its name matches. English names remain necessary for learned-spell
  detection, spell textures, and secure casting; this is not localization support.
- XP detection recognizes spell ID `1243969` and the nine individually verified
  Well Fed IDs in the audit below (or Well Fed XP Boost by name if no ID exists).
  Each one's Forever `buffspells` explicitly confirms +5% kill XP. Only
  `1248422` and `1249519` have been observed in the user's client so far.
  Do not generalize to unverified Well Fed IDs. Sources:
  https://nether.wowhead.com/forever/tooltip/spell/1243969
  https://nether.wowhead.com/forever/tooltip/spell/1248422
  https://nether.wowhead.com/forever/tooltip/spell/1249519
  https://nether.wowhead.com/forever/tooltip/item/6290
  Smallfish's item tooltip confirms +5% kill XP after 10 seconds eating and
  2 Attack Power for 15 minutes, without a character-level requirement.
  The observed aura 1249519 lists 1 Attack Power and 15 minutes; its
  `buffspells` explicitly includes 1243969's +5% kill XP. The stat discrepancy
  is not resolved or relied on by selection/detection.
- A user report showed aura access failing on `PLAYER_REGEN_DISABLED` despite
  the lockdown guard. Combat entry now latches a conservative blocked state
  until `PLAYER_REGEN_ENABLED`, in addition to checking `InCombatLockdown()`.
  Mock tests cover the entry event while lockdown still returns false; actual
  event/flag timing remains unverified. In-game, enter combat and move/use
  status, then leave combat: no aura error should occur and reminders refresh.
- The verified food allowlist is `consumables.food` in `Buffed.lua`; it is not
  exhaustive. Selection prefers the highest usable required character level,
  breaking equal-level ties by allowlist order, without ranking stat bonuses.
- Scroll of Intellect supports ranks I–IV (required levels 5/20/35/50), selecting
  the highest usable rank. Arcane Intellect/Brilliance also satisfy the reminder.
- Initialization occurs on world entry, not login or earlier bag/spell events;
  world entry in combat defers initialization until combat ends. Normal updates
  skip aura, spellbook, and bag scans while dead/ghost or mounted. Relevant
  events still hide icons and refresh them when those states end.
- The status copy window is pre-created out of combat. Combat diagnostics use
  only cached aura states/names/IDs, learned spells, and bag availability. If no
  aura snapshot exists, report that rather than claiming buffs are missing.
  Status includes the aura API used. Selected text can be copied with Ctrl+C;
  addons cannot write directly to the system clipboard.
- Event/command runtime errors are caught so a failed status command does not
  abort chat submission. The first pending error is printed after combat (or
  immediately out of combat), and retained in status until reload. Request the
  `Runtime error (please share)` message if combat diagnostics fail to open.
- Current scope excludes party/raid scanning, expiry warnings, general food
  detection, items beyond XP food, Intellect scrolls, and Cozy Sleeping Bag, a minimap button,
  and an options panel. Other classes do nothing.

### Shared reminders and class scope

- Item-based reminders (`food`, `intellect`, `sleepingbag`) and informational
  `camp` are available to every class. Item reminders still require a carried,
  usable allowlisted item; Camp Benefits has no item prerequisite.
- Only spell reminders are class-filtered: priests get `fortitude`, `spirit`,
  `fire`, `shadowguard`; druids get `mark`, `thorns`. This supersedes older
  priest/druid-only scope notes below. No new gameplay data or spell support added.
- Mock coverage checks all shared reminders with and without carried items and
  qualifying auras across nine class tokens, spell isolation, and shared toggles.
  Actual Forever validation pending: on a druid and another class, `/reload`,
  carry usable food/Intellect scroll/bag, check missing/present buffs and toggles,
  and confirm normal combat/mount/death and dungeon suppression.

### Camp Benefits reminder

- Available to priests and druids. Druid mock coverage includes default enablement,
  informational-only attributes, aura detection, toggle, and dungeon suppression.
  In-game druid validation pending: `/reload`, check missing/present Camp Benefits,
  `/buffed camp`, and dungeon entry/exit.

- `/buffed camp` toggles an informational-only reminder for the umbrella aura
  Camp Benefits (1229741), observed in the user's out-of-combat status report.
  It does not depend on carried items or learned spells and has no secure action.
- Verified name, icon, one-hour buff duration and bundled benefit descriptions:
  https://nether.wowhead.com/forever/tooltip/spell/1229741
  Individual benefits, scaling, acquisition and survival through death are not
  inferred from the umbrella aura. No individual-benefit checks are implemented.
- Uses the existing out-of-combat aura scan and combat-hidden parent. In-game:
  `/reload`, check that the icon hides with Camp Benefits and returns without it;
  clicking must do nothing. Verify `/buffed camp` and combat/mount/death hiding.

### Dungeon suppression

- User verified `/dump IsInInstance()` returns `true, "party"` inside a Forever
  dungeon. Refresh suppresses only Camp Benefits and Cozy Sleeping Bag for that
  result; no raid or other instance-type behavior is inferred.
- Existing `PLAYER_ENTERING_WORLD` refreshes on entry/exit; combat transitions
  defer scans and secure changes until combat ends. No polling is added.
- In-game: carry the bag with both buffs missing, enter/leave a dungeon, and
  confirm both reminders hide/return while other reminders remain unchanged.
  Repeat a transition in combat and verify the result after combat ends.

### Fishing lure reminder

- Shared, informational-only `/buffed fishing`: exact main-hand item 6256
  and GetWeaponEnchantInfo's first return false. Carried lures are optional:
  show the selected lure icon if carried, otherwise item 6256's fishing-pole
  icon (verified icon inv_fishingpole_02). Tooltip distinguishes both cases.
  No click action, skill check, automatic equipment swap, or combat reads.
  Any temporary main-hand enchant suppresses it; no enchant-ID mapping inferred.
- User verified out of combat: false/nil/nil/nil without a lure;
  true/598657/0/265 after applying one. Only the boolean is used; missing API
  or nil result fails closed. Combat status reports cached equipment/enchant state.
- Verified individually at https://nether.wowhead.com/forever/tooltip/item/{ID}:
  6256 Fishing Pole; 6529 Shiny Bauble (+25/10min), 6530 Nightcrawlers
  (+50/10min), 6532 Bright Baubles (+75/10min), 6533 Aquadynamic Fish
  Attractor (+100/5min), 6811 Aquadynamic Fish Lens (+50/10min),
  7307 Flesh Eating Worm (+75/10min). No character-level requirements listed.
  Fishing requirements: none listed/50/100/100/50/100 respectively for lures.
  Linked spells 8087/8088/8090/8089/8532/9092 individually verified at
  https://nether.wowhead.com/forever/tooltip/spell/{ID}; all five-second casts,
  no aura mappings exposed. Ownership only, not a claim of usability or ranking.
- Refresh uses existing events plus UNIT_INVENTORY_CHANGED. No polling added.
  User reported the reminder works in-game after implementation; individual
  expiry-without-movement and suppression cases were not separately reported.
  For further validation: equip 6256 with a lure in bags, apply it, let it expire without moving,
  swap to staff, remove lures, toggle /buffed fishing, and check suppression.
  Report /buffed status if stale; do not assume expiry emits an event.
- Mocks cover six lure IDs, optional ownership and pole-icon fallback, exact
  pole, enchant applied/removed with and without carried lures,
  toggle, no click action, and combat inventory/status scan and mutation guards.

### Hydrocane reminder

- Informational-only `hydrocane` reminder for all classes; no equip action,
  automatic swapping, previous-weapon tracking, or combat reminder.
- Verified Forever item 9452 (Hydrocane), icon INV_Staff_15, required character
  level 27, and equipped effect: underwater breath lasts 50% longer, not unlimited.
  Sources: https://nether.wowhead.com/forever/tooltip/item/9452 and
  https://nether.wowhead.com/forever/tooltip/spell/11789 (the effect's level 20
  is not the item's character-level requirement).
- User's out-of-combat tests: IsSubmerged and IsSwimming both returned true
  underwater and at the surface. GetMirrorTimerInfo(2) returned BREATH underwater
  and UNKNOWN with zero/empty fields after the breath bar disappeared at the
  surface. Check only timer type across slots 1–3, not numeric timer values.
  This indicates an active breath timer, not exact physical submersion: the
  reminder can persist while breath replenishes at the surface, and will not
  appear underwater without a breath timer.
- Requires a carried item and level 27+, active BREATH timer, and no Hydrocane
  in main-hand slot 16. Existing suppression and secure visibility rules apply.
  Refresh on MIRROR_TIMER_START/STOP, PLAYER_EQUIPMENT_CHANGED, and existing
  events; no polling or combat timer/equipment reads. A user reported the icon
  remaining after leaving water until movement stopped. Timer events now also
  schedule a one-shot next-frame refresh via a self-removing OnUpdate handler,
  to handle GetMirrorTimerInfo still returning the old state during the event.
  This event/API ordering is a suspected cause, not yet confirmed in-game.
  Mocks cover stale start/stop state and combat entry before the callback;
  verify leaving water while continuing to move hides the icon after the breath
  bar disappears. Status uses a cached
  breath/equipment condition in combat, explicitly labelled cached.
- Mock coverage: ownership, required level, all timer slots, non-breath timers,
  equipment changes, toggle, no secure action, mount/death suppression, and
  combat scan/mutation guards. Actual event delivery and inventory API behavior
  still need Forever validation: /reload with Hydrocane in bags, submerge until
  the breath bar appears, equip/unequip it, surface until the bar disappears,
  and check /buffed hydrocane plus combat transitions. The icon must not equip
  anything on click. Report /buffed status if it fails to refresh.

### Cozy Sleeping Bag reminder

- `sleepingbag` uses carried item 211527 (Cozy Sleeping Bag) and aura 429959
  (Well-Rested), observed by the user at one stack. Any stack hides the reminder;
  stack counts, cooldowns, and progress toward three stacks are not tracked.
- Verified Forever sources:
  https://nether.wowhead.com/forever/tooltip/item/211527
  https://nether.wowhead.com/forever/tooltip/spell/429961
  https://nether.wowhead.com/forever/tooltip/spell/429959
- Item tooltip lists no character-level requirement (item level 40 is not a use
  requirement). Unroll Bag has a 15-second cast and one-hour cooldown; the tooltip
  says resting inside for at least one minute grants XP benefits, up to three
  stacks. Well-Rested lists +1% experience gains and a two-hour duration.
- Uses existing out-of-combat aura and secure item-button paths. Actual unrolling
  via this button still needs an in-game test. Carry the bag without Well-Rested,
  click to unroll, and rest until one stack appears: the icon should disappear.
  Remove Well-Rested to restore it; remove the bag to hide it. Check the
  `/buffed sleepingbag` toggle and confirm normal combat suppression.

### Druid Mark of the Wild reminder

- Druids currently get `mark`, `thorns` and the shared `food` and `camp` reminders.
  Priest reminders are unchanged; other classes still do nothing. This supersedes
  earlier priest-only scope statements. No other druid features added.
- Individually verified every ID at
  `https://nether.wowhead.com/forever/tooltip/spell/{ID}`:
  Mark of the Wild 1126/5232/6756/5234/8907/9884/9885 (levels
  1/10/20/30/40/50/60), Gift of the Wild 21849/21850 (levels 50/60).
  All list one-hour buffs. Mark grants armor, with attributes from level 10
  and resistances from level 30; Gift lists equivalent level-50/60 bonuses.
  No additional ranks or stacking behavior inferred.
- Uses existing learned-spell, self-cast, out-of-combat paths; Gift also satisfies
  the reminder. The button always casts Mark. XP food selection is unchanged.
- Mock coverage: learned/unlearned Mark, self-target attributes, all nine IDs,
  name fallback, unknown-ID rejection, toggle, food availability/XP detection,
  class isolation, cached combat diagnostics, mount/death suppression.
- Actual Forever druid casting/API behavior remains unverified. In-game:
  `/reload`, remove Mark, click with another unit targeted, confirm self-cast
  and icon disappearance. Check Gift, food from bags, toggles, combat/mount/death
  suppression. Share out-of-combat `/buffed status` if detection fails.

### Skyborne Skysight reminder

- `skysight` is a clickable, learned-spell and cooldown-ready reminder shared
  across classes. Learned Skysight gates availability rather than introducing
  an unverified race-token API. Existing combat/mount/death suppression applies;
  the user explicitly requested no reminder while mounted.
- Verified https://nether.wowhead.com/forever/tooltip/spell/1259686:
  Skysight, icon ability_skyreach_lens_flare, level 1, 0.5-second cast,
  two-minute cooldown, +15% movement and mounted movement speed for 30 seconds.
  Tooltip says a nearby elemental convergence grants Charged for one hour and
  increases the ability's effect by 100%; no convergence/Charged checks added.
  The endpoint exposes no resulting aura ID; no aura mapping is inferred.
- Reuses the verified out-of-combat C_Spell.GetSpellCooldown fields and secure
  self-cast path. SPELL_UPDATE_COOLDOWN is now registered for all classes.
  No combat reads or polling. Mock tests cover unlearned/learned, cooldown
  expiry, missing/disabled data, self-target attributes, toggle, mount/death,
  combat scan/mutation guards and class isolation.
- Actual Forever racial spellbook/casting behavior and cooldown expiry event
  delivery remain unverified. On a Skyborne character: /reload, check the ready
  icon, click with another unit targeted, and confirm hiding after casting and
  automatic return after two minutes without moving. Check /buffed skysight,
  mount/dismount and combat transitions; share /buffed status if it fails.

### Druid Nature's Grasp reminder

- Druid-only `grasp`: learned, missing aura, and off cooldown. Existing self-cast
  secure button and combat/mount/death suppression apply; no combat cooldown reads.
- Individually verified Forever spell endpoints
  `https://nether.wowhead.com/forever/tooltip/spell/{ID}` for
  16689/16810/16811/16812/16813/17329: Nature's Grasp, levels
  10/18/28/38/48/58, one-minute cooldown, 45-second buff, one melee hit roots
  the attacker, castable while shapeshifted. No other ranks inferred.
- User verified out-of-combat `C_Spell.GetSpellCooldown("Nature's Grasp")`:
  startTime=0, duration=0, isEnabled=true when ready; startTime=1949.686,
  duration=60, isEnabled=true after casting. Only these fields are used.
  Missing data fails closed. Status reports cooldown readiness cached in combat.
- Event-driven refresh on SPELL_UPDATE_COOLDOWN (druids only); no polling.
  Actual Forever event delivery at cooldown expiry remains unverified.
- Mock coverage includes learning, cooldown/expiry/disabled/unavailable states,
  all six aura IDs, name fallback, unknown-ID rejection, toggle, class isolation,
  and combat scan suppression. In-game: `/reload`, click with another target,
  confirm hiding after casting and automatic return at cooldown expiry without
  moving. Test `/buffed grasp`, mount/death/combat transitions, and share status
  if it fails.

### Druid Thorns reminder

- `thorns` uses the existing learned-spell, self-targeted secure cast and
  out-of-combat aura paths. No live combat aura checks or automatic casting.
- Individually verified Forever endpoints
  `https://nether.wowhead.com/forever/tooltip/spell/{ID}` for
  467/782/1075/8914/9756/9910: English name Thorns, required character levels
  6/14/24/34/44/54, ten-minute buff, and 3/6/9/12/15/18 Nature damage to
  attackers when hit. No other ranks or interactions inferred.
- Mock tests cover learned/unlearned availability, self-target attributes,
  all six aura IDs, name fallback, unknown-ID rejection, toggle, druid scope,
  combat scan suppression and mount/death hiding.
- In-game validation pending: `/reload`, remove Thorns, click its reminder
  with another unit targeted; confirm self-cast and disappearance. Check
  `/buffed thorns` and combat/mount/death suppression. If detection fails,
  share out-of-combat `/buffed status`.

### Divine Spirit reminder

- `spirit` uses the existing learned-spell, self-cast, out-of-combat reminder path.
  Divine Spirit and Prayer of Spirit both satisfy it; the button casts Divine Spirit.
- Individually verified Forever endpoints:
  https://nether.wowhead.com/forever/tooltip/spell/14752
  https://nether.wowhead.com/forever/tooltip/spell/14818
  https://nether.wowhead.com/forever/tooltip/spell/14819
  https://nether.wowhead.com/forever/tooltip/spell/27841
  https://nether.wowhead.com/forever/tooltip/spell/27681
  Divine Spirit ranks require levels 30/40/50/60 and grant 17/23/33/40 Spirit
  for one hour. Prayer of Spirit requires level 60 and grants 40 Spirit for
  one hour. No additional ranks or stacking rules are inferred.
- Mock coverage includes learning, self-target attributes, each verified aura ID,
  name fallback, unknown-ID rejection, and `/buffed spirit` toggling.
- In-game validation remains pending: `/reload`, remove Divine Spirit, click its
  reminder with another unit targeted, and confirm it buffs yourself and hides.
  Verify the toggle and normal combat/mount/death suppression. Share an
  out-of-combat `/buffed status` if the applied aura is not recognized.

### Verified aura IDs

Each ID below was individually checked using Wowhead's Forever tooltip endpoint
`https://nether.wowhead.com/forever/tooltip/spell/{ID}`. For example:
https://nether.wowhead.com/forever/tooltip/spell/1243
https://nether.wowhead.com/forever/tooltip/spell/12176

| Effect | Verified IDs |
| --- | --- |
| Power Word: Fortitude | 1243, 1244, 1245, 2791, 10937, 10938 |
| Prayer of Fortitude | 21562, 21564 |
| Divine Spirit / Prayer of Spirit | 14752, 14818, 14819, 27841, 27681 |
| Inner Fire | 588, 7128, 602, 1006, 10951, 10952 |
| Shadowguard | 18137, 19308, 19309, 19310, 19311, 19312 |
| Scroll Intellect | 8096, 8097, 8098, 12176 |
| Arcane Intellect | 1459, 1460, 1461, 10156, 10157 |
| Arcane Brilliance | 23028 |
| XP food | 1243969, 1248406, 1248420, 1248421, 1248422, 1248688, 1249519, 1249520, 1249521, 1249523 |

The spell tooltips confirm English names, buff text, effects, durations, and
required spell levels for the listed ranks. Fortitude/Prayer and mage Intellect
last 1 hour; Inner Fire lasts 10 minutes/20 charges; Shadowguard lasts 10
minutes/3 charges; scroll Intellect lasts 30 minutes. Shadowguard's cast and buff
tooltips disagree on damage amounts; no damage values are encoded or relied on.
The scroll spell-level fields differ from item-use requirements: the item
endpoints for 955/2290/4419/10308 link to 8096/8097/8098/12176 respectively and
confirm character use levels 5/20/35/50. Source example:
https://nether.wowhead.com/forever/tooltip/item/10308

These checks establish the listed database entries, not that no additional
Forever ranks/variants exist, nor which IDs the actual client returns. Unknown
IDs require an out-of-combat `/buffed status` report and verification before
adding them. No stacking/replacement rules were changed. Casting and learned
spell detection are deliberately unchanged pending separate API verification.

## Supported XP food audit

Verified 249865/249866/249867/249868/13933/249870 at
`https://nether.wowhead.com/forever/tooltip/item/{ID}`. All explicitly grant
+5% kill XP after at least 10 seconds consuming, with a 15-minute Well Fed bonus.
Lobster Stew (13933, level 45) was already supported. Added Peace Tea (249865,
no listed character-level requirement), Royal Tea (249866, level 5), Root Tea
(249867, level 15), Triage Tea (249868, level 25), and Sage's Tea (249870,
level 45). The allowlist now contains 61 entries. These drinks use the same
item-use path; no general drink detection or aura mappings were added.
Individually verified linked use spells at
`https://nether.wowhead.com/forever/tooltip/spell/{ID}`:
1249920/1249921/1249922/1249923/1249925. They confirm the XP effect and
2/7/11/22/44 Healing Power respectively; tooltip wording says eating despite
restoring mana while drinking. Resulting aura IDs are not exposed.
Mock tests cover selection and required-level boundaries for all six items.
Actual drinking and resulting XP aura detection still need in-game validation.

Reverified 5095/21072/21217/274971/13931/13935/249869 at
`https://nether.wowhead.com/forever/tooltip/item/{ID}`. All explicitly grant
+5% kill XP after at least 10 seconds eating, with a 15-minute Well Fed bonus.
5095/21072/13931 were already supported at levels 5/10/35. Added Sagefish
Delight (21217, level 30), Briny Seafood Stew (274971, level 25), Baked Salmon
(13935, level 45), and Sunny Tea (249869, level 35); allowlist now has 56 entries.
Sunny Tea restores mana while drinking, although its bonus text says eating;
its explicit XP effect qualifies it for the same reminder. No general drinks
support or new aura mapping was inferred. New distinct use spells verified:
https://nether.wowhead.com/forever/tooltip/spell/1249507
https://nether.wowhead.com/forever/tooltip/spell/1249510
https://nether.wowhead.com/forever/tooltip/spell/1249924
These list 7 Spell Damage, 14 Spell Damage, and 33 Healing Power respectively,
plus the XP effect, with no resulting aura mapping exposed. Baked Salmon uses
previously verified 1249516 (28 Spell Damage). Tests cover selection at each
item's required level and rejection below it. In-game selection, secure item use
and resulting XP aura detection for these additions remain to be confirmed.

Reverified user-provided IDs 6290/787/4592/8364/13927/13932/13934 at
`https://nether.wowhead.com/forever/tooltip/item/{ID}`. All explicitly grant
+5% kill XP after 10 seconds eating, with a 15-minute Well Fed bonus.
Added Slitherskin Mackerel (787, no listed character-level requirement) and
Mithril Head Trout (8364, required level 25), bringing the allowlist to 52.
The other five were already supported, with requirements 1/5/35/35/45.
Also verified their new linked use spells:
https://nether.wowhead.com/forever/tooltip/spell/1249503
https://nether.wowhead.com/forever/tooltip/spell/1249509
These confirm 6/20 Attack Power respectively and the XP effect; neither exposes
a resulting aura mapping. Tests cover all seven items' availability and level
boundaries, plus highest-usable-level selection, fallback and stable ties.
In-game: carry multiple levels of supported food without its XP buff, `/reload`,
and confirm the highest usable level is selected and clicking eats that item.
No class-specific stat optimization or increased-healing tie-breaker is claimed.

Added Twice-Spiced Raptor Slice (250077) after verifying:
https://nether.wowhead.com/forever/tooltip/item/250077
https://nether.wowhead.com/forever/tooltip/spell/1248383
Requires character level 5; at least 10 seconds eating grants 3 Intellect and
+5% kill XP for 15 minutes. The use spell does not expose a resulting aura ID;
no additional aura mapping was inferred. Tests cover selection at level 5 and
rejection at level 4. This brings the allowlist to 50 entries, not an exhaustive
Forever food list. In-game selection/click behavior still needs confirmation.

Rechecked all 49 entries in `consumables.food` using
`https://nether.wowhead.com/forever/tooltip/item/{ID}`. Every English name and
required character level matches the encoded entry (no listed requirement is
represented as level 1). Every item explicitly grants +5% kill XP after at least
10 seconds eating, with a 15-minute Well Fed bonus. No food priorities changed.
Longjaw Mud Snapper (4592) requires level 5 and lists 10 Attack Power plus XP;
its use spell is 1249506, not its resulting aura ID.

Also checked every distinct linked Nutritious Food use spell at
`https://nether.wowhead.com/forever/tooltip/spell/{ID}`:
1248377, 1248378, 1248379, 1248380, 1248381, 1248382, 1248383, 1248384,
1248386, 1248387, 1248388, 1248389, 1248390, 1248391, 1248392, 1248394,
1248395, 1248687, 1249500, 1249501, 1249502, 1249504, 1249505, 1249506,
1249512, 1249513, 1249514, 1249515, 1249516, 1249522.
All 30 explicitly confirm +5% kill XP. Their tooltip endpoints have empty
`buff`/`buffspells`; they do not expose a food-to-resulting-aura mapping.
Human-readable Forever pages returned HTTP 403. No mappings were inferred from
adjacent IDs, matching stats, or character level.

Independently queried each aura below using
`https://nether.wowhead.com/forever/tooltip/spell/{ID}`. Each is named Well Fed,
lasts 15 minutes, and has `buffspells[1243969]` explicitly stating
"Experience gained from kills increased by 5%." These qualify independently
of which food applies them:

| Aura ID | Listed additional effect |
| --- | --- |
| 1248406 | 1 Stamina |
| 1248420 | 1 Agility |
| 1248421 | 1 Intellect |
| 1248422 | 1 Strength |
| 1248688 | 15% movement speed while in Westfall |
| 1249519 | 1 Attack Power |
| 1249520 | 1 Spell Damage |
| 1249521 | 1 Fishing Skill |
| 1249523 | 1% Critical Strike chance |

The aura stat amounts differ from many item tooltips. Scaling and exact
food-to-aura mappings remain unverified; detection only relies on explicit XP
text. This audit is not proof that no other XP-bearing aura IDs exist. Tests
cover all nine qualifying IDs and rejection of an unknown Well Fed ID.
In-game, try Longjaw Mud Snapper and other supported foods after 10 seconds
of eating; if the icon remains, share an out-of-combat `/buffed status` report.

## In-game smoke test

Mock tests do not verify Forever's actual aura APIs, frame protection,
spellbook, or secure-click behavior. Validate these in the client:

1. On a priest, remove Inner Fire: its icon should appear. Click with another
   unit targeted: it should buff yourself and disappear.
2. Apply Fortitude (try different learned ranks), Inner Fire, and Shadowguard:
   each should hide its reminder. Apply Prayer of Fortitude: no Fortitude
   reminder should appear. Check `/buffed status` for the actual aura IDs and
   share it if a reminder stays visible. Test scroll Intellect, Arcane Intellect,
   and Arcane Brilliance when available; each should hide the Intellect icon.
3. Enter combat with a reminder visible: the bar should hide and return afterward.
4. Enter combat with Shadowguard active, then spend its charges. The bar should
   stay hidden. Use `/buffed status` for the first time during that fight: the
   copy window should open and label its pre-combat aura snapshot cached.
   Leave combat: the Shadowguard reminder should return and status update.
   Repeat with movement and aura/bag/spell events; no secret-aura errors should
   occur.
5. Mount/dismount and die/resurrect: reminders should hide and return.
6. Move the bar and toggle a reminder, then `/reload`: settings should persist.
7. Carry supported usable XP food without its XP buff: the icon should appear.
   Eat for at least 10 seconds: it should disappear once the XP buff appears.
   Plain Well Fed must not hide it. Removing the last supported usable food
   should hide it. Moving should hide only the food icon; stopping should
   restore it if the XP buff is missing.
8. Carry a usable Scroll of Intellect without an Intellect buff: its icon should
   appear. Click with another unit targeted: it should buff yourself and
   disappear. Removing the last scroll should also hide the icon.

## Validation and workflow

Runtime files are `Buffed.toc` and `Buffed.lua`. Mock tests are in
`tests/smoke.lua`; they are not loaded by the game.

Run from the addon folder:

```bash
lua tests/smoke.lua
# Alternative when no Lua interpreter is installed:
npx --yes --package fengari-node-cli fengari tests/smoke.lua

git diff --check
```

Update tests and `README.md` alongside behavior changes. Mock success does not
prove the real client works. Ask the user to `/reload` and test in-game; use
`/buffed status` for diagnostics. Lua error reporting can be enabled with
`/console scriptErrors 1` followed by `/reload`.

## Versioning and releases

Releases use an integer from `github.run_number` in
`.github/workflows/release.yml`. No manual version bumps or Lua version constant
are needed. The repository's `Buffed.toc` says `dev`; packaging writes the run
number into the archived TOC only, without modifying or committing source files.

The workflow is manually triggered via **Actions → Release → Run workflow**.
Run 12 creates tag/release `v12` at the selected commit and `Buffed-v12.zip`, with
generated release notes. Failed runs can leave gaps. Reruns keep their number;
if a release already exists, creation fails rather than overwriting it. Run a
new workflow to publish another release. Keep this workflow's identity stable
so its run numbering continues.

The ZIP contains a top-level `Buffed/` folder with only `Buffed.toc`, `Buffed.lua`,
and `README.md`; developer files are excluded. Packaging uses Python's standard
library on the GitHub runner. The repository needs Actions enabled and
`contents: write` access. The manual workflow must be present on the default
branch before GitHub offers its Run workflow button.

Release procedure (only when explicitly requested):

1. Validate, commit, and push the intended release changes.
2. In GitHub Actions, run **Release**, selecting the intended branch.
3. Check the workflow, generated release, and ZIP. Extracting it into
   `Interface/AddOns` should produce `Interface/AddOns/Buffed/Buffed.toc` without
   extra nesting, and the archived TOC should show the release number.

Only commit or push when asked. Report whether changes were committed or pushed.
