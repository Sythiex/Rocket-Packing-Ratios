local expected_quantity = require("scripts.expected_quantity")
local recipe_selector = require("scripts.recipe_selector")

local weight_resolver = {}
local methods = {}

local FIXED_POINT_SCALE = 65536
local FLUID_WEIGHT = 100

local function quantize(value)
  return math.floor(value * FIXED_POINT_SCALE + 0.5) / FIXED_POINT_SCALE
end

local function utility_constants(catalog)
  return (catalog.data_raw["utility-constants"] or {}).default or {}
end

function weight_resolver.new(catalog)
  local constants = utility_constants(catalog)
  return setmetatable({
    catalog = catalog,
    default_item_weight = constants.default_item_weight or 100,
    rocket_lift_weight = constants.default_rocket_lift_weight or 1000000,
    memo = {},
    active = {}
  }, {__index = methods})
end

function methods:resolve(item_name)
  local memoized = self.memo[item_name]
  if memoized then
    return memoized
  end

  local item = self.catalog.items[item_name]
  if item == nil then
    return {ok = false, reason = "missing-item-weight"}
  end
  if item.weight ~= nil then
    local result = {ok = true, value = quantize(item.weight), source = "explicit"}
    self.memo[item_name] = result
    return result
  end
  if item.only_in_cursor and item.spawnable then
    local result = {ok = true, value = 0, source = "cursor"}
    self.memo[item_name] = result
    return result
  end
  if self.active[item_name] then
    return {ok = true, value = quantize(self.default_item_weight), source = "cycle-default"}
  end

  local selected = recipe_selector.select(self.catalog, item_name)
  if not selected.ok then
    local result
    if selected.no_recipe then
      result = {ok = true, value = quantize(self.default_item_weight), source = "default"}
    else
      result = {ok = false, reason = selected.reason}
    end
    self.memo[item_name] = result
    return result
  end

  self.active[item_name] = true
  local recipe_weight = 0
  for _, ingredient in ipairs(selected.recipe.ingredients) do
    if ingredient.type == "fluid" then
      recipe_weight = recipe_weight + ingredient.amount * FLUID_WEIGHT
    else
      local ingredient_weight = self:resolve(ingredient.name)
      if not ingredient_weight.ok then
        self.active[item_name] = nil
        return ingredient_weight
      end
      recipe_weight = recipe_weight + ingredient.amount * ingredient_weight.value
    end
  end
  self.active[item_name] = nil

  -- Factorio 2.1's automatic item-weight calculation ignores
  -- ItemProductPrototype::extra_count_fraction. The user-facing ratio still
  -- includes it in expected output; the isolated engine fixtures pin this
  -- otherwise-undocumented distinction.
  local product_count = expected_quantity.for_all_items(selected.recipe, false)
  if recipe_weight <= 0 or product_count <= 0 then
    local result = {ok = true, value = quantize(self.default_item_weight), source = "default"}
    self.memo[item_name] = result
    return result
  end

  local intermediate = recipe_weight / product_count * item.ingredient_to_weight_coefficient
  local value
  if not selected.recipe.allow_productivity then
    local simple = self.rocket_lift_weight / item.stack_size
    if simple >= intermediate then
      value = simple
    end
  end
  if value == nil then
    local stack_amount = self.rocket_lift_weight / intermediate / item.stack_size
    if stack_amount <= 1 then
      value = math.floor(intermediate)
    else
      value = self.rocket_lift_weight / math.floor(stack_amount) / item.stack_size
    end
  end

  local result = {ok = true, value = quantize(value), source = "automatic"}
  self.memo[item_name] = result
  return result
end

function weight_resolver.quantize(value)
  return quantize(value)
end

return weight_resolver
