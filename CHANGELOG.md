# GamepadMacros

## 0.3.7

- **Heal Me heals your friend too.** With a friendly player targeted, it heals them; otherwise it heals you, including with nothing or an enemy targeted (your target stays on the enemy) or a dead friend targeted. A Heal Me you have not edited is updated by itself when you log in.

## 0.3.6

- Heal Me names the heal without a rank again ("/cast [@player] Lesser Heal"). Forever's combat log shows that casting a spell by name already casts your highest rank, so the rank is not needed.

## 0.3.5

- Heal Me is tidier: just the one heal, your best, at its best rank ("/cast [@player] Lesser Heal(Rank 3)"; a priest switches to Heal once learned). It still moves up by itself when you learn a new rank.

## 0.3.4

- **Heal Me casts your best rank.** In Forever, casting a heal by name alone casts Rank 1. Heal Me now names your highest learned rank ("/cast [@player] Lesser Heal(Rank 3)"), followed by the name alone in case a rank is not accepted. When you learn a new rank, Heal Me moves up to it by itself, and chat says so. A Heal Me you have edited yourself is left alone.

## 0.3.3

- **The window now sizes itself to its text.** Each time it opens, every name, description, status and button is measured, and the rows, buttons and window are made as big as their text needs, so nothing overlaps whatever text size, font or screen you play with (a handheld like the Legion Go or Steam Deck included). Long descriptions wrap onto a second line, the bottom buttons stack if they do not fit side by side, and if the window would still be taller or wider than your screen it is scaled down to fit.

## 0.3.2

- **Controller:** the B button now closes GamepadMacros's window, like the X and Escape. While one is open, B closes it; once it is closed, B does whatever you have it set to again.

## 0.3.1

- When you log in, GamepadMacros checks every macro it added and brings it up to date with the installed version, so improvements in later versions reach macros you added before. It says in chat which ones it updated. A macro you have edited yourself is left as it is.

## 0.3.0

Eat & Drink, rebuilt around two simple steps:

- **First press: your best plain food.** As soon as its short cast finishes and you are eating, the button turns into **your best plain drink**, so the second press drinks too.
- **Back to the food** when you drink, move, stand up, or go into combat (or after 30 seconds if the game never shows the eating buff).
- **Buff food and drink are skipped:** anything that makes you Well Fed is left for you to use yourself.
- The button always shows the item the next press uses.

## 0.2.7

- Eat & Drink turns into your drink as soon as you finish the short cast of eating, even when GamepadMacros cannot recognise Forever's eating buff (before, it could stay on the food, and a second press only said a more powerful spell was already active). It turns back into the food 30 seconds later or when you get up.
- `/gpm debug` also lists your food, your drink, whether you count as eating or drinking, and your buffs.

## 0.2.6

- Fixed: the buttons for Eat & Drink, Bandage, Potion and Quest Item kept their fixed picture (Eat & Drink always showed a turkey), whatever item they were set to use. They now have the question-mark icon, which makes the button show the item the macro uses right now: your food, then your drink once you are eating, or your next food when one runs out. Macros added before are switched over by themselves.

## 0.2.5

- Eat & Drink's button now shows what the next press does: your food until you are eating, then your drink, then the food again once you get up. It no longer uses a /castsequence (whose icon did not change) or a 30-second reset, and a second press during the food's short cast can no longer cancel it.

## 0.2.4

- Fixed: 0.2.3 still did not take back its own macros when the game handed their text back with a line break after it. That is now ignored.
- `/gpm debug` lists, for each macro that follows your bags, what the game reports and what GamepadMacros wants it to be.

## 0.2.3

- Fixed: the macros that follow your bags (Eat & Drink, Bandage, Potion, Quest Item) could stop updating for good. GamepadMacros only updates macros it made, and the game only saves that record when it closes normally, so after a crash it forgot them. It now also recognises its own macros by their text, so they update again, while a macro you wrote yourself is still never touched.
- Hovering over a macro in the window now shows the macro as it really is in your macro list.

## 0.2.2

- Eat & Drink now takes two presses: the first eats your best food, the second drinks your best drink while you keep eating. In Forever, eating starts with a short cast, and drinking in the same press cancelled it, so you only drank. After 30 seconds it starts with the food again.

## 0.2.1

- Fixed: Eat & Drink could miss your food and only drink. Food is now recognised by the game's Food & Drink item category, not only by a use called "Food", and food the game has not finished loading when you log in is picked up as soon as it arrives.

## 0.2.0

- New macros for things in your bags, each one button: **Bandage** (your best bandage), **Eat & Drink** (your best food and drink in one press), **Potion** (your best healing potion) and **Hearth** (your Hearthstone). Like Quest Item, they follow your bags as they change, outside combat, and pick the best item your character is high enough to use.

## 0.1.0

- First version. The gamepad macros from MacroKit 0.6 (Heal Me, Quest Item, Save Gear, Wear Gear, Leave Group, Hello, Thanks, Follow Me, Need Help), now an addon of their own with a **Gamepad macros** window (`/gpm`). The minimap button shows once you use a controller. Macros MacroKit 0.6 added are taken over.
