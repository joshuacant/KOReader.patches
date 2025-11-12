--[[
    This user patch is primarily for use with the Project: Title plugin.

    It allows for setting the font size and face for the footer visible when browsing folders. It
    does not affect the footer aka "Status Bar" while reading a book.

    good_serif and font_size are used for showing the current folder name (or 'Home'/'Library')
    good_sans and font_size_deviceinfo are used for showing the device info (wifi, frontlight, etc)

--]]

local userpatch = require("userpatch")
local function patchCoverBrowser(plugin)
    local Menu = require("ui/widget/menu")
    local ptutil = require("ptutil")
    local orig_Menu_init = Menu.init
    Menu.init = function(self)
        local orig_good_serif = ptutil.good_serif
        local orig_good_sans = ptutil.good_sans
        local orig_font_size = ptutil.footer_defaults.font_size
        local orig_font_size_deviceinfo = ptutil.footer_defaults.font_size_deviceinfo

        -- ========== set what you want in here ==========
        ptutil.good_serif = "source/SourceSerif4-BoldIt.ttf"
        ptutil.good_sans = "source/SourceSerif4-BoldIt.ttf"
        ptutil.footer_defaults.font_size = 10
        ptutil.footer_defaults.font_size_deviceinfo = 10
        -- ========== set what you want in here ==========

        orig_Menu_init(self)
        ptutil.good_sans = orig_good_sans
        ptutil.good_serif = orig_good_serif
        ptutil.footer_defaults.font_size = orig_font_size
        ptutil.footer_defaults.font_size_deviceinfo = orig_font_size_deviceinfo
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)