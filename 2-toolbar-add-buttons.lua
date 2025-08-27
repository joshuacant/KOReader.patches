--[[
    This user patch is primarily for use with the Project: Title plugin. It requires
    Project: Title v3.5 or higher.

    It adds 2 buttons to the toolbar, one on each side of the center logo icon.
    Buttons must be added in pairs to maintain balance in the toolbar.

    This example adds new left4 and right4 buttons, but you can also add left5
    and right5 buttons for a total of 5 per side, if you have enough room. Use
    the provided 'padding5' if you add those buttons.

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
local IconButton = require("ui/widget/iconbutton")
local LeftContainer = require("ui/widget/container/leftcontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local Dispatcher = require("dispatcher")
local userpatch = require("userpatch")
local Device = require("device")
local Geom = require("ui/geometry")
local Screen = Device.screen
local logger = require("logger")

local function patchCoverBrowser(plugin)
    local TitleBar = require("titlebar")
    local orig_TitleBar_init = TitleBar.init
    TitleBar.init = function(self)
        self.width = Screen:getWidth()
        self.titlebar_height = self.icon_size + self.icon_padding_top + self.icon_padding_bottom
        self.dimen = Geom:new {
            x = 0,
            y = 0,
            w = self.width,
            h = self.titlebar_height,
        }
        self.icon_margin_lr = Screen:scaleBySize(24) -- reduce intra-button spacing to fit more
        self.icon_total_width = self.icon_size + self.icon_margin_lr
        local padding4 = self.titlebar_margin_lr + (self.icon_total_width * 3)
        local padding5 = self.titlebar_margin_lr + (self.icon_total_width * 4)

        local function build_container(button, is_left_button, padding)
            local pre_padding
            local post_padding
            if is_left_button then
                pre_padding = padding
                post_padding = self.width - padding - button:getSize().w
            else
                pre_padding = self.width - padding - button:getSize().w
                post_padding = padding
            end
            return LeftContainer:new {
                dimen = self.dimen,
                HorizontalGroup:new {
                    HorizontalSpan:new { width = pre_padding },
                    button,
                    HorizontalSpan:new { width = post_padding },
                },
            }
        end

        self.left4_button = IconButton:new {
            icon = "appbar.pokeball",
            icon_rotation_angle = 0,
            width = self.icon_size,
            height = self.icon_size,
            padding = 0,
            padding_bottom = self.icon_padding_bottom,
            padding_top = self.icon_padding_top,
            callback = function()
                Dispatcher:execute({ "screenshot" })
            end,
            hold_callback = function()
                Dispatcher:execute({
                    ["set_frontlight"] = 40,
                    ["set_frontlight_warmth"] = 20,
                })
            end,
            allow_flash = true,
            show_parent = self.show_parent,
        }
        self.left4_button_container = build_container(self.left4_button, true, padding4)

        self.right4_button = IconButton:new {
            icon = "appbar.search",
            icon_rotation_angle = 0,
            width = self.icon_size,
            height = self.icon_size,
            padding = 0,
            padding_bottom = self.icon_padding_bottom,
            padding_top = self.icon_padding_top,
            callback = function()
                Dispatcher:execute({ "file_search" })
            end,
            hold_callback = function()
                Dispatcher:execute({ "calibre_search" })
            end,
            allow_flash = true,
            show_parent = self.show_parent,
        }
        self.right4_button_container = build_container(self.right4_button, false, padding4)

        orig_TitleBar_init(self)
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
