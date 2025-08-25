--[[
    This user patch is primarily for use with the Project: Title plugin.

    It hides progress bars in Cover Grid when a book has been finished.

    There is an optional setting below to display the trophy svg in
    in the lower right corner of the book cover, similar to the old
    dogear style from Cover Browser.
--]]

local show_finished_img_in_corner = true

local userpatch = require("userpatch")
local function patchCoverBrowser(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    local orig_MosaicMenuItem_paintTo = MosaicMenuItem.paintTo
    MosaicMenuItem.paintTo = function(self, bb, x, y)
        if self.status == "complete" or self.percent_finished == 1 then
            self.show_progress_bar = false
            self.been_opened = false -- this lie will also hide the text-based progress box
        end
        orig_MosaicMenuItem_paintTo(self, bb, x, y)
        if show_finished_img_in_corner and (self.status == "complete" or self.percent_finished == 1) then
            local FrameContainer = require("ui/widget/container/framecontainer")
            local Size = require("ui/size")
            local Blitbuffer = require("ffi/blitbuffer")
            local ImageWidget = require("ui/widget/imagewidget")
            local DataStorage = require("datastorage")
            local Device = require("device")
            local Screen = Device.screen
            local status_icon_size = Screen:scaleBySize(16)
            local plugin_path = DataStorage:getFullDataDir() .. "/plugins/projecttitle.koplugin"
            local finished_img = FrameContainer:new {
                radius = 0,
                bordersize = Size.border.thin,
                padding = Size.padding.small,
                margin = 0,
                background = Blitbuffer.COLOR_WHITE,
                ImageWidget:new {
                    file = plugin_path .. "/resources/trophy.svg",
                    alpha = true,
                    width = status_icon_size,
                    height = status_icon_size,
                    scale_factor = 0,
                    original_in_nightmode = false,
                },
            }
            local target = self[1][1][1]
            local pos_x = x + self.width / 2 + target.width / 2 - finished_img:getSize().w
            local pos_y = y + (self.height - finished_img:getSize().w - (Size.border.thin * 2))
            finished_img:paintTo(bb, pos_x, pos_y)
        end
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
