local prefix = "rocket-packing-ratios-test-"

local catalog_module = require("__rocket-packing-ratios__.scripts.catalog")
local expected_quantity = require("__rocket-packing-ratios__.scripts.expected_quantity")
local recipe_selector = require("__rocket-packing-ratios__.scripts.recipe_selector")
local weight_resolver = require("__rocket-packing-ratios__.scripts.weight_resolver")
local calculator = require("__rocket-packing-ratios__.scripts.calculator")
local formatter = require("__rocket-packing-ratios__.scripts.formatter")

local function fail(message)
  error("[Rocket Packing Ratios fixture] " .. message, 0)
end

local function assert_true(value, message)
  if not value then
    fail(message)
  end
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    fail(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function assert_close(actual, expected, message, tolerance)
  tolerance = tolerance or 1e-9
  if math.abs(actual - expected) > tolerance then
    fail(message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function localised_text(value)
  if type(value) == "string" then
    return value
  end
  local text = ""
  for index = 2, #value do
    text = text .. localised_text(value[index])
  end
  return text
end

local catalog = catalog_module.build(data.raw, defines.prototypes.item)
local weights = weight_resolver.new(catalog)
local calculations = calculator.new(catalog, weights)

local selection_expectations = {
  ["selector"] = prefix .. "selector",
  ["selector-catalyst"] = prefix .. "selector-catalyst-z",
  ["selector-hand"] = prefix .. "selector-hand-a",
  ["selector-intermediate"] = prefix .. "selector-intermediate-z",
  ["selector-hidden-filter"] = prefix .. "selector-hidden-filter-fallback",
  ["selector-decomposition-filter"] = prefix .. "selector-decomposition-filter-fallback",
  ["selector-category"] = prefix .. "selector-category-a-name",
  ["selector-subgroup"] = prefix .. "selector-subgroup-z-name",
  ["selector-order"] = prefix .. "selector-order-z-name",
  ["selector-subgroup-identifier"] = prefix .. "selector-subgroup-identifier-z",
  ["selector-tie"] = prefix .. "selector-tie-a",
  ["selector-multi-category"] = prefix .. "selector-multi-category-a",
  ["selector-main-product"] = prefix .. "selector-main-product-z-name",
  ["selector-main-product-order"] = prefix .. "selector-main-product-order-z-name",
  ["selector-omitted-order"] = prefix .. "selector-omitted-order-z-name",
  ["selector-omitted-order-no-main"] = prefix .. "selector-omitted-order-no-main-a-name"
}
for suffix, recipe_name in pairs(selection_expectations) do
  local selected = recipe_selector.select(catalog, prefix .. suffix)
  assert_true(selected.ok, "selector failed for " .. suffix)
  assert_equal(selected.recipe.name, recipe_name, "wrong canonical recipe for " .. suffix)
end

local duplicate_recipe = {
  name = "duplicate",
  ingredients = {},
  categories = {"crafting"},
  hand_crafting_intermediate = true,
  allows_hand_crafting_intermediate = true,
  allow_decomposition = true,
  hidden = false,
  subgroup = "other",
  order = ""
}
local ambiguous_catalog = {
  items = {duplicate = {name = "duplicate", subgroup = "other", order = ""}},
  recipes_by_product = {duplicate = {duplicate_recipe, duplicate_recipe}}
}
local ambiguous = recipe_selector.select(ambiguous_catalog, "duplicate")
assert_equal(ambiguous.reason, "ambiguous-production-recipe", "ambiguous selector reason")

assert_close(expected_quantity.for_product({amount = 2}), 2, "fixed product amount")
assert_close(expected_quantity.for_product({amount_min = 2, amount_max = 4}), 3, "range mean")
assert_close(expected_quantity.for_product({amount_min = 5, amount_max = 3}), 5,
  "reversed range clamp")
assert_close(expected_quantity.for_product({
  amount_min = 2,
  amount_max = 4,
  extra_count_fraction = 0.5,
  independent_probability = 0.5,
  shared_probability = {min = 0.2, max = 0.6}
}), 0.7, "combined expected quantity")

local weight_expectations = {
  ["source-a"] = 100,
  ["source-fractional"] = 43691 / 65536,
  ["weight-default"] = 100,
  ["weight-automatic"] = 100,
  ["weight-fluid"] = 100,
  ["weight-simple"] = 10000,
  ["weight-stack-rounded"] = 500,
  ["weight-stack-fractional"] = 19662766 / 65536,
  ["weight-probability"] = 6666666,
  ["weight-range"] = 1333333,
  ["weight-reversed-range"] = 200,
  ["weight-extra"] = 1333333,
  ["weight-independent"] = 2666666,
  ["weight-shared"] = 3333333,
  ["weight-combined"] = 6666666,
  ["selector-tie"] = 100,
  ["selector-multi-category"] = 100,
  ["selector-intermediate"] = 200,
  ["selector-hidden-filter"] = 200,
  ["selector-decomposition-filter"] = 200,
  ["selector-subgroup-identifier"] = 200,
  ["selector-main-product"] = 50,
  ["selector-main-product-order"] = 100,
  ["selector-omitted-order"] = 200,
  ["selector-omitted-order-no-main"] = 100
}
for suffix, expected in pairs(weight_expectations) do
  local resolved = weights:resolve(prefix .. suffix)
  assert_true(resolved.ok, "weight resolution failed for " .. suffix)
  assert_close(resolved.value, expected, "wrong weight for " .. suffix, 1 / 65536)
end
assert_equal(weights:resolve(prefix .. "cursor-source").value, 0, "cursor item weight")
local cycle_a_weight = weights:resolve(prefix .. "cycle-a")
local cycle_b_weight = weights:resolve(prefix .. "cycle-b")
assert_close(cycle_a_weight.value, 25, "cycle A fallback weight")
assert_close(cycle_b_weight.value, 50, "cycle B fallback weight")

local one_step = calculations:calculate(prefix .. "one-step")
assert_true(one_step.ok and one_step.expanded == nil, "one-step calculation did not collapse")
assert_close(one_step.direct.ratio, 2, "one-step ratio")

local probabilistic = calculations:calculate(prefix .. "probability")
assert_true(probabilistic.ok, "probabilistic calculation failed")
assert_close(probabilistic.direct.ratio, 2, "probabilistic ratio")

local reversed_range = calculations:calculate(prefix .. "reversed-range")
assert_true(reversed_range.ok, "reversed-range calculation failed")
assert_close(reversed_range.direct.ratio, 1, "reversed-range ratio")

local duplicate_target = calculations:calculate(prefix .. "duplicate-target")
assert_true(duplicate_target.ok, "duplicate target calculation failed")
assert_close(duplicate_target.direct.ratio, 1, "duplicate target ratio")

local expanded = calculations:calculate(prefix .. "expanded")
assert_true(expanded.ok and expanded.expanded ~= nil, "expanded calculation missing")
assert_close(expanded.direct.ratio, 1, "expanded direct ratio")
assert_close(expanded.expanded.ratio, 2, "expanded frontier ratio")
assert_close(expanded.expanded.frontier[prefix .. "source-a"], 2, "expanded amount normalization")

local identical = calculations:calculate(prefix .. "identical-frontier")
assert_true(identical.ok and identical.expanded == nil, "identical frontier was not collapsed")

local failure_expectations = {
  ["failure-fluid"] = "fluid-packaging-undefined",
  ["failure-multiple"] = "multiple-products",
  ["failure-same-name-fluid-product"] = "multiple-products",
  ["failure-catalyst"] = "unsupported-catalyst",
  ["failure-zero-output"] = "no-expected-output",
  ["failure-missing-weight"] = "missing-item-weight"
}
for suffix, reason in pairs(failure_expectations) do
  local result = calculations:calculate(prefix .. suffix)
  assert_true(not result.ok, "failure fixture unexpectedly succeeded for " .. suffix)
  assert_equal(result.reason, reason, "wrong failure reason for " .. suffix)
end

local cycle = calculations:calculate(prefix .. "cycle-a")
assert_true(cycle.ok, "cycle direct calculation should succeed")
assert_equal(cycle.expanded_failure, "cyclic-recipe", "cycle expansion failure")

local assembling_machine = calculations:calculate("assembling-machine-1")
assert_true(assembling_machine.ok and assembling_machine.expanded ~= nil,
  "assembling-machine-1 should have direct and expanded values")
assert_true(assembling_machine.direct.frontier["electronic-circuit"] ~= nil,
  "assembling-machine-1 direct circuit frontier missing")
assert_true(assembling_machine.direct.frontier["iron-gear-wheel"] ~= nil,
  "assembling-machine-1 direct gear frontier missing")
assert_true(assembling_machine.expanded.frontier["iron-plate"] ~= nil,
  "assembling-machine-1 expanded iron plate missing")
assert_true(assembling_machine.expanded.frontier["copper-plate"] ~= nil,
  "assembling-machine-1 expanded copper plate missing")
assert_true(assembling_machine.expanded.frontier["iron-ore"] == nil,
  "assembling-machine-1 expanded past plate-level leaves")
assert_true(math.abs(assembling_machine.direct.ratio - assembling_machine.expanded.ratio) > 1e-9,
  "assembling-machine-1 ratios should differ")

assert_equal(formatter.number(0.001), "0.001", "lower fixed-format boundary")
assert_equal(formatter.number(12.345), "12.3", "three significant digits")
assert_equal(formatter.number(999), "999", "upper fixed-format boundary")
assert_equal(formatter.number(1000), "1e3", "scientific upper range")
assert_equal(formatter.number(0.0001), "1e-4", "scientific lower range")

local long_result = calculations:calculate(prefix .. "long-target")
assert_true(long_result.ok, "long icon calculation failed")
local first_icons = localised_text(formatter.icons(long_result.direct.frontier, catalog))
local second_icons = localised_text(formatter.icons(long_result.direct.frontier, catalog))
assert_equal(first_icons, second_icons, "icon ordering changed between calls")
local icon_count = 0
for _ in first_icons:gmatch("%[item=") do
  icon_count = icon_count + 1
end
assert_equal(icon_count, 24, "long icon sequence was capped")
local even_position = first_icons:find(prefix .. "long-source-24", 1, true)
local odd_position = first_icons:find(prefix .. "long-source-23", 1, true)
assert_true(even_position ~= nil and odd_position ~= nil and even_position < odd_position,
  "native subgroup ordering was not applied: " .. first_icons)

local existing = data.raw.item[prefix .. "existing-tooltip"].custom_tooltip_fields
assert_equal(#existing, 2, "existing tooltip was replaced")
assert_equal(existing[1].order, 17, "existing tooltip order changed")
assert_equal(existing[2].name[1], "rocket-packing-ratios.tooltip-label", "generated tooltip locale key")
assert_equal(existing[2].order, 100, "generated tooltip order")
assert_true(existing[2].show_in_tooltip and existing[2].show_in_factoriopedia,
  "generated tooltip visibility flags")

local raw_item = data.raw.item[prefix .. "weight-default"]
assert_true(raw_item.custom_tooltip_fields == nil, "recipe-less item received a tooltip")

for type_name in pairs(defines.prototypes.item) do
  for name in pairs(data.raw[type_name] or {}) do
    assert_true(catalog.items[name] ~= nil, "catalog missed " .. type_name .. "/" .. name)
  end
end

local repeat_catalog = catalog_module.build(data.raw, defines.prototypes.item)
local repeat_result = calculator.new(repeat_catalog, weight_resolver.new(repeat_catalog))
  :calculate(prefix .. "long-target")
assert_equal(
  localised_text(formatter.icons(repeat_result.direct.frontier, repeat_catalog)),
  first_icons,
  "repeated catalog build changed output"
)

local generated_cycle_field = data.raw.item[prefix .. "cycle-a"].custom_tooltip_fields[1]
assert_equal(generated_cycle_field.value[1], "rocket-packing-ratios.direct-and-expanded",
  "cycle field should preserve direct result")
assert_equal(generated_cycle_field.value[3][1], "rocket-packing-ratios.expanded-unavailable",
  "cycle field missing expanded failure")

for suffix, reason in pairs(failure_expectations) do
  local fields = data.raw.item[prefix .. suffix].custom_tooltip_fields
  assert_true(fields and #fields == 1, "failure tooltip missing for " .. suffix)
  assert_equal(fields[1].value[1], "rocket-packing-ratios.unavailable",
    "failure tooltip localization for " .. suffix)
  assert_equal(fields[1].value[2][1], "rocket-packing-ratios-unavailable-reason." .. reason,
    "failure reason localization for " .. suffix)
end
