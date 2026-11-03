-- luajit kosettings.lua <in.lua> <overrides.lua> <out.lua> [header-path]
-- Deep-merges the table returned by overrides.lua into the KOReader settings
-- file in.lua and writes a KOReader-style dump to out.lua.
-- In overrides, the string "__DELETE__" removes a key; a table with
-- __replace = true replaces instead of merging.
local inp, ovr, outp, header = arg[1], arg[2], arg[3], arg[4]
local base = {}
local f = io.open(inp, "r")
if f then f:close(); base = dofile(inp) or {} end
local over = dofile(ovr)

local function merge(dst, src)
  for k, v in pairs(src) do
    if v == "__DELETE__" then
      dst[k] = nil
    elseif type(v) == "table" and v.__replace then
      v.__replace = nil
      dst[k] = v
    elseif type(v) == "table" and type(dst[k]) == "table" then
      merge(dst[k], v)
    else
      dst[k] = v
    end
  end
  return dst
end
merge(base, over)

local function keycmp(a, b)
  local ta, tb = type(a), type(b)
  if ta == tb then return a < b end
  return ta == "number"
end
local function opairs(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, keycmp)
  local i = 0
  return function() i = i + 1; local k = keys[i]; if k ~= nil then return k, t[k] end end
end
local ind = "    "
local function ser(v, lv, out)
  local t = type(v)
  if t == "table" then
    out[#out + 1] = "{\n"
    for k, x in opairs(v) do
      out[#out + 1] = ind:rep(lv + 1)
      if type(k) == "number" then out[#out + 1] = "[" .. k .. "] = "
      else out[#out + 1] = "[" .. string.format("%q", k) .. "] = " end
      ser(x, lv + 1, out)
      out[#out + 1] = ",\n"
    end
    out[#out + 1] = ind:rep(lv) .. "}"
  elseif t == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif t == "number" then
    if v == math.floor(v) and math.abs(v) < 2^53 then out[#out + 1] = string.format("%d", v)
    else out[#out + 1] = string.format("%.17g", v) end
  else
    out[#out + 1] = tostring(v)
  end
end
local out = { "-- " .. (header or outp) .. "\nreturn " }
ser(base, 0, out)
out[#out + 1] = "\n"
local o = assert(io.open(outp, "w"))
o:write(table.concat(out))
o:close()
