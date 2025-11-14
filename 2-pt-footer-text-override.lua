--[[
    This user patch is primarily for use with the Project: Title plugin. It affects the folder
    name displayed in the footer of the file browser. It does not affect the footer/"Status Bar"
    when reading a book.

    It replaces underscores with spaces and moves the common English articles (the, a, an)
    from the end of the filename back to the start. e.g. A folder named "Frog_Bucket,_The"
    would appear as "The Frog Bucket".
--]]

local userpatch = require("userpatch")
local Menu = require("ui/widget/menu")
local function patchCoverBrowser(plugin)
    local orig_Menu_updatePageInfo = Menu.updatePageInfo
    Menu.updatePageInfo = function(self)
        orig_Menu_updatePageInfo(self)
        local display_path, _ = self.cur_folder_text:getFittedText()
        if display_path then
            -- fix underscores that were used for spaces
            display_path = display_path:gsub("_", " ")
            -- fix articles for titles that were changed for proper sorting
            local endings = { ', The', ', An', ', A' }
            for i, ending in ipairs(endings) do
                if display_path:match(ending) then
                    display_path = string.sub(ending, 3) .. " " .. string.sub(display_path, 1, ((string.len(ending) + 1) * -1))
                end
            end
            self.cur_folder_text:setText(display_path)
        end
    end
end
userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
