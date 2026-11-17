# Buffed

Clickable self-buff reminders for priests and druids in **WoW Forever** (English client).

## Setup

Download the ZIP from [Releases](https://github.com/LarsEckart/Buffed/releases)
and extract its `Buffed` folder into `Interface/AddOns`. Enable it in the AddOns
list, then log in or `/reload`. Missing buffs appear near the center of your screen.
Click a spell or item icon to buff yourself, even with another unit targeted.
Camp Benefits is an informational reminder only.

## Reminders

Druids currently get **Mark of the Wild** (Gift of the Wild also counts),
**Thorns**, and the shared **XP food** reminder below. Spell reminders appear
only when learned and missing; click to cast on yourself. Toggle them with
`/buffed mark`, `/buffed thorns`, or `/buffed food`.
The remaining reminders are priest-only.

- **Camp Benefits** — appears when the umbrella buff is missing, regardless of
  carried items. This icon cannot refresh the buff; visit a camp. Individual
  camp benefits are not checked.

- **Power Word: Fortitude, Divine Spirit, Inner Fire, and Shadowguard** — only learned spells
  appear; equivalent prayer buffs also count.
- **XP food** — appears when you carry supported food and lack its XP buff.
  Click to eat and stay seated for at least 10 seconds for **+5% XP from kills**.
  Not all food or Well Fed buffs qualify. Supported foods include Roasted Boar
  Meat, Brilliant Smallfish, Longjaw Mud Snapper, Crab Cake, Strider Stew,
  Smoked Sagefish, Roast Raptor, and Twice-Spiced Raptor Slice.
  Recognized XP-bearing Well Fed variants count even when they also grant stats.
- **Scroll of Intellect** — uses your highest usable rank (I–IV); hidden when
  you already have Intellect or Arcane Brilliance.
- **Cozy Sleeping Bag** — appears when you carry the bag and lack Well-Rested.
  Click to unroll, then rest inside for at least one minute. Any stack of
  Well-Rested hides the reminder.

Reminders hide during combat, while mounted, or while dead, and refresh when
these states end. Camp Benefits and Cozy Sleeping Bag also hide inside dungeons.
The food reminder also hides while moving. Position and reminder settings are
saved per character. Other classes are not supported.

## Commands

| Command | Action |
| --- | --- |
| `/buffed` | Show help |
| `/buffed unlock` | Drag the **Buffed** label to move the bar |
| `/buffed lock` | Lock the bar |
| `/buffed reset` | Reset its position |
| `/buffed mark`, `thorns`, `fortitude`, `spirit`, `fire`, `shadowguard`, `food`, `intellect`, `sleepingbag`, or `camp` | Toggle a reminder supported by your class |
| `/buffed status` | Show diagnostics in chat and a copy window |

If a reminder stays visible after buffing, run `/buffed status`, press **Ctrl+C**
to copy the selected text, and share it with your report. Press **Escape** to close the window.
During combat, diagnostics show **cached, not live** information. If an error
appears after combat, include that message too.
