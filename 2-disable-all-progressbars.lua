--[[
    This user patch is primarily for use with the Project: Title plugin.

    It hides all book information overlays in Cover Grid. All of them.
    Progress bars, text based percentage, file size, series number.
--]]

local userpatch = require("userpatch")
local function patchCoverBrowser(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    local orig_MosaicMenuItem_paintTo = MosaicMenuItem.paintTo
    MosaicMenuItem.paintTo = function(self, bb, x, y)
        local file = self.entry.file or false
        local is_file = self.entry.is_file or false
        -- pretend to be a directory in paintTo and everything is skipped
        self.entry.file = false
        self.entry.is_file = false
        orig_MosaicMenuItem_paintTo(self, bb, x, y)
        -- restore original values for everything else
        self.entry.file = file
        self.entry.is_file = is_file
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
