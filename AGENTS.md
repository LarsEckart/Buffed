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
