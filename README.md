# Buffed

A small English-only priest self-buff addon for WoW Forever (interface 16001).
Original implementation inspired by BuffCheck; no external libraries required.

## First increment

- Missing **Power Word: Fortitude**, **Inner Fire**, **Divine Spirit**, and **Shadowguard** reminders.
- Optional **Shadow Protection** and **Shadowform** reminders, off by default.
- Only learned spells appear. Prayer equivalents also satisfy their buff group.
- Click a priest spell icon to cast the single-target buff on yourself.
- **Well Fed** reminder, on by default. Eat buff food from your bags; this icon
  is reminder-only and does not select or use food.
- Hidden during combat, while dead/ghost, or while mounted.
- Position and enabled reminders are saved per character.

No party/raid scanning, expiry warnings, automatic food selection, other consumable tracking,
minimap button, or options panel yet.
Other classes do nothing. Use an English game client.

## Try it

The addon folder must be named `Buffed` and contain `Buffed.toc` and `Buffed.lua`.
Enable Buffed in the character-selection AddOns list, then log in (or `/reload`).
Missing learned buffs appear near the center, slightly below your character.

- `/buffed` — help
- `/buffed unlock` — drag the **Buffed** label to move the icons
- `/buffed lock` — finish moving
- `/buffed reset` — reset position
- `/buffed status` — show enabled/learned status
- `/buffed fortitude`, `fire`, `spirit`, `shadow`, `form`, `shadowguard`, or `food` — toggle that reminder

### In-game smoke test

1. On a priest, remove Inner Fire: its icon should appear. Click it: the buff
   should be applied to yourself even with another unit targeted, and the icon disappear.
2. Apply Prayer of Fortitude: no Fortitude reminder should appear.
3. Enter combat with a reminder visible: the bar should hide and return afterward.
4. Mount/dismount and die/resurrect: reminders should hide and return appropriately.
5. Move the bar and toggle a reminder, then `/reload`: settings should persist.
6. Without Well Fed, a food icon should appear. Eat buff food until Well Fed
   is applied: the icon should disappear. Remove Well Fed: it should return.

Automated tests use mocked WoW APIs, not the actual client. In-game validation is
still required, particularly Forever's spellbook and secure-click behavior.

Run the mock tests from this folder with Lua 5.1+:

```
lua tests/smoke.lua
```
