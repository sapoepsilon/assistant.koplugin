--[[
Inference reader user patch (Pixel 9 Pro Fold, KOReader 2026.07.x)

1. AI-first highlight popup: the assistant.koplugin buttons (Explain, Simplify,
   Why it matters, Define terms) come first, in bold, without the "(AI)" suffix;
   "AI Assistant" becomes "Ask AI…"; Wikipedia / Dictionary / Translate /
   View HTML / User dictionary are dropped. Dialog width is capped so it does
   not span the whole inner screen.
2. Layout actions for gestures / quick menu:
     ir_layout_inner    content width + continuous scroll (default, inner screen)
     ir_layout_columns  zoom to one column at a time + page view (cover screen)
     ir_layout_page     whole page + page view (figures, tables)
     ir_toggle_figures  invert the document back so figures keep true colours
   Zoom actions (also bound to spread / pinch):
     ir_zoom_in         PDF: fit page -> fit width -> magnify x1.25 (page view,
                        tap the edges to move across the page); EPUB: bigger text
     ir_zoom_out        the same ladder backwards; EPUB: smaller text
3. Fold awareness: when the screen becomes narrow (cover screen) a PDF switches
   to column view; when it becomes wide again, column view goes back to
   content width. Only touches paged documents (PDF/DjVu).

Everything is wrapped in pcall so a failure falls back to stock behaviour.
Disable by deleting this file (or Tools > Patch management).
]]

local logger = require("logger")

