# Developer instructions

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
  exhaustive. Selection prefers Roasted Boar Meat, then lower-level foods,
  ignoring stat bonuses.
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

### Camp Benefits reminder

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
