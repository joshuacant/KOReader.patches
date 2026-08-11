--[[
    Redacted Screensaver Patch for KOReader.
    Works with EPUB, FB2, and other rolling documents.
    Original version by sparklerfish.

    Shows the current page with uncommon words covered by black "redaction" bars. Replace the word
    list at the bottom of this file with the words you DO NOT want censored. Everything else
    gets the black box treatment.

    Also blanks out the top and bottom of the page (to obscure header and footers) and draws black
    boxes where that information would have been.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local DocCache = require("document/doccache")
local Geom = require("ui/geometry")
local logger = require("logger")
local Screen = Device.screen
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local util = require("util")
local _ = require("gettext")

local RedactedScreensaverWidget = Widget:extend {
    ui = nil,
    document = nil,
    dimen = nil,
    redaction_boxes = nil,
}

local DEBUG = false
local WORDS_TO_SHOW = {}
local MAX_CACHED_BOXES = 500
local MAX_REDACTIONS = 999
local REDACTED_ENABLED_SETTING = "redactedscreensaver_enabled"
local REDACTION_PADDING_H = 2
local REDACTION_PADDING_V = 1
local MERGE_GAP_TOLERANCE = 15
local HEADER_HEIGHT = 60
local FOOTER_HEIGHT = 60
local HF_INSET = 16
local HF_BLOCK_HEIGHT = 38

function RedactedScreensaverWidget:init()
    self.dimen = Geom:new {
        x = 0,
        y = 0,
        w = Screen:getWidth(),
        h = Screen:getHeight(),
    }
    self.redaction_boxes = {}
    self:calculateRedactions()
end

function RedactedScreensaverWidget:groupBoxesByLine(boxes, tolerance)
    local lines = {}
    for _, box in ipairs(boxes) do
        local found_line = false
        for _, line in ipairs(lines) do
            if math.abs(line.y - box.y) <= tolerance then
                table.insert(line.boxes, box)
                found_line = true
                break
            end
        end
        if not found_line then
            table.insert(lines, {
                y = box.y,
                boxes = { box }
            })
        end
    end
    return lines
end

function RedactedScreensaverWidget:calculateLineTolerance()
    local default_tolerance = 5
    if self.ui and self.ui.font and self.ui.font.size then
        local font_size = self.ui.font.size
        return math.max(3, math.floor(font_size * 0.25))
    end
    if self.ui and self.ui.rolling and self.ui.rolling.font_size then
        local font_size = self.ui.rolling.font_size
        return math.max(3, math.floor(font_size * 0.25))
    end
    return default_tolerance
end

function RedactedScreensaverWidget:buildCacheKey()
    local doc_file = self.document.file
    if not doc_file then return nil end
    local page_id
    if self.ui.paging then
        page_id = self.ui:getCurrentPage()
    elseif self.ui.rolling then
        if self.ui.view and self.ui.view.state and self.ui.view.state.page then
            page_id = self.ui.view.state.page
        end
    end
    if not page_id then return nil end
    local font_size = 0
    if self.ui.rolling and self.ui.rolling.font_size then
        font_size = self.ui.rolling.font_size
    end
    local rotation = Screen:getRotationMode() or 0
    local cache_key = string.format("redacted_boxes|%s|%s|f%d|r%d",
        doc_file, tostring(page_id), font_size, rotation)
    return cache_key
end

function RedactedScreensaverWidget:calculateRedactions()
    if not self.ui then
        logger.warn("RedactedScreensaver: No UI available")
        return
    end
    if not self.document then
        logger.warn("RedactedScreensaver: No document available")
        return
    end
    if not self.ui.view then
        logger.warn("RedactedScreensaver: No view available")
        return
    end
    local cache_key = self:buildCacheKey()
    if not cache_key then return end
    local cached = DocCache:check(cache_key)
    local boxes = nil
    if cached and cached.boxes then
        boxes = cached.boxes
    else
        local ok, result = pcall(function()
            if self.ui.rolling then
                return self:getRollingDocumentBoxes()
            end
            return {}
        end)
        if ok and result then
            boxes = result
            if #boxes > MAX_CACHED_BOXES then
                logger.warn(string.format("RedactedScreensaver: Page has %d words, limiting cache to %d", #boxes,
                    MAX_CACHED_BOXES))
                local limited_boxes = {}
                for i = 1, MAX_CACHED_BOXES do
                    limited_boxes[i] = boxes[i]
                end
                boxes = limited_boxes
            end
            if #boxes > 0 then
                DocCache:insert(cache_key, {
                    boxes = boxes,
                    size = #boxes * 100,
                })
            end
        end
    end
    if boxes and #boxes > 0 then
        self:selectRandomRedactions(boxes)
    else
        logger.warn("RedactedScreensaver: No word boxes found")
    end
end

function RedactedScreensaverWidget:getRollingDocumentBoxes()
    local boxes = {}
    if not self.document then
        logger.warn("RedactedScreensaver: No document for rolling extraction")
        return boxes
    end
    -- Calculate adaptive grid step based on font size
    local font_size = 16 -- default fallback
    if self.ui.rolling and self.ui.rolling.font_size then
        font_size = self.ui.rolling.font_size
    end
    local step_x = math.max(60, math.floor(font_size * 3))
    local step_y = math.max(30, math.floor(font_size * 3))
    local seen_words = {}
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    for y = 0, screen_h, step_y do
        for x = 0, screen_w, step_x do
            local ok, word = pcall(self.document.getWordFromPosition, self.document, { x = x, y = y }, true)
            if ok and word and word.sbox then
                -- logger.info(word)
                local sbox = word.sbox
                local key = string.format("%.0f_%.0f_%.0f_%.0f", sbox.x or 0, sbox.y or 0, sbox.w or 0, sbox.h or 0)
                if not seen_words[key] and sbox.w and sbox.h and sbox.w > 0 and sbox.h > 0 then
                    seen_words[key] = true
                    table.insert(boxes, {
                        x = sbox.x,
                        y = sbox.y,
                        w = sbox.w,
                        h = sbox.h,
                        word = word.word or "",
                    })
                end
            end
        end
    end
    return boxes
end

function RedactedScreensaverWidget:selectRandomRedactions(boxes)
    if #boxes == 0 then return end
    -- Group boxes into lines based on Y coordinate
    local line_tolerance = self:calculateLineTolerance()
    local lines = self:groupBoxesByLine(boxes, line_tolerance)
    for _, line in ipairs(lines) do
        table.sort(line.boxes, function(a, b) return a.x < b.x end)
    end
    local redaction_count = 0
    local max_redactions = math.min(MAX_REDACTIONS, #boxes)
    for _, line in ipairs(lines) do
        if redaction_count >= max_redactions then
            break
        end
        local line_boxes = line.boxes
        if #line_boxes > 0 then
            local i = 1
            local redact_word
            local word
            while i <= #line_boxes and redaction_count < max_redactions do
                redact_word = false
                word = line_boxes[i].word or "a"
                -- redact all standalone numbers
                if word:gsub('[^%d]', ''):match("^%d+$") then
                    if DEBUG then logger.info("    redacted: number") end
                    redact_word = true
                else
                    -- convert word to lowercase, remove all non-letter characters
                    word = util.stringLower(word)
                    word = word:gsub('[^%l]', '')
                    -- ignore empty strings (isolated punctuation marks)
                    if word == "" then
                        if DEBUG then logger.info("not redacted: empty") end
                        redact_word = false
                        -- redact words not in the common word list
                    elseif not util.arrayContains(WORDS_TO_SHOW, word) then
                        if DEBUG then logger.info("    redacted: uncommon word") end
                        redact_word = true
                    else
                        if DEBUG then logger.info("not redacted: common word") end
                    end
                end
                if DEBUG then logger.info(string.format("'%s'", line_boxes[i].word)) end
                if DEBUG then logger.info(string.format("'%s'", word)) end
                -- add redaction box
                if redact_word then
                    for j = 0, 0 do
                        if i + j <= #line_boxes and redaction_count < max_redactions then
                            table.insert(self.redaction_boxes, line_boxes[i + j])
                            redaction_count = redaction_count + 1
                        end
                    end
                end
                i = i + 1
            end
        end
    end
    self:mergeConsecutiveRedactions()
end

function RedactedScreensaverWidget:mergeConsecutiveRedactions()
    if #self.redaction_boxes == 0 then return end
    -- Group redactions by line (similar Y coordinate)
    local line_tolerance = self:calculateLineTolerance()
    local lines = self:groupBoxesByLine(self.redaction_boxes, line_tolerance)
    local merged_boxes = {}
    for _, line in ipairs(lines) do
        table.sort(line.boxes, function(a, b) return a.x < b.x end)
        local i = 1
        while i <= #line.boxes do
            local current = line.boxes[i]
            local merge_box = {
                x = current.x,
                y = current.y,
                w = current.w,
                h = current.h,
            }
            local j = i + 1
            while j <= #line.boxes do
                local next_box = line.boxes[j]
                local gap = next_box.x - (merge_box.x + merge_box.w)
                if gap <= MERGE_GAP_TOLERANCE then
                    local right_edge = math.max(merge_box.x + merge_box.w, next_box.x + next_box.w)
                    merge_box.w = right_edge - merge_box.x
                    merge_box.h = math.max(merge_box.h, next_box.h)
                    j = j + 1
                else
                    break
                end
            end
            table.insert(merged_boxes, merge_box)
            i = j
        end
    end
    self.redaction_boxes = merged_boxes
end

function RedactedScreensaverWidget:blockHeaderFooter(bb)
    local bb_width = bb:getWidth()
    local bb_height = bb:getHeight()
    local header_height = HEADER_HEIGHT
    local footer_height = FOOTER_HEIGHT
    local header_block_width = math.floor((math.random(35, 40) / 100) * bb_width)
    local footer_block_width = math.floor((math.random(20, 25) / 100) * bb_width)
    local inset = HF_INSET
    local block_height = HF_BLOCK_HEIGHT
    bb:paintRect(0, 0, bb_width, header_height, Blitbuffer.COLOR_WHITE)
    bb:paintRect(0, (bb_height - footer_height), bb_width, footer_height, Blitbuffer.COLOR_WHITE)
    bb:paintRect(((bb_width / 2) - (header_block_width / 2)), (0 + inset), header_block_width, block_height, Blitbuffer.COLOR_BLACK)
    bb:paintRect(((bb_width / 2) - (footer_block_width / 2)), (bb_height - (block_height + inset)), footer_block_width, block_height, Blitbuffer.COLOR_BLACK)
end

function RedactedScreensaverWidget:paintTo(bb, x, y)
    local bb_width = bb:getWidth()
    local bb_height = bb:getHeight()
    for _, box in ipairs(self.redaction_boxes) do
        local rx = box.x - REDACTION_PADDING_H
        local ry = box.y - REDACTION_PADDING_V
        local rw = box.w + (REDACTION_PADDING_H * 2)
        local rh = box.h + (REDACTION_PADDING_V * 2)
        local x1 = math.max(0, rx)
        local y1 = math.max(0, ry)
        local x2 = math.min(bb_width, rx + rw)
        local y2 = math.min(bb_height, ry + rh)
        rw = x2 - x1
        rh = y2 - y1
        if rw > 0 and rh > 0 then
            bb:paintRect(x1, y1, rw, rh, Blitbuffer.COLOR_BLACK)
        end
    end
end

------------------------------------------------------------
-- Screensaver Module Patching
------------------------------------------------------------

local Screensaver = require("ui/screensaver")

-- Save current state to allow chaining with other screensaver patches
-- Use unique names to avoid conflicts with other patches
if not Screensaver._redacted_orig_setup then
    Screensaver._redacted_orig_setup = Screensaver.setup
    Screensaver._redacted_orig_show = Screensaver.show
    Screensaver._redacted_orig_cleanup = Screensaver.cleanup
    Screensaver._redacted_orig_modeExpectsPortrait = Screensaver.modeExpectsPortrait
end

local function shouldShowRedacted()
    -- Only use redacted if:
    -- 1. The toggle is enabled
    -- 2. We're currently in a rolling document (EPUB, FB2, etc.)
    -- 3. Not in a paged document (PDF, DjVu, etc.)
    local enabled = G_reader_settings:readSetting(REDACTED_ENABLED_SETTING) == true
    local ui = require("apps/reader/readerui").instance
    local in_rolling_document = ui and ui.document and ui.rolling and not ui.paging
    return enabled and in_rolling_document
end

Screensaver.setup = function(screensaver_self, event, event_message)
    Screensaver.setupWordlist()
    Screensaver._redacted_orig_setup(screensaver_self, event, event_message)
    if shouldShowRedacted() then
        -- logger.info("RedactedScreensaver: Activating redacted screensaver")
        screensaver_self.screensaver_type = "redacted"
    end
end



Screensaver.show = function(screensaver_self)
    if screensaver_self.screensaver_type ~= "redacted" then
        return Screensaver._redacted_orig_show(screensaver_self)
    end
    local ui = require("apps/reader/readerui").instance
    if not ui then return end
    Device.screen_saver_mode = true
    local redacted_widget = RedactedScreensaverWidget:new {
        ui = ui,
        document = ui.document,
    }
    if Screen.bb then
        local ok, err = pcall(redacted_widget.paintTo, redacted_widget, Screen.bb, 0, 0)
        if not ok then
            logger.err("RedactedScreensaver: Failed to paint redactions:", err)
        end
        pcall(redacted_widget.blockHeaderFooter, redacted_widget, Screen.bb)
    end
    local ScreenSaverWidget = require("ui/widget/screensaverwidget")
    local empty_widget = Widget:new {}
    empty_widget.dimen = Geom:new {
        x = 0,
        y = 0,
        w = Screen:getWidth(),
        h = Screen:getHeight(),
    }
    screensaver_self.screensaver_widget = ScreenSaverWidget:new {
        widget = empty_widget,
        background = nil, -- no background, keep existing screen content
        covers_fullscreen = true,
    }
    screensaver_self.screensaver_widget.modal = true
    UIManager:show(screensaver_self.screensaver_widget, "full")
    if Device:isTouchDevice() and
        G_reader_settings:readSetting("screensaver_delay") == "gesture" then
        local ScreenSaverLockWidget = require("ui/widget/screensaverlockwidget")
        screensaver_self.screensaver_lock_widget = ScreenSaverLockWidget:new {
            ui = ui,
        }
        UIManager:show(screensaver_self.screensaver_lock_widget)
    end
end

Screensaver.cleanup = function(screensaver_self)
    Screensaver._redacted_orig_cleanup(screensaver_self)
end

Screensaver.modeExpectsPortrait = function(screensaver_self)
    if screensaver_self.screensaver_type == "redacted" then
        return false -- Keep current orientation
    end
    return Screensaver._redacted_orig_modeExpectsPortrait(screensaver_self)
end

------------------------------------------------------------
-- Menu Injection
------------------------------------------------------------
local orig_dofile = dofile
_G.dofile = function(filepath)
    local result = orig_dofile(filepath)
    if filepath and filepath:match("screensaver_menu%.lua$") then
        if result and result[1] and result[1].sub_item_table then
            local wallpaper_submenu = result[1].sub_item_table
            for _, item in ipairs(wallpaper_submenu) do
                if item.text and type(item.text) == "string" and item.text:find("redacted") then
                    return result
                end
            end
            -- Insert our checkbox after the screensaver type options (position 7)
            table.insert(wallpaper_submenu, 7, {
                text = _("Use redacted screensaver when reading"),
                help_text = _(
                    "When enabled, shows the current page with random words blacked out like a redacted document while reading a book. This overrides the wallpaper setting above when in reader mode."),
                checked_func = function()
                    return G_reader_settings:isTrue(REDACTED_ENABLED_SETTING)
                end,
                callback = function()
                    G_reader_settings:flipNilOrFalse(REDACTED_ENABLED_SETTING)
                end,
                separator = true,
            })
            -- logger.info("RedactedScreensaver: Successfully injected menu item into screensaver settings")
        end
    end
    return result
end

Screensaver.setupWordlist = function()
    WORDS_TO_SHOW = {
        "re",
        "m",
        "ll",
        "d",
        "t",
        "s",
        "a",
        "about",
        "actually",
        "after",
        "again",
        "ah",
        "all",
        "always",
        "also",
        "am",
        "an",
        "and",
        "another",
        "any",
        "anything",
        "are",
        "around",
        "as",
        "ask",
        "asked",
        "asking",
        "asks",
        "at",
        "ate",
        "away",
        "babies",
        "baby",
        "back",
        "bad",
        "be",
        "because",
        "been",
        "before",
        "being",
        "believe",
        "believed",
        "believes",
        "believing",
        "best",
        "better",
        "big",
        "bigger",
        "biggest",
        "bought",
        "break",
        "breaking",
        "breaks",
        "bring",
        "bringing",
        "brings",
        "broke",
        "broken",
        "brought",
        "but",
        "buy",
        "buying",
        "buys",
        "by",
        "call",
        "called",
        "calling",
        "calls",
        "came",
        "can",
        "cannot",
        "car",
        "care",
        "cared",
        "cares",
        "caring",
        "cars",
        "change",
        "changed",
        "changes",
        "changing",
        "check",
        "checked",
        "checking",
        "checks",
        "child",
        "children",
        "come",
        "comes",
        "coming",
        "cool",
        "cooler",
        "coolest",
        "could",
        "course",
        "courses",
        "crazier",
        "craziest",
        "crazy",
        "dad",
        "dads",
        "day",
        "days",
        "did",
        "didn",
        "do",
        "don",
        "does",
        "dog",
        "dogs",
        "doing",
        "dollar",
        "dollars",
        "done",
        "down",
        "dying",
        "eat",
        "eaten",
        "eating",
        "eats",
        "else",
        "enough",
        "even",
        "ever",
        "every",
        "everybody",
        "everyone",
        "everything",
        "excuse",
        "excused",
        "excuses",
        "excusing",
        "families",
        "family",
        "feel",
        "feeling",
        "feels",
        "felt",
        "find",
        "finding",
        "finds",
        "fine",
        "finer",
        "finest",
        "first",
        "five",
        "fives",
        "for",
        "forget",
        "forgets",
        "forgetting",
        "forgot",
        "forgotten",
        "found",
        "friend",
        "friends",
        "from",
        "fun",
        "funnier",
        "funniest",
        "funny",
        "game",
        "games",
        "gave",
        "get",
        "gets",
        "getting",
        "give",
        "given",
        "gives",
        "giving",
        "go",
        "goes",
        "going",
        "gone",
        "good",
        "got",
        "gotten",
        "great",
        "greater",
        "greatest",
        "guess",
        "guessed",
        "guesses",
        "guessing",
        "guy",
        "guys",
        "had",
        "happen",
        "happened",
        "happening",
        "happens",
        "happier",
        "happiest",
        "happy",
        "hard",
        "harder",
        "hardest",
        "has",
        "hate",
        "hated",
        "hates",
        "hating",
        "have",
        "having",
        "head",
        "heads",
        "hear",
        "heard",
        "hearing",
        "hears",
        "held",
        "hell",
        "hello",
        "help",
        "helped",
        "helping",
        "helps",
        "her",
        "here",
        "hey",
        "hi",
        "his",
        "hm",
        "hmm",
        "hold",
        "holding",
        "holds",
        "home",
        "homes",
        "honey",
        "hot",
        "hotter",
        "hottest",
        "hour",
        "hours",
        "house",
        "houses",
        "how",
        "huh",
        "idea",
        "ideas",
        "i",
        "if",
        "in",
        "into",
        "is",
        "it",
        "job",
        "jobs",
        "just",
        "keep",
        "keeping",
        "keeps",
        "kept",
        "kid",
        "kids",
        "kill",
        "killed",
        "killing",
        "kills",
        "kind",
        "kinds",
        "knew",
        "know",
        "knowing",
        "known",
        "knows",
        "last",
        "lasted",
        "lasting",
        "lasts",
        "late",
        "later",
        "latest",
        "leave",
        "leaves",
        "leaving",
        "left",
        "let",
        "lets",
        "letting",
        "life",
        "like",
        "liked",
        "likes",
        "liking",
        "listen",
        "listened",
        "listening",
        "listens",
        "little",
        "live",
        "lived",
        "lives",
        "living",
        "long",
        "longer",
        "longest",
        "look",
        "looked",
        "looking",
        "looks",
        "lose",
        "loses",
        "losing",
        "lost",
        "lot",
        "lots",
        "love",
        "loved",
        "loves",
        "loving",
        "made",
        "make",
        "makes",
        "making",
        "man",
        "married",
        "marries",
        "marry",
        "marrying",
        "may",
        "maybe",
        "me",
        "mean",
        "meaning",
        "means",
        "meant",
        "meet",
        "meeting",
        "meets",
        "men",
        "met",
        "might",
        "mine",
        "minute",
        "minutes",
        "miss",
        "missed",
        "misses",
        "missing",
        "mom",
        "moms",
        "money",
        "more",
        "most",
        "mother",
        "mothers",
        "move",
        "moved",
        "moves",
        "movie",
        "movies",
        "moving",
        "much",
        "must",
        "my",
        "name",
        "names",
        "need",
        "needed",
        "needing",
        "needs",
        "never",
        "new",
        "newer",
        "newest",
        "nice",
        "nicer",
        "nicest",
        "night",
        "nights",
        "no",
        "not",
        "nothing",
        "now",
        "of",
        "off",
        "oh",
        "OK",
        "okay",
        "old",
        "older",
        "oldest",
        "on",
        "one",
        "ones",
        "only",
        "or",
        "other",
        "our",
        "out",
        "over",
        "own",
        "paid",
        "parties",
        "party",
        "pay",
        "paying",
        "pays",
        "people",
        "person",
        "persons",
        "pick",
        "picked",
        "picking",
        "picks",
        "place",
        "places",
        "play",
        "played",
        "playing",
        "plays",
        "please",
        "prettier",
        "prettiest",
        "pretty",
        "problem",
        "problems",
        "put",
        "puts",
        "putting",
        "ran",
        "readier",
        "readiest",
        "ready",
        "real",
        "really",
        "remember",
        "remembered",
        "remembering",
        "remembers",
        "right",
        "room",
        "rooms",
        "run",
        "running",
        "runs",
        "said",
        "same",
        "sameness",
        "sat",
        "saw",
        "say",
        "saying",
        "says",
        "school",
        "schools",
        "second",
        "see",
        "seeing",
        "seem",
        "seemed",
        "seeming",
        "seems",
        "seen",
        "sees",
        "shall",
        "should",
        "show",
        "showed",
        "showing",
        "shown",
        "shows",
        "sir",
        "sirs",
        "sit",
        "sits",
        "sitting",
        "so",
        "some",
        "someone",
        "something",
        "son",
        "sons",
        "sorry",
        "sound",
        "sounded",
        "sounding",
        "sounds",
        "start",
        "started",
        "starting",
        "starts",
        "stay",
        "stayed",
        "staying",
        "stays",
        "still",
        "stop",
        "stopped",
        "stopping",
        "stops",
        "stuff",
        "stupid",
        "stupider",
        "stupidest",
        "suppose",
        "supposed",
        "supposes",
        "supposing",
        "sure",
        "surer",
        "surest",
        "take",
        "taken",
        "takes",
        "taking",
        "talk",
        "talked",
        "talking",
        "talks",
        "tell",
        "telling",
        "tells",
        "than",
        "thank",
        "thanked",
        "thanking",
        "thanks",
        "that",
        "the",
        "their",
        "theirs",
        "then",
        "there",
        "these",
        "thing",
        "things",
        "think",
        "thinking",
        "thinks",
        "this",
        "those",
        "thought",
        "three",
        "threes",
        "through",
        "time",
        "times",
        "to",
        "today",
        "together",
        "told",
        "tonight",
        "too",
        "took",
        "tried",
        "tries",
        "try",
        "trying",
        "turn",
        "turned",
        "turning",
        "turns",
        "two",
        "twos",
        "uh",
        "um",
        "understand",
        "understanding",
        "understands",
        "understood",
        "up",
        "us",
        "use",
        "used",
        "uses",
        "using",
        "very",
        "wait",
        "waited",
        "waiting",
        "waits",
        "want",
        "wanted",
        "wanting",
        "wants",
        "was",
        "watch",
        "watched",
        "watches",
        "watching",
        "way",
        "ways",
        "we",
        "wear",
        "wearing",
        "wears",
        "week",
        "weeks",
        "well",
        "went",
        "were",
        "what",
        "when",
        "where",
        "which",
        "who",
        "whoa",
        "whole",
        "why",
        "will",
        "willing",
        "with",
        "woman",
        "women",
        "won",
        "word",
        "words",
        "wore",
        "work",
        "worked",
        "working",
        "works",
        "world",
        "worlds",
        "worn",
        "worried",
        "worries",
        "worry",
        "worrying",
        "worse",
        "worst",
        "would",
        "wow",
        "wrong",
        "yeah",
        "year",
        "years",
        "yes",
        "you",
        "your",
        "yours",
        "yourself",
        "yourselves",
    }
end
