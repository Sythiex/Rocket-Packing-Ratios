local catalog_module = require("scripts.catalog")
local weight_resolver = require("scripts.weight_resolver")
local calculator = require("scripts.calculator")
local formatter = require("scripts.formatter")

local pipeline = {}

function pipeline.run(data_raw, item_type_definitions)
  local catalog = catalog_module.build(data_raw, item_type_definitions)
  local weights = weight_resolver.new(catalog)
  local calculations = calculator.new(catalog, weights)
  local counts = {items = 0, tooltips = 0, unavailable = 0}

  for _, item_name in ipairs(catalog.item_names) do
    counts.items = counts.items + 1
    local result = calculations:calculate(item_name)
    if not result.no_recipe then
      local prototype = catalog.items[item_name].prototype
      prototype.custom_tooltip_fields = prototype.custom_tooltip_fields or {}
      prototype.custom_tooltip_fields[#prototype.custom_tooltip_fields + 1] =
        formatter.tooltip_field(result, catalog)
      counts.tooltips = counts.tooltips + 1
      if not result.ok then
        counts.unavailable = counts.unavailable + 1
      end
    end
  end

  return {
    catalog = catalog,
    weights = weights,
    calculations = calculations,
    counts = counts
  }
end

return pipeline
