# Buffed

Clickable self-buff reminders for priests in **WoW Forever** (English client).

## Setup

Place the `Buffed` folder in `Interface/AddOns`, enable it in the AddOns list,
then log in or `/reload`. Missing buffs appear near the center of your screen.
Click an icon to buff yourself, even with another unit targeted.

## Reminders

- **Power Word: Fortitude, Inner Fire, and Shadowguard** — only learned spells
  appear; equivalent prayer buffs also count.
- **XP food** — appears when you carry supported food and lack its XP buff.
  Click to eat and stay seated for at least 10 seconds for **+5% XP from kills**.
  Not all food or Well Fed buffs qualify. Supported foods include Roasted Boar
  Meat, Crab Cake, Strider Stew, Smoked Sagefish, and Roast Raptor.
- **Scroll of Intellect** — uses your highest usable rank (I–IV); hidden when
  you already have Intellect or Arcane Brilliance.

Reminders hide during combat, while mounted, or while dead, and refresh when
these states end. The food reminder also hides while moving. Position and
reminder settings are saved per character. Other classes are not supported.

## Commands

| Command | Action |
| --- | --- |
| `/buffed` | Show help |
| `/buffed unlock` | Drag the **Buffed** label to move the bar |
| `/buffed lock` | Lock the bar |
| `/buffed reset` | Reset its position |
| `/buffed fortitude`, `fire`, `shadowguard`, `food`, or `intellect` | Toggle that reminder |
| `/buffed status` | Show diagnostics in chat and a copy window |

For troubleshooting, run `/buffed status`, press **Ctrl+C** to copy the selected
text, and share it with your report. Press **Escape** to close the window.
During combat, diagnostics show **cached, not live** information. If an error
appears after combat, include that message too.
