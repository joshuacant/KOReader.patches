--[[
    This user patch is primarily for use with the Project: Title plugin.

    You can configure the status bar info widgets that optionally appear
    in the footer. In the example below, both frontlight indicators will
    not be shown.
--]]
local Menu = require("ui/widget/menu")
local updatePageInfo_orig = Menu.updatePageInfo

Menu.updatePageInfo = function(self, select_number)
    self.footer_config = {
        order = {
            "clock",
            "wifi",
            "battery",
            -- "frontlight",         -- Removed frontlight
            -- "frontlight_warmth",  -- Removed frontlight_warmth
        },
        wifi_show_disabled = true,
        frontlight_show_off = true,
    }
    updatePageInfo_orig(self, select_number)
end
