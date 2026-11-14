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
- XP detection recognizes Well Fed XP Boost by name or spell ID `1243969`,
  plus client-observed Well Fed aura `1248422`. Wowhead Forever's `buffspells`
  confirms that this specific Well Fed aura includes the 5% XP effect. Other
  XP-bearing Well Fed IDs remain unverified; do not generalize to all Well Fed.
  Sources:
  https://nether.wowhead.com/forever/tooltip/spell/1243969
  https://nether.wowhead.com/forever/tooltip/spell/1248422
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
  detection, consumables beyond XP food and Intellect scrolls, a minimap button,
  and an options panel. Other classes do nothing.

## In-game smoke test

Mock tests do not verify Forever's actual aura APIs, frame protection,
spellbook, or secure-click behavior. Validate these in the client:

1. On a priest, remove Inner Fire: its icon should appear. Click with another
   unit targeted: it should buff yourself and disappear.
2. Apply Prayer of Fortitude: no Fortitude reminder should appear.
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

Only commit or push when asked. Report whether changes were committed or pushed.
