--[[
    This user patch is primarily for use with the Project: Title plugin. It requires
    Project: Title v3.5 or higher.

    It replaces a button in the top toolbar.

    You can choose a new icon and new actions for tap and long-press. If you set
    icon, tap, or hold to nil then the original value is kept. In this way you
    could keep an button's icon and tap action and add only a long-press action
    to it.

    Icons are set by using their filename without extension, eg: "check" will use
    the image file /koreader/resources/icons/mdlite/check.svg

    Icons can be any of the ones bundled with KOReader in /koreader/resources/icons
    or you can add your own to /koreader/icons

    You can manually program a button to do absolutely anything, but the fastest
    method is to use the functions defined by, and added to, Dispatcher.

    You can find all predefined functions at the link below. For functions added
    by plugins, you'll have to go digging into their code to find them.

    https://github.com/koreader/koreader/blob/master/frontend/dispatcher.lua
--]]
local userpatch = require("userpatch")
local Dispatcher = require("dispatcher")
local logger = require("logger")
-- You should not need to change the code above this line



-- Pick the button to replace. The other 3 buttons should not be replaced, they are
-- essential to using KOReader.
local button_to_replace = "right3"      -- Open last book (book w/ arrow)
-- local button_to_replace = "left2"       -- Favorites (heart)
-- local button_to_replace = "left3"       -- History (clock)

-- Choose a new icon for the button.
local new_icon = "appbar.search"

-- Tap Callback is the action(s) for a short tap.
local new_tap_callback = function()
    Dispatcher:execute({"file_search"}) -- example: open file search box
end

-- Hold Callback is the action(s) for a long-press.
local new_hold_callback = function() -- multi-action example: set frontlight brightness, then warmth
    Dispatcher:execute({
        ["set_frontlight"] = 40,
        ["set_frontlight_warmth"] = 20,
    })
end



-- You should not need to change the code below this line
local function patchCoverBrowser(plugin)
    local TitleBar = require("titlebar")
    local orig_TitleBar_init = TitleBar.init
    TitleBar.init = function(self)
        self[button_to_replace .. "_icon"] = new_icon or self[button_to_replace .. "_icon"]
        self[button_to_replace .. "_icon_tap_callback"] = new_tap_callback or self[button_to_replace .. "_icon_tap_callback"]
        self[button_to_replace .. "_icon_hold_callback"] = new_hold_callback or self[button_to_replace .. "_icon_hold_callback"]
        orig_TitleBar_init(self)
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
