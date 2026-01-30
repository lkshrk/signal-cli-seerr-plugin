--[[
  Minimal JSON implementation for testing
  Supports encoding/decoding of simple tables used in tests
]]

local json = {}

-- Simple encode function
function json.encode(obj)
  local t = type(obj)
  if t == "nil" then
    return "null"
  elseif t == "boolean" then
    return obj and "true" or "false"
  elseif t == "number" then
    return tostring(obj)
  elseif t == "string" then
    return '"' .. obj:gsub('"', '\\"'):gsub("\n", "\\n") .. '"'
  elseif t == "table" then
    local is_array = true
    local max_index = 0
    for k, v in pairs(obj) do
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        is_array = false
        break
      end
      max_index = math.max(max_index, k)
    end
    
    if is_array and max_index > 0 then
      -- Array
      local parts = {}
      for i = 1, max_index do
        parts[i] = json.encode(obj[i])
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      -- Object
      local parts = {}
      for k, v in pairs(obj) do
        table.insert(parts, json.encode(tostring(k)) .. ":" .. json.encode(v))
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

-- Better decode function with position tracking
local function skip_whitespace(str, pos)
  while pos <= #str and str:sub(pos, pos):match("%s") do
    pos = pos + 1
  end
  return pos
end

local function parse_value(str, pos)
  pos = skip_whitespace(str, pos)
  if pos > #str then return nil, pos end
  
  local char = str:sub(pos, pos)
  
  -- null
  if str:sub(pos, pos + 3) == "null" then
    return nil, pos + 4
  end
  
  -- true
  if str:sub(pos, pos + 3) == "true" then
    return true, pos + 4
  end
  
  -- false
  if str:sub(pos, pos + 4) == "false" then
    return false, pos + 5
  end
  
  -- number
  local num_str = str:match("^%-?%d+%.?%d*[eE]?[+-]?%d*", pos)
  if num_str then
    return tonumber(num_str), pos + #num_str
  end
  
  -- string
  if char == '"' then
    local end_pos = pos + 1
    local result = {}
    while end_pos <= #str do
      local c = str:sub(end_pos, end_pos)
      if c == '"' then
        break
      elseif c == '\\' then
        local next_c = str:sub(end_pos + 1, end_pos + 1)
        if next_c == '"' then
          table.insert(result, '"')
          end_pos = end_pos + 2
        elseif next_c == '\\' then
          table.insert(result, '\\')
          end_pos = end_pos + 2
        elseif next_c == 'n' then
          table.insert(result, '\n')
          end_pos = end_pos + 2
        elseif next_c == 't' then
          table.insert(result, '\t')
          end_pos = end_pos + 2
        else
          table.insert(result, next_c)
          end_pos = end_pos + 2
        end
      else
        table.insert(result, c)
        end_pos = end_pos + 1
      end
    end
    return table.concat(result), end_pos + 1
  end
  
  -- array
  if char == '[' then
    local arr = {}
    pos = pos + 1
    pos = skip_whitespace(str, pos)
    if str:sub(pos, pos) == ']' then
      return arr, pos + 1
    end
    while true do
      local val, new_pos = parse_value(str, pos)
      if val ~= nil or str:sub(pos, pos) == 'n' then
        table.insert(arr, val)
      end
      pos = skip_whitespace(str, new_pos)
      local next_char = str:sub(pos, pos)
      if next_char == ']' then
        return arr, pos + 1
      elseif next_char == ',' then
        pos = pos + 1
      else
        break
      end
    end
    return arr, pos
  end
  
  -- object
  if char == '{' then
    local obj = {}
    pos = pos + 1
    pos = skip_whitespace(str, pos)
    if str:sub(pos, pos) == '}' then
      return obj, pos + 1
    end
    while true do
      -- Parse key (must be string)
      pos = skip_whitespace(str, pos)
      local key, new_pos
      if str:sub(pos, pos) == '"' then
        key, new_pos = parse_value(str, pos)
      else
        break
      end
      pos = skip_whitespace(str, new_pos)
      if str:sub(pos, pos) ~= ':' then
        break
      end
      pos = pos + 1
      -- Parse value
      local val, val_pos = parse_value(str, pos)
      obj[key] = val
      pos = skip_whitespace(str, val_pos)
      local next_char = str:sub(pos, pos)
      if next_char == '}' then
        return obj, pos + 1
      elseif next_char == ',' then
        pos = pos + 1
      else
        break
      end
    end
    return obj, pos
  end
  
  return nil, pos
end

function json.decode(str)
  if not str or str == "" then
    return nil
  end
  local result, pos = parse_value(str, 1)
  return result
end

return json
