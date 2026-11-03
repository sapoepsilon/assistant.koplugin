-- merged into /sdcard/koreader/settings.reader.lua by tools/kosettings.lua
local HOME = "/storage/emulated/0/Books/Inference"
return {
  -- dark everywhere
  night_mode = true,
  -- library
  home_dir = HOME,
  start_with = "last",          -- resume the last paper; library when nothing is open yet
  quickstart_shown_version = 300000000000,
  collate = "strcoll",
  reverse_collate = false,
  -- PDF defaults (two-column arXiv on the near-square inner screen)
  kopt_zoom_mode_genus = 3,     -- content (margins auto-trimmed)
  kopt_zoom_mode_type = 1,      -- width
  kopt_page_scroll = 1,         -- continuous scroll
  kopt_page_gap_height = 8,
  kopt_text_wrap = 0,
  kopt_zoom_overlap_h = 0,      -- column view: no bleed of the neighbouring column
  kopt_zoom_range_number = 2,   -- column view splits the page into 2 columns
  kopt_zoom_overlap_v = 12,
  -- selection -> popup with AI buttons, also for a single word
  default_highlight_action = "ask",
  highlight_action_on_single_word = true,
  highlight_dialog_position = "gesture",
  -- footer: page, %, time left in section, clock, battery
  footer = {
    book_chapter = true,
    book_chapter_max_width_pct = 40,
    chapter_time_to_read = true,
    book_time_to_read = false,
    pages_left = false,
    toc_markers = true,
  },
  -- plugins that only add menu noise on this phone
  plugins_disabled = {
    hello = true, japanese = true, perceptionexpander = true, newsdownloader = true,
    wallabag = true, calibre = true, opds = true, SSH = true, timesync = true,
    autoturn = true, coverimage = true, movetoarchive = true, qrclipboard = true,
    httpinspector = true, archiveviewer = true, kosync = true, vocabbuilder = true,
    autowarmth = true, batterystat = true, keepalive = true, autostandby = true,
  },
}
