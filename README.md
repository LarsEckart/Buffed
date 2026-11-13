# Buffed

A small English-only priest self-buff addon for WoW Forever (interface 16001).
Original implementation inspired by BuffCheck; no external libraries required.

## First increment

- Missing **Power Word: Fortitude**, **Inner Fire**, and **Shadowguard** reminders.
- Only learned spells appear. Prayer equivalents also satisfy their buff group.
- Click a priest spell icon to cast the single-target buff on yourself.
- **XP food** reminder, on by default, only when a supported, usable food is in
  your bags and **Well Fed XP Boost** is missing. Click to eat, then remain seated
  for at least 10 seconds for **+5% XP from kills**. Plain Well Fed does not count.
  Recognizes the XP effect by name or spell ID `1243969`, and the client-observed
  **Well Fed** aura `1248422`. Wowhead Forever's `buffspells` confirms that this
  specific Well Fed aura includes the 5% XP effect; other Well Fed IDs are not
  assumed to grant XP. Sources:
  https://nether.wowhead.com/forever/tooltip/spell/1243969
  https://nether.wowhead.com/forever/tooltip/spell/1248422
  Other XP-bearing Well Fed aura IDs remain unverified.
  The allowlist contains foods verified on Wowhead Forever, including Roasted
  Boar Meat, Crab Cake, Strider Stew, Smoked Sagefish, and Roast Raptor. It is not
  exhaustive. Roasted Boar Meat is preferred, then lower-level foods; selection
  ignores stat bonuses. See `consumables.food` in `Buffed.lua` for the full list.
- **Scroll of Intellect** reminder when a usable scroll is in your bags and
  Intellect is missing. Click to use it on yourself. Supports classic ranks
  I–IV (required levels 5/20/35/50) and picks the highest usable rank;
  Arcane Intellect/Brilliance also hide it.
- The clickable bar is hidden during combat, while dead/ghost, or while mounted.
  No conditional Shadowguard combat reminder: the Forever client has reported
  secret/tainted aura-access errors during combat. Buffed does not read aura
  APIs or inspect `UNIT_AURA` payloads in combat, and never modifies secure
  buttons or their layout there. Reminders refresh after combat.
  The food icon also hides while moving and returns when you stop; other icons
  are unaffected. Movement updates are event-driven, with no polling.
- Position and enabled reminders are saved per character.
- Initializes on world entry, not login or earlier bag/spell events. If world
  entry occurs in combat, initialization waits until combat ends. Normal updates
  skip buff, spellbook, and bag scans while dead/ghost or mounted; relevant
  events still hide icons and refresh them when you return.

No party/raid scanning, expiry warnings, general food detection, other consumable
tracking beyond the items above, minimap button, or options panel yet.
Other classes do nothing. Use an English game client.

## Try it

The addon folder must be named `Buffed` and contain `Buffed.toc` and `Buffed.lua`.
Enable Buffed in the character-selection AddOns list, then log in (or `/reload`).
Missing learned buffs appear near the center, slightly below your character.

- `/buffed` — help
- `/buffed unlock` — drag the **Buffed** label to move the icons
- `/buffed lock` — finish moving
- `/buffed reset` — reset position
- `/buffed status` — show enabled/learned status and the client's active buff
  names/IDs (including the aura API used) in chat and a copy window.
  The window is pre-created out of combat, so first use during combat does not
  create frames. In combat, aura states/names/IDs, bag availability, and learned
  spells come exclusively from the last out-of-combat scans and are explicitly
  labelled **cached, not live**. Buffs changing in combat will not change that
  snapshot. If no aura snapshot exists yet, status says so instead of claiming
  buffs are missing. Live scans resume after combat.
  Text is selected automatically: press **Ctrl+C** to copy, then **Escape** to
  close. WoW addons cannot write directly to the system clipboard.
- Runtime errors from event/command handlers are caught so a failed status
  command does not abort chat submission. The first pending error is printed
  to chat after combat (immediately if already out of combat) and retained in
  subsequent `/buffed status` output until reload. If combat behavior fails,
  leave combat and share the `Runtime error (please share)` message; combat
  diagnostics do not need to open successfully.
- `/buffed fortitude`, `fire`, `shadowguard`, `food`, or `intellect` — toggle that reminder

### In-game smoke test

- Enter combat with Shadowguard active, then spend its charges. The bar should
  remain hidden. Run `/buffed status` for the first time during that fight:
  the copy window should open and identify the aura information as cached,
  still listing the pre-combat buff. Leave combat: the normal Shadowguard
  reminder should return, and status should reflect the current aura state.
  Repeat with movement and other aura/bag/spell events during combat; there
  should be no secret-aura errors. Mock tests do not verify Forever's actual
  frame protection or aura APIs.

1. On a priest, remove Inner Fire: its icon should appear. Click it: the buff
   should be applied to yourself even with another unit targeted, and the icon disappear.
2. Apply Prayer of Fortitude: no Fortitude reminder should appear.
3. Enter combat with a reminder visible: the bar should hide and return afterward.
4. Mount/dismount and die/resurrect: reminders should hide and return appropriately.
5. Move the bar and toggle a reminder, then `/reload`: settings should persist.
6. Carry supported XP food without Well Fed XP Boost: its icon should appear.
   Click to eat for at least 10 seconds: the icon should disappear once the XP
   buff appears. Plain Well Fed must not hide it. Removing the last supported,
   usable food from your bags should also hide the icon. Start moving: only the
   food icon should hide. Stop moving: it should return if the XP buff is missing.
7. Carry a usable Scroll of Intellect without an Intellect buff: its icon should
   appear. Click it with another unit targeted: it should buff you and disappear.
   Removing the last scroll from your bags should also hide the icon.

API reference: Blizzard's generated `UnitAuraDocumentation.lua` marks
`GetBuffDataByIndex` with `RequiresUnitAuraAccess` and
`SecretWhenUnitAuraRestricted`:
https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitAuraDocumentation.lua
This is a community mirror of Blizzard's current Retail-generated documentation,
not Forever-specific compatibility evidence. The user's Forever client error
is the evidence for conservatively avoiding combat aura access here.

Automated tests use mocked WoW APIs, not the actual client. In-game validation is
still required, particularly Forever's spellbook and secure-click behavior.

Run the mock tests from this folder with Lua 5.1+:

```
lua tests/smoke.lua
```
