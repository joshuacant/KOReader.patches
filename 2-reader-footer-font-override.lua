--[[
    This user patch is primarily for use with the Project: Title plugin.
    
    It sets the "Status Bar" (Footer) font to the serif font used in the plugin.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local ReaderFooter = require("apps/reader/modules/readerfooter")
local _ReaderFooter_init_orig = ReaderFooter.init
ReaderFooter.init = function(self)
    self.text_font_face = "source/SourceSerif4-Regular.ttf"
    _ReaderFooter_init_orig(self)
    self.footer_text.fgcolor = Blitbuffer.COLOR_BLACK -- you could change the font color here, too
end
