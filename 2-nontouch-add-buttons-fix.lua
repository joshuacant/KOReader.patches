--[[
    This user patch is primarily for use with the Project: Title plugin. It requires
    Project: Title v3.5 or higher.

    It adds support for using the d-pad on older Kindle-style devices when adding extra
    buttons to the top toolbar.
--]]
local userpatch = require("userpatch")
local logger = require("logger")

local function patchCoverBrowser(plugin)
    local TitleBar = require("titlebar")
    -- local orig_generateHorizontalLayout = TitleBar.generateHorizontalLayout
    -- local orig_generateVerticalLayout = TitleBar.generateVerticalLayout

    TitleBar.generateHorizontalLayout = function(self)
        local row = {}
        if self.left1_button then
            table.insert(row, self.left1_button)
        end
        if self.left2_button then
            table.insert(row, self.left2_button)
        end
        if self.left3_button then
            table.insert(row, self.left3_button)
        end



        -- add extra left buttons here in ascending order:
        if self.left4_button then
            table.insert(row, self.left4_button)
        end
        -- stop adding
        if self.center_button then
            table.insert(row, self.center_button)
        end
        -- add extra right buttons here in descending order:
        if self.right4_button then
            table.insert(row, self.right4_button)
        end
        -- stop adding



        if self.right3_button then
            table.insert(row, self.right3_button)
        end
        if self.right2_button then
            table.insert(row, self.right2_button)
        end
        if self.right1_button then
            table.insert(row, self.right1_button)
        end
        local layout = {}
        if #row > 0 then
            table.insert(layout, row)
        end
        return layout
    end

    TitleBar.generateVerticalLayout = function(self)
        local layout = {}
        if self.left1_button then
            table.insert(layout, { self.left1_button })
        end
        if self.left2_button then
            table.insert(layout, { self.left2_button })
        end
        if self.left3_button then
            table.insert(layout, { self.left3_button })
        end



        -- add extra left buttons here in ascending order:
        if self.left4_button then
            table.insert(layout, { self.left4_button })
        end
        -- stop adding
        if self.center_button then
            table.insert(layout, { self.center_button })
        end
        -- add extra right buttons here in descending order:
        if self.right4_button then
            table.insert(layout, { self.right4_button })
        end
        -- stop adding



        if self.right3_button then
            table.insert(layout, { self.right3_button })
        end
        if self.right2_button then
            table.insert(layout, { self.right2_button })
        end
        if self.right1_button then
            table.insert(layout, { self.right1_button })
        end
        return layout
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
