-- feature/inference_reader.lua
-- Local customization ("Inference reader" setup for the Pixel Fold):
--   * ai_explain_page   - one action/gesture: explain the page you are on
--   * ai_cycle_provider - flip between the configured providers (LAN / Tailscale)
-- Registered from main.lua; prompts live in configuration.lua (explain_page).

local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Notification = require("ui/widget/notification")
local Trapper = require("ui/trapper")
local Dispatcher = require("dispatcher")
local NetUtils = require("utils/net")
local TextUtils = require("utils/text")
local logger = require("logger")
local _ = require("core/gettext")

local M = {}

function M.registerActions()
  Dispatcher:registerAction("ai_explain_page", {
    category = "none",
    event = "AskAIExplainPage",
    title = _("AI: explain this page"),
    reader = true,
  })
  Dispatcher:registerAction("ai_cycle_provider", {
    category = "none",
    event = "AskAICycleProvider",
    title = _("AI: switch provider (LAN / Tailscale)"),
    general = true,
  })
end

local function currentPageText(ui, max_chars)
  local doc = ui.document
  local text = ""
  local ok, err = pcall(function()
    if doc.info and doc.info.has_pages then
      local page = (ui.paging and ui.paging.current_page) or doc:getCurrentPage()
      text = TextUtils.pageTextToString(doc:getPageText(page)) or ""
    else
      local xp = doc:getXPointer()
      local page = doc:getCurrentPage()
      local total = doc:getPageCount()
      local xp_start = doc:getPageXPointer(page)
      local xp_end = doc:getPageXPointer(math.min(total, page + 1))
      text = doc:getTextFromXPointers(xp_start, xp_end) or ""
      doc:gotoXPointer(xp)
    end
  end)
  if not ok then
    logger.warn("inference_reader: page text extraction failed", err)
    return ""
  end
  text = text:gsub("[ \t]+", " "):gsub("\n%s*\n%s*\n+", "\n\n")
  if max_chars and #text > max_chars then
    text = TextUtils.truncateToHeadUtf8Safe(text, max_chars)
  end
  return text
end

function M.explainPage(assistant)
  if not assistant.ui or not assistant.ui.document then return end
  if not assistant:isConfigured() then return end
  local max_chars = assistant.config:getFeature("max_page_context_chars", 6000) * 2
  local text = currentPageText(assistant.ui, max_chars)
  if text == "" or not text:find("%w") then
    UIManager:show(InfoMessage:new{
      text = _("No selectable text on this page (scanned image?)."),
      timeout = 3,
    })
    return true
  end
  NetUtils.runWhenOnlineFast(function()
    Trapper:wrap(function()
      if not assistant.assistant_dialog then return end
      assistant.assistant_dialog:runPrompt(text, "explain_page")
    end)
  end)
  return true
end

function M.cycleProvider(assistant)
  if not assistant.config or not assistant.querier then
    assistant:isConfigured()
    return true
  end
  local ids = {}
  for id, rec in pairs(assistant.config:getProviderSettings()) do
    if type(rec) == "table" and rec.visible ~= false and assistant.config:isProviderEnabled(id) then
      table.insert(ids, id)
    end
  end
  table.sort(ids)
  if #ids < 2 then
    UIManager:show(Notification:new{ text = _("Only one AI provider configured.") })
    return true
  end
  local current = assistant.settings:readSetting("provider")
  local nxt = ids[1]
  for i, id in ipairs(ids) do
    if id == current then nxt = ids[i % #ids + 1] break end
  end
  local ok, err = assistant.querier:load_model(nxt)
  if not ok then
    UIManager:show(InfoMessage:new{ icon = "notice-warning", text = tostring(err) })
    return true
  end
  assistant.settings:saveSetting("provider", nxt)
  assistant.updated = true
  local rec = assistant.config:getProvider(nxt) or {}
  UIManager:show(Notification:new{
    text = string.format(_("AI provider: %s"), rec.display_name or nxt),
  })
  return true
end

return M
