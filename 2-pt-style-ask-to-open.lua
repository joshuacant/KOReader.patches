--[[
    This user patch is primarily for use with the Project: Title plugin.

    It replaces the stock "ask to open file" dialog with one that fits the PT UI better.
--]]

local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local UIManager = require("ui/uimanager")
local ConfirmBox = require("ui/widget/confirmbox")
local TextBoxWidget = require("ui/widget/textboxwidget")
local ImageWidget = require("ui/widget/imagewidget")
local ReaderUI = require("apps/reader/readerui")
local Size = require("ui/size")
local Screen = require("device").screen
local Font = require("ui/font")
local logger = require("logger")
local _ = require("gettext")
local userpatch = require("userpatch")

local icon_file = "book.opened"
-- local icon_file = "blank"

local function patchCoverBrowser(plugin)
    local BookInfoManager = require("bookinfomanager")
    local ptutil = require("ptutil")

    local _orig_showReaderCoroutine = ReaderUI.showReaderCoroutine
    ReaderUI.showReaderCoroutine = function(self, file, provider, seamless)
        return _orig_showReaderCoroutine(self, file, provider, true)
    end

    local _orig_openFile = filemanagerutil.openFile
    filemanagerutil.openFile = function(ui, file, caller_pre_callback, no_dialog)
        local openFile = function()
            if caller_pre_callback then
                caller_pre_callback()
            end
            if ui.document then -- Reader
                if ui.document.file ~= file then
                    local DocumentRegistry = require("document/documentregistry")
                    local provider, is_provider_forced = DocumentRegistry:getProvider(file, true) -- include auxiliary
                    if provider and provider.order then                                           -- auxiliary
                        -- keep the currently opened document, open the file over Reader
                        if provider.callback then                                                 -- module
                            provider.callback(file)
                        else                                                                      -- plugin
                            ui[provider.provider]:openFile(file)
                        end
                    else -- document
                        ui:switchDocument(file, nil, nil, provider, is_provider_forced)
                    end
                end
            else -- FM
                ui:openFile(file)
            end
        end

        if not no_dialog and G_reader_settings:isTrue("file_ask_to_open") then
            local confirm_box = ConfirmBox:new {
                text = "",
                face = Font:getFace("smallffont"),
                icon = icon_file,
                ok_text = _("Open"),
                ok_callback = openFile,
            }

            local book_title
            local book_series
            local book_author
            local book_filename
            local bookinfo = BookInfoManager:getBookInfo(file, true)
            if bookinfo then
                local DGENERIC_ICON_SIZE = G_defaults:readSetting("DGENERIC_ICON_SIZE")
                local box_width = confirm_box:getAddedWidgetAvailableWidth()
                local box_width_safe = math.floor((box_width - Screen:scaleBySize(DGENERIC_ICON_SIZE) - Size.span.horizontal_default) * 0.96)
                if bookinfo.has_cover and not bookinfo.ignore_cover then
                    local cover_max_width = math.floor(box_width_safe * 0.75)
                    local cover_max_height = math.floor(Screen:getHeight() * 0.75)
                    local _, _, scale_factor = BookInfoManager.getCachedCoverSize(
                        bookinfo.cover_w, bookinfo.cover_h,
                        cover_max_width, cover_max_height
                    )
                    local cover_image = ImageWidget:new {
                        image = bookinfo.cover_bb,
                        scale_factor = scale_factor,
                    }
                    local cover_box = HorizontalGroup:new {
                        HorizontalSpan:new {
                            width = math.floor((box_width_safe - cover_image:getSize().w) / 2),
                        },
                        cover_image,
                    }
                    confirm_box:addWidget(cover_box)
                end
                if bookinfo.title then
                    book_title = bookinfo.title or ""
                    local title_box = TextBoxWidget:new {
                        text = book_title,
                        face = Font:getFace(ptutil.title_serif, 26),
                        alignment = "center",
                        width = box_width_safe,
                        parent = confirm_box,
                    }
                    confirm_box:addWidget(title_box)
                end
                if bookinfo.series and bookinfo.series_index then
                    book_series = ptutil.formatSeries(bookinfo.series, bookinfo.series_index) or ""
                    local series_box = TextBoxWidget:new {
                        text = book_series,
                        face = Font:getFace(ptutil.good_serif, 22),
                        fgcolor = Blitbuffer.COLOR_GRAY_2,
                        alignment = "center",
                        width = box_width_safe,
                        parent = confirm_box,
                    }
                    confirm_box:addWidget(series_box)
                end
                if bookinfo.authors then
                    book_author = ptutil.formatAuthors(bookinfo.authors, 1) or ""
                    local author_box = TextBoxWidget:new {
                        text = book_author,
                        face = Font:getFace(ptutil.good_serif, 22),
                        fgcolor = Blitbuffer.COLOR_GRAY_2,
                        alignment = "center",
                        width = box_width_safe,
                        parent = confirm_box,
                    }
                    confirm_box:addWidget(author_box)
                end
            else
                book_filename = BD.filename(file:match("([^/]+)$"))
                local filename_box = TextBoxWidget:new {
                    text = book_filename,
                    face = Font:getFace(ptutil.good_sans, 26),
                    parent = confirm_box,
                }
                confirm_box:addWidget(filename_box)
            end
            UIManager:show(confirm_box)
        else
            openFile()
        end
    end
end

userpatch.registerPatchPluginFunc("projecttitle", patchCoverBrowser)
