# Buffed

Buff reminders for all classes in **WoW Forever** (English client).

## Setup

Download the ZIP from [Releases](https://github.com/LarsEckart/Buffed/releases)
and extract its `Buffed` folder into `Interface/AddOns`. Enable it in the AddOns
list, then log in or `/reload`. Missing buffs appear near the center of your screen.
Click a spell or item icon to buff yourself, even with another unit targeted.
Camp Benefits and Hydrocane are informational reminders only (not clickable).

## Reminders

**All classes** get XP food, Intellect scroll, Cozy Sleeping Bag, Hydrocane, and Camp Benefits
reminders when their prerequisites are met. Item reminders require a supported,
usable item in your bags; Camp Benefits needs no item.

**Skyborne** characters get **Skysight** when learned and off cooldown. Click for
its 30-second speed boost; like other reminders, it stays hidden while mounted.

**Druids** also get **Mark of the Wild** (Gift of the Wild counts), **Thorns**,
and **Nature's Grasp**. Nature's Grasp appears only when learned, missing, and
off cooldown; click to cast on yourself.
**Priests** also get the spell reminders listed below. Spell reminders appear
only when learned and missing; click to cast on yourself.

- **Camp Benefits** — appears when the umbrella buff is missing, regardless of
  carried items. This icon cannot refresh the buff; visit a camp. Individual
  camp benefits are not checked.

- **Power Word: Fortitude, Divine Spirit, Inner Fire, and Shadowguard** (priests) — only learned spells
  appear; equivalent prayer buffs also count.
- **XP food** — appears when you carry supported food or XP-granting tea and lack its XP buff.
  Click to eat/drink and stay seated for at least 10 seconds for **+5% XP from kills**.
  Not all food or Well Fed buffs qualify. Supported foods include Roasted Boar
  Meat, Brilliant Smallfish, Longjaw Mud Snapper, Crab Cake, Strider Stew,
  Smoked Sagefish, Roast Raptor, Twice-Spiced Raptor Slice, Slitherskin Mackerel,
  Mithril Head Trout, Sagefish Delight, Briny Seafood Stew, and Baked Salmon.
  Selects the carried food/drink with the highest level
  requirement you meet; equal-level ties use a fixed order, not stat bonuses.
  Recognized XP-bearing Well Fed variants count even when they also grant stats.
- **Scroll of Intellect** — uses your highest usable rank (I–IV); hidden when
  you already have Intellect or Arcane Brilliance.
- **Hydrocane** — appears at level 27+ when carried in your bags, not equipped,
  and your breath timer is active. Equip it manually for 50% longer underwater
  breath. Hides once equipped or the breath bar disappears, without needing to
  stop moving; does not restore
  your previous weapon automatically.
- **Cozy Sleeping Bag** — appears when you carry the bag and lack Well-Rested.
  Click to unroll, then rest inside for at least one minute. Any stack of
  Well-Rested hides the reminder.

Reminders hide during combat, while mounted, or while dead, and refresh when
these states end. Camp Benefits and Cozy Sleeping Bag also hide inside dungeons.
The food reminder also hides while moving. Position and reminder settings are
saved per character.

## Commands

| Command | Action |
| --- | --- |
| `/buffed` | Show help |
| `/buffed unlock` | Drag the **Buffed** label to move the bar |
| `/buffed lock` | Lock the bar |
| `/buffed reset` | Reset its position |
| `/buffed mark`, `thorns`, `grasp`, `skysight`, `fortitude`, `spirit`, `fire`, `shadowguard`, `food`, `intellect`, `sleepingbag`, `hydrocane`, or `camp` | Toggle a reminder supported by your class |
| `/buffed status` | Show diagnostics in chat and a copy window |

If a reminder stays visible after buffing, run `/buffed status`, press **Ctrl+C**
to copy the selected text, and share it with your report. Press **Escape** to close the window.
During combat, diagnostics show **cached, not live** information. If an error
appears after combat, include that message too.
