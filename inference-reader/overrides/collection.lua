-- written to /sdcard/koreader/settings/collection.lua (new file)
local H = "/storage/emulated/0/Books/Inference"
return {
  ["favorites"] = { settings = { order = 1 } },
  ["Inference reading list"] = {
    settings = { order = 2, collate = "strcoll",
      folders = { [H] = { subfolders = false, scan_on_show = true } } },
  },
  ["DeepSeek"] = {
    settings = { order = 3, collate = "strcoll",
      folders = { [H .. "/DeepSeek"] = { subfolders = false, scan_on_show = true } } },
  },
}
