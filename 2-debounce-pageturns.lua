--[[
    This user patch limits how quickly the physical page turn buttons on your device
    can be pressed. This is also known as debouncing. It can help with a device
    whose buttons are starting to wear out a little and a single physical press of
    the button is triggering multiple page turns. It could also help with someone
    who has a medical condition such as tremors and inadvertently presses the
    button down multiple times in rapid succession.

    Adjust the ratelimit value below to filter out all repeat presses that happen
    within that time. 
    
    The default value below is 0.33 which equals 330ms, 1/3rd of a second, 180bpm, 3Hz
    or however else you want to think about it!
--]]
local Device = require("device")
local logger = require("logger")

-- minimum time required between button presses, in fractions of a second
local ratelimit = 0.33

local _handleKeyBoardEv_orig = Device.input.handleKeyBoardEv
Device.input.handleKeyBoardEv = function(self, ev)
    -- filter only page turn events on the downpress
    if (ev.code == 193 or ev.code == 194) and ev.value == 1 then
        -- first event
        if not self._prev_ev then
            self._prev_ev = ev
            return _handleKeyBoardEv_orig(self, ev)
        -- all subsequent events
        else
            local prev_ev_time = self._prev_ev.time.sec + (self._prev_ev.time.usec / 1000000)
            local curr_ev_time = ev.time.sec + (ev.time.usec / 1000000)
            local tdelta = curr_ev_time - prev_ev_time
            self._prev_ev = ev
            -- debounce by limiting presses faster than the rate limit
            if (tdelta > ratelimit) then
                return _handleKeyBoardEv_orig(self, ev)
            end
        end
    -- all non-page turn events
    else
        return _handleKeyBoardEv_orig(self, ev)
    end
end
