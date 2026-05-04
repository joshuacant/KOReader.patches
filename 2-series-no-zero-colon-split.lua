--[[
    This user patch is primarily for use with the Project: Title plugin. It requires
    Project: Title v3.5 or higher.

    This patch alters the series by doing the following:
        If the series index is 0, it is supressed entirely.
        If the series string has one or more colons, split on them and show only the
         substring that's furthest to the right.

    Otherwise the series and index are presented as they are in the metadata.
--]]
local BD = require("ui/bidi")
local util = require("util")
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
