# MenuExt

MenuExt is a [Hammerspoon](http://hammerspoon.org) that allows you to get spoken info about all your menu extras with simple global hotkeys.

## Installation

First, download and install Hammerspoon. You can do so either [from their Github](https://github.com/Hammerspoon/hammerspoon/releases/latest), or if you have it installed, through homebrew simply by running:

```bash
$ brew install Hammerspoon
```

in Terminal. Once you have it installed, run it, and follow the prompts to grant accessibility permissions (I also choose to hide the app from the dock here so it stays out of your command-tab switcher)

If you're a VoiceOver user, you also need to allow external apps to control VoiceOver through Apple Script. To do so, open VoiceOver utility with VO + f8, navigate to the "General" section and check the "Allow VoiceOver to be controlled with AppleScript" checkbox.

Once Hammerspoon is installed and configured, navigate into the folder where you cloned this repository with Finder or another file manager, and open "MenuExt.spoon" which should cause Hammerspoon to install it into the right place. Finally, from the Hammerspoon menu extra select the open configuration option which should open your default text editor with your init.lua file. To make MenuExt work and do its thing, simply add the following 2 lines:

```lua
hs.loadSpoon("MenuExt")
spoon.MenuExt:start()
```

Save the file, return to the Hammerspoon menu extra but this time click the reload configuration option for your new changes to take effect. Mac OS will warn you that Hammerspoon is trying to control Voice Over. Grant it permission and the spoon should start working.

## Keys

By default the keys are Option-Shift with the number row:

* Option-Shift-1 to 9, and 0: the menu extra in slots 1 to 10. Press once to hear it, or twice quickly to open it.
* Option-Shift-= (the last key of the number row): the next page of ten, for slots 11 to 20 and so on.
* Option-Shift-` (the first key of the number row): the previous page.

The page stays where you leave it. Menu extras are counted from left to right.

macOS's own menu extras (Wi-Fi, Battery, Clock, Control Center and so on) are named, with their current value where macOS gives one, such as "Battery, 80%, charging" or "Clock, Mon 5 Oct 19:40".

## Choosing the modifier keys

Option-Shift with a number types a character on most keyboard layouts, which can't then be typed while MenuExt is running. To use other modifiers, set them before `start()`, as a list or a single string:

```lua
hs.loadSpoon("MenuExt")
spoon.MenuExt.modifiers = {"ctrl", "opt"} -- or "CTRL+OPT"
spoon.MenuExt:start()
```

Modifier names, in any case: `CTRL`, `OPT`, `CMD` and `SHIFT` (`CONTROL`, `CTL`, `OPTION`, `ALT` and `COMMAND` also work). For one side of the keyboard only, put `L` or `R` in front, e.g. `ROPT`, `LCMD` or `RCTRL`.

Control-Option doesn't type characters, but it's VoiceOver's modifier unless you've changed that to Caps Lock in VoiceOver Utility.

## Credits

* Instillation instructions adapted from [Indent Beeper](https://github.com/pitermach/IndentBeeper).
* Initial code for getting the text of each menu extra by [Mikolaj Holysz](https://www.github.com/mikolysz).
