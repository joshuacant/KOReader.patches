--[[
    This user patch is primarily for use with the Project: Title plugin.

    It restores the stock KOReader footer with centered pagination controls
    and disables completely the footer bundled with PT.
--]]

local Menu = require("ui/widget/menu")
local userpatch = require("userpatch")

local function patchCoverBrowser(_plugin)
    local ok, CoverMenu = pcall(require, "covermenu")
    if not ok or not CoverMenu or not CoverMenu.menuInit then
        return
    end
    Menu.init = function(self, ...)
        return CoverMenu._Menu_init_orig(self, ...)
    end
end
userpatch.registerPatchPluginFunc("projecttitle", patchCoverBrowser)
