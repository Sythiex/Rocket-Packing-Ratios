local catalog_module = require("scripts.catalog")

local formatter = {}

local function trim_fixed(value)
  value = value:gsub("(%..-)0+$", "%1")
  value = value:gsub("%.$", "")
  if value == "-0" then
    return "0"
  end
  return value
end

function formatter.number(value)
  if value == 0 then
    return "0"
  end
  local magnitude = math.abs(value)
  if magnitude < 0.001 or magnitude > 999 then
    local mantissa, exponent = string.format("%.2e", value):match("^(.+)e([+-]?%d+)$")
    mantissa = trim_fixed(mantissa)
    exponent = tostring(tonumber(exponent))
    return mantissa .. "e" .. exponent
  end

  local digits_before_decimal = math.floor(math.log(magnitude, 10)) + 1
  local decimal_places = math.max(0, 3 - digits_before_decimal)
  return trim_fixed(string.format("%." .. decimal_places .. "f", value))
end

function formatter.icons(frontier, catalog)
  local items = {}
  for item_name, amount in pairs(frontier) do
    local item = catalog.items[item_name]
    if amount > 0 and item then
      items[#items + 1] = item
    end
  end
  table.sort(items, catalog_module.item_less)

  local chunks = {}
  local chunk = ""
  for _, item in ipairs(items) do
    local tag = "[item=" .. item.name .. "]"
    if #chunk > 0 and #chunk + #tag > 160 then
      chunks[#chunks + 1] = chunk
      chunk = ""
    end
    chunk = chunk .. tag
  end
  if #chunk > 0 or #chunks == 0 then
    chunks[#chunks + 1] = chunk
  end

  local nodes = chunks
  while #nodes > 1 do
    local parents = {}
    for first = 1, #nodes, 18 do
      local concatenation = {""}
      for index = first, math.min(first + 17, #nodes) do
        concatenation[#concatenation + 1] = nodes[index]
      end
      parents[#parents + 1] = concatenation
    end
    nodes = parents
  end
  if type(nodes[1]) == "string" then
    return {"", nodes[1]}
  end
  return nodes[1]
end

local function reason(reason_key)
  return {"rocket-packing-ratios-unavailable-reason." .. reason_key}
end

local function comparison(entry, catalog)
  return {
    "rocket-packing-ratios.comparison",
    {"", formatter.number(entry.ratio)},
    formatter.icons(entry.frontier, catalog)
  }
end

function formatter.tooltip_value(result, catalog)
  if not result.ok then
    return {
      "rocket-packing-ratios.unavailable",
      reason(result.reason)
    }
  end

  local direct = comparison(result.direct, catalog)
  if result.expanded then
    return {
      "rocket-packing-ratios.direct-and-expanded",
      direct,
      comparison(result.expanded, catalog)
    }
  end
  if result.expanded_failure then
    return {
      "rocket-packing-ratios.direct-and-expanded",
      direct,
      {
        "rocket-packing-ratios.expanded-unavailable",
        reason(result.expanded_failure)
      }
    }
  end
  return direct
end

function formatter.tooltip_field(result, catalog)
  return {
    name = {"rocket-packing-ratios.tooltip-label"},
    value = formatter.tooltip_value(result, catalog),
    order = 100,
    show_in_tooltip = true,
    show_in_factoriopedia = true
  }
end

return formatter
