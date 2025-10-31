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
        local arabic = {
            { roman = 'M',  decimal = 1000 },
            { roman = 'CM', decimal = 900 },
            { roman = 'D',  decimal = 500 },
            { roman = 'CD', decimal = 400 },
            { roman = 'C',  decimal = 100 },
            { roman = 'XC', decimal = 90 },
            { roman = 'L',  decimal = 50 },
            { roman = 'XL', decimal = 40 },
            { roman = 'X',  decimal = 10 },
            { roman = 'IX', decimal = 9 },
            { roman = 'V',  decimal = 5 },
            { roman = 'IV', decimal = 4 },
            { roman = 'I',  decimal = 1 },
        }

        local function conv_to_roman(index)
            if type(index) ~= "number" then return "" end
            for _, numeral in ipairs(arabic) do
                if index >= numeral.decimal then
                    return numeral.roman .. (conv_to_roman(index - numeral.decimal) or "")
                end
            end
        end

        local formatted_series = ""
        if series_index and series_index > 0 then
            local roman_index = conv_to_roman(series_index)
            formatted_series = BD.auto(series) .. " " .. roman_index
        else
            formatted_series = BD.auto(series)
        end
        return formatted_series
    end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
