-- merged into /sdcard/koreader/settings/assistant.lua by tools/kosettings.lua
return {
  provider = "openai_proxycli_lan",
  auto_copy_asked_question = false,   -- no clipboard spam
  include_page_text = true,           -- send ±1 page of paper text with every selection
  prepend_book_metadata = true,       -- title/author/position of the paper
  use_stream_mode = true,
  stream_mode_auto_scroll = true,
  large_stream_dialog = true,
  auto_prompt_suggest = true,         -- follow-up question chips (only on Explain / Why / Page)
  show_reasoning = false,
  response_font_size = 19,
  use_websearch = "none",
  enable_auto_recap = false,
}
