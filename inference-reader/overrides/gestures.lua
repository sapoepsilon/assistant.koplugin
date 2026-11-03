-- merged into /sdcard/koreader/settings/gestures.lua by tools/kosettings.lua
-- Quick menu (tap top-left corner), grouped:
--   AI | zoom | find your way (contents, go to, search, bookmarks) | display | papers
-- ir_* actions come from koreader/patches/2-inference-reader.lua, the rest are stock
-- KOReader dispatcher actions (renamed below via quickmenu_action_names).
-- No rotation item: KOReader has no G-sensor on Android (lock_gsensor is hidden) and
-- the inner screen ignores app orientation requests (iterate_rotation did nothing).
-- A function, so each gesture gets its own copy (kosettings.lua consumes __replace).
local function reader_quickmenu() return {
  __replace = true,
  ai_explain_page = true,
  ir_ai_ask = true,
  ai_cycle_provider = true,
  ir_zoom_in = true,
  ir_zoom_out = true,
  ir_layout_inner = true,
  ir_layout_page = true,
  ir_layout_columns = true,
  ir_contents = true,
  go_to = true,
  fulltext_search = true,
  toggle_bookmark = true,
  bookmarks = true,
  ir_night_mode = true,
  ir_toggle_figures = true,
  show_frontlight_dialog = true,
  show_config_menu = true,
  ir_prev_paper = true,
  ir_next_paper = true,
  ir_library = true,
  settings = {
    show_as_quickmenu = true,
    order = {
      "ai_explain_page", "ir_ai_ask", "ai_cycle_provider",
      "ir_zoom_in", "ir_zoom_out", "ir_layout_inner", "ir_layout_page", "ir_layout_columns",
      "ir_contents", "go_to", "fulltext_search", "toggle_bookmark", "bookmarks",
      "ir_night_mode", "ir_toggle_figures", "show_frontlight_dialog", "show_config_menu",
      "ir_prev_paper", "ir_next_paper", "ir_library",
    },
    quickmenu_separators = {
      ai_cycle_provider = true, ir_layout_columns = true, bookmarks = true, show_config_menu = true,
    },
    quickmenu_action_names = {
      go_to = "Go to page…",
      fulltext_search = "Search in document…",
      toggle_bookmark = "Bookmark this page (on / off)",
      bookmarks = "Bookmarks & highlights",
      show_frontlight_dialog = "Brightness…",
      show_config_menu = "More reader settings…",
    },
  },
} end
return {
  gesture_reader = {
    -- top-left corner tap: the reader quick menu (was: toggle page flipping)
    tap_top_left_corner = reader_quickmenu(),
    -- two-finger tap anywhere-ish corners as a backup trigger
    two_finger_tap_top_left_corner = reader_quickmenu(),
    -- spread / pinch: zoom in / out (PDF: fit page <-> fit width <-> magnified;
    -- EPUB: font size). Stock binds them to font size only, which does nothing in a PDF.
    spread_gesture = { __replace = true, ir_zoom_in = true },
    pinch_gesture = { __replace = true, ir_zoom_out = true },
    -- bottom-left corner: night mode (was: frontlight toggle, which on Android just jumps brightness)
    tap_left_bottom_corner = { __replace = true, night_mode = true },
    -- hold bottom-left corner: AI explain this page
    hold_bottom_left_corner = { __replace = true, ai_explain_page = true },
    -- hold bottom-right corner: ask the AI anything
    hold_bottom_right_corner = { __replace = true, ai_ask_question = true },
    -- multiswipe right-left-right: next paper in folder; left-right-left: previous paper
    multiswipe_east_west_east = { __replace = true, ir_next_paper = true },
    multiswipe_west_east_west = { __replace = true, ir_prev_paper = true },
    -- toggle_reflow stays on the south-east L swipe
  },
  gesture_fm = {
    -- (the FM title bar owns the top-left corner, so no quick menu there)
    tap_top_left_corner = "__DELETE__",
    tap_left_bottom_corner = { __replace = true, night_mode = true },
  },
}
