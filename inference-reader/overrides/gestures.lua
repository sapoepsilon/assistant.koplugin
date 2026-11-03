-- merged into /sdcard/koreader/settings/gestures.lua by tools/kosettings.lua
local reader_quickmenu = {
  __replace = true,
  ai_explain_page = true,
  ir_ai_ask = true,
  ai_cycle_provider = true,
  ir_layout_inner = true,
  ir_layout_columns = true,
  ir_layout_page = true,
  ir_toggle_figures = true,
  ir_night_mode = true,
  ir_contents = true,
  ir_prev_paper = true,
  ir_next_paper = true,
  ir_library = true,
  settings = {
    show_as_quickmenu = true,
    order = {
      "ai_explain_page", "ir_ai_ask", "ai_cycle_provider",
      "ir_layout_inner", "ir_layout_columns", "ir_layout_page", "ir_toggle_figures", "ir_night_mode",
      "ir_contents", "ir_prev_paper", "ir_next_paper", "ir_library",
    },
    quickmenu_separators = { ai_cycle_provider = true, ir_night_mode = true },
  },
}
return {
  gesture_reader = {
    -- top-left corner tap: the reader quick menu (was: toggle page flipping)
    tap_top_left_corner = reader_quickmenu,
    -- two-finger tap anywhere-ish corners as a backup trigger
    two_finger_tap_top_left_corner = reader_quickmenu,
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