local ok_all, err_all = pcall(function()

local Dispatcher = require("dispatcher")
local Event = require("ui/event")
local Notification = require("ui/widget/notification")
local ReaderHighlight = require("apps/reader/modules/readerhighlight")
local ReaderUI = require("apps/reader/readerui")
local ButtonDialog = require("ui/widget/buttondialog")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen

-------------------------------------------------------------------------------
-- 1. Highlight popup
-------------------------------------------------------------------------------
local HIDDEN = {
    ["05_wikipedia"] = true,
    ["06_dictionary"] = true,
    ["07_translate"] = true,
    ["09_view_html"] = true,
    ["10_user_dict"] = true,
}

local orig_onShowHighlightMenu = ReaderHighlight.onShowHighlightMenu

-- After an AI button fires (the plugin has already read the selection), close the
-- popup so the answer isn't followed by the same popup again. The selection stays
-- highlighted until the next tap, like after "Copy".
local function closeAfter(self, b)
    local cb = b.callback
    if not cb then return end
    b.callback = function()
        local dlg = self.highlight_dialog
        cb()
        if dlg then
            UIManager:close(dlg)
            if self.highlight_dialog == dlg then self.highlight_dialog = nil end
        end
    end
end

local function buildRows(self, index)
    local keys = {}
    for k in pairs(self._highlight_buttons) do keys[#keys + 1] = k end
    table.sort(keys)
    local ai, rest, ask = {}, {}, nil
    for _, k in ipairs(keys) do
        if not HIDDEN[k] then
            local b = self._highlight_buttons[k](self, index)
            if b and (not b.show_in_highlight_dialog_func or b.show_in_highlight_dialog_func()) then
                if k == "ai_assistant" then
                    b.text = "Ask AI…"
                    closeAfter(self, b)
                    ask = b
                elseif k:match("^assistant_") then
                    b.text = (b.text or ""):gsub(" %(AI%)$", "")
                    b.font_bold = true
                    closeAfter(self, b)
                    table.insert(ai, b)
                else
                    table.insert(rest, b)
                end
            end
        end
    end
    local rows = {}
    for i = 1, #ai, 2 do
        rows[#rows + 1] = ai[i + 1] and { ai[i], ai[i + 1] } or { ai[i] }
    end
    if ask then
        rows[#rows + 1] = { ask }
    end
    for i = 1, #rest, 3 do
        local row = {}
        for j = i, math.min(i + 2, #rest) do row[#row + 1] = rest[j] end
        rows[#rows + 1] = row
    end
    return rows
end

function ReaderHighlight:onShowHighlightMenu(index)
    if not self.selected_text then return end
    local ok, rows = pcall(buildRows, self, index)
    if not ok or #rows == 0 then
        logger.warn("inference-reader: highlight menu fallback", rows)
        return orig_onShowHighlightMenu(self, index)
    end
    local min_side = math.min(Screen:getWidth(), Screen:getHeight())
    self.highlight_dialog = ButtonDialog:new{
        buttons = rows,
        width = math.min(math.floor(min_side * 0.9), Screen:scaleBySize(480)),
        anchor = function()
            return self:_getDialogAnchor(self.highlight_dialog, index)
        end,
        tap_close_callback = function()
            if self.hold_pos then
                self:clear()
            end
        end,
    }
    UIManager:show(self.highlight_dialog, "[ui]")
    return true
end

-------------------------------------------------------------------------------
-- 2. Layout actions
-------------------------------------------------------------------------------
Dispatcher:registerAction("ir_layout_inner", {
    category = "none", event = "IRLayout", arg = "inner",
    title = "Zoom: fit width (scroll)", paging = true,
})
Dispatcher:registerAction("ir_layout_columns", {
    category = "none", event = "IRLayout", arg = "columns",
    title = "Zoom: one column at a time", paging = true,
})
Dispatcher:registerAction("ir_layout_page", {
    category = "none", event = "IRLayout", arg = "page",
    title = "Zoom: fit page", paging = true,
})
Dispatcher:registerAction("ir_toggle_figures", {
    category = "none", event = "IRToggleFigures",
    title = "Figures: true colours / dark", paging = true,
})

-- Short, consistent names for the quick menu (aliases of stock/plugin events).
Dispatcher:registerAction("ir_ai_ask", {
    category = "none", event = "AskAIQuestion", title = "AI: ask a question", reader = true,
})
Dispatcher:registerAction("ir_night_mode", {
    category = "none", event = "ToggleNightMode", title = "Night mode on / off", general = true,
})
Dispatcher:registerAction("ir_contents", {
    category = "none", event = "ShowToc", title = "Contents", reader = true,
})
Dispatcher:registerAction("ir_prev_paper", {
    category = "none", event = "OpenNextOrPreviousFileInFolder", arg = true,
    title = "Previous paper", general = true,
})
Dispatcher:registerAction("ir_next_paper", {
    category = "none", event = "OpenNextOrPreviousFileInFolder",
    title = "Next paper", general = true,
})
Dispatcher:registerAction("ir_library", {
    category = "none", event = "Home", title = "Library", general = true,
})

local LAYOUT_NAMES = {
    inner = "Fit width · scroll",
    columns = "One column at a time",
    page = "Fit page",
}

local function applyLayout(ui, which, quiet)
    if not ui.paging or not ui.zooming then return end
    local conf = ui.document.configurable
    if which == "columns" then
        -- columns need page view; set it first to avoid the scroll-mode warning
        if ui.view.page_scroll then ui:handleEvent(Event:new("SetScrollMode", false)) end
        conf.page_scroll = 0
        conf.zoom_overlap_h = 0
        ui:handleEvent(Event:new("SetZoomMode", "columns"))
    elseif which == "page" then
        if ui.view.page_scroll then ui:handleEvent(Event:new("SetScrollMode", false)) end
        conf.page_scroll = 0
        ui:handleEvent(Event:new("SetZoomMode", "page"))
    else
        ui:handleEvent(Event:new("SetZoomMode", "contentwidth"))
        if not ui.view.page_scroll then
            conf.page_scroll = 1
            ui:handleEvent(Event:new("SetScrollMode", true))
        end
    end
    UIManager:setDirty(ui.dialog or ui, "full")
    if not quiet then
        UIManager:show(Notification:new{ text = LAYOUT_NAMES[which] or which })
    end
end

function ReaderUI:onIRLayout(which)
    local ok, err = pcall(applyLayout, self, which)
    if not ok then logger.warn("inference-reader: layout failed", err) end
    return true
end

function ReaderUI:onIRToggleFigures()
    if not self.paging then return true end
    local ok, err = pcall(function()
        local new = self.document.configurable.nightmode_document == 1 and 0 or 1
        self:handleEvent(Event:new("ConfigChange", "nightmode_document", new))
        self.document.configurable.nightmode_document = new
        UIManager:setDirty(self.dialog or self, "full")
        UIManager:show(Notification:new{
            text = new == 1 and "Figures: true colours" or "Figures: dark",
        })
    end)
    if not ok then logger.warn("inference-reader: figure toggle failed", err) end
    return true
end

-- Zoom in / out. category "arg": from the quick menu the event gets nil, from a
-- spread / pinch gesture it gets the gesture (its distance sets the step).
Dispatcher:registerAction("ir_zoom_in", {
    category = "arg", event = "IRZoom", arg = "in", title = "Zoom in", reader = true,
})
Dispatcher:registerAction("ir_zoom_out", {
    category = "arg", event = "IRZoom", arg = "out", title = "Zoom out", reader = true,
})

local ZOOM_STEP, ZOOM_MAX = 1.25, 6

local function pinchGesture(arg)
    if type(arg) == "table" and (arg.ges == "spread" or arg.ges == "pinch") then return arg end
end

local function zoomBy(ui, arg)
    local ges = pinchGesture(arg)
    local zoom_in
    if ges then zoom_in = ges.ges == "spread" else zoom_in = arg ~= "out" end
    if ui.rolling then
        -- reflowable (EPUB/HTML): zoom = font size; a gesture scales with its distance
        ui:handleEvent(Event:new(zoom_in and "IncreaseFontSize" or "DecreaseFontSize", ges or 1))
        return
    end
    if not ui.paging or not ui.zooming then return end
    local z = ui.zooming
    -- current zoom in units of content width (1 = fit width, <1 = whole page visible)
    local cur = z:getNumberOf("columns")
    local step = ZOOM_STEP
    if ges and ges.distance then
        local side = math.min(Screen:getWidth(), Screen:getHeight())
        step = math.max(1.1, math.min(2.5, 1 + ges.distance / (side * 0.5)))
    end
    if zoom_in and cur < 0.98 then
        return applyLayout(ui, "inner")
    elseif not zoom_in and cur <= 1.02 then
        return applyLayout(ui, "page")
    end
    local new = zoom_in and math.min(cur * step, ZOOM_MAX) or cur / step
    -- (snap: a step that would land just above 100% goes straight back to fit width)
    if not zoom_in and new < 1.12 then
        return applyLayout(ui, "inner")
    end
    -- magnified: page view (continuous view cannot pan sideways), manual zoom factor
    if ui.view.page_scroll then ui:handleEvent(Event:new("SetScrollMode", false)) end
    ui.document.configurable.page_scroll = 0
    ui:handleEvent(Event:new("SetZoomPan", { kopt_zoom_factor = new }, true))
    ui:handleEvent(Event:new("SetZoomMode", "manual"))
    z:setZoom()
    ui:handleEvent(Event:new("RedrawCurrentPage"))
    UIManager:setDirty(ui.dialog or ui, "full")
    UIManager:show(Notification:new{
        text = ("Zoom %d%% · tap the edges to move"):format(math.floor(new * 100 + 0.5)),
    })
end

function ReaderUI:onIRZoom(arg)
    local ok, err = pcall(zoomBy, self, arg)
    if not ok then logger.warn("inference-reader: zoom failed", err) end
    return true
end

-------------------------------------------------------------------------------
-- 3. Fold awareness
-------------------------------------------------------------------------------
local function isNarrow(w, h)
    return w and h and w < h * 0.62
end

local function autoLayout(ui, w, h)
    if not ui.paging or not ui.zooming or not ui.document then return end
    local mode = ui.zooming.zoom_mode
    if isNarrow(w, h) then
        if mode ~= "columns" then applyLayout(ui, "columns", true) end
    elseif mode == "columns" then
        applyLayout(ui, "inner", true)
    end
end

local orig_onScreenResize = ReaderUI.onScreenResize
function ReaderUI:onScreenResize(dimen)
    local ret = orig_onScreenResize and orig_onScreenResize(self, dimen)
    local ui = self
    UIManager:nextTick(function()
        local ok, err = pcall(autoLayout, ui, Screen:getWidth(), Screen:getHeight())
        if not ok then logger.warn("inference-reader: auto layout failed", err) end
    end)
    return ret
end

local orig_onReaderReady = ReaderUI.onReaderReady
function ReaderUI:onReaderReady(...)
    local ret
    if orig_onReaderReady then ret = orig_onReaderReady(self, ...) end
    if isNarrow(Screen:getWidth(), Screen:getHeight()) then
        local ui = self
        UIManager:nextTick(function()
            local ok, err = pcall(autoLayout, ui, Screen:getWidth(), Screen:getHeight())
            if not ok then logger.warn("inference-reader: auto layout failed", err) end
        end)
    end
    return ret
end

end)

if not ok_all then
    logger.warn("inference-reader patch failed to load:", err_all)
end
