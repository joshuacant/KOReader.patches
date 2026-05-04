--[[
    This user patch is primarily for use with the Project: Title plugin. It requires
    Project: Title v3.5 or higher.

    This patch converts series index numbers from Arabic to Roman numerals.

    This patch is meant to demonstrate how replacing the new formatAuthors, formatSeries,
    and formatAuthorSeries functions with your own can change the look of Cover List
    view without needing to modify the plugin itself.
--]]
local BD = require("ui/bidi")
local userpatch = require("userpatch")

local function patchCoverBrowser(plugin)
    local ptutil = require("ptutil")

    -- replace formatSeries so that this new function below is run instead
    function ptutil.formatSeries(series, series_index)
        local formatted_series = ""
        -- suppress series if index is "0"
        if series_index == 0 then
            return ""
        end
        -- if series is formated like "big series: small subseries" then show only "small subseries"
        if string.match(series, ": ") then
            series = string.sub(series, util.lastIndexOf(series, ": ") + 1, -1)
        end
        if series_index then
            formatted_series = "#" .. series_index .. ptutil.separator.en_dash .. BD.auto(series)
        else
            formatted_series = BD.auto(series)
        end
        return formatted_series
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
