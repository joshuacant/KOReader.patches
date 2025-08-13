--[[
    This user patch is primarily for use with the Project: Title plugin.

    It hides progress bars in Cover Grid when a book has not been opened yet.
--]]

local userpatch = require("userpatch")
local function patchCoverBrowser(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    local orig_MosaicMenuItem_paintTo = MosaicMenuItem.paintTo
    MosaicMenuItem.paintTo = function(self, bb, x, y)
        if self.percent_finished == nil then
            self.show_progress_bar = false
        end
        orig_MosaicMenuItem_paintTo(self, bb, x, y)
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)