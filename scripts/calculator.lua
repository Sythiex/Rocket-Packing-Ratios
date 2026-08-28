local expected_quantity = require("scripts.expected_quantity")
local recipe_selector = require("scripts.recipe_selector")

local calculator = {}
local methods = {}

local function failure(reason)
  return {ok = false, reason = reason}
end

local function add_amount(frontier, item_name, amount)
  frontier[item_name] = (frontier[item_name] or 0) + amount
end

local function sorted_keys(dictionary)
  local keys = {}
  for key in pairs(dictionary) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function aggregate_item_ingredients(recipe)
  local frontier = {}
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "item" then
      add_amount(frontier, ingredient.name, ingredient.amount)
    end
  end
  return frontier
end

local function copy_scaled(target, source, scale)
  for _, item_name in ipairs(sorted_keys(source)) do
    local amount = source[item_name]
    add_amount(target, item_name, amount * scale)
  end
end

local function frontiers_equal(left, right)
  for item_name, amount in pairs(left) do
    if math.abs(amount - (right[item_name] or 0)) > 1e-12 then
      return false
    end
  end
  for item_name, amount in pairs(right) do
    if math.abs(amount - (left[item_name] or 0)) > 1e-12 then
      return false
    end
  end
  return true
end

function calculator.new(catalog, weights)
  return setmetatable({
    catalog = catalog,
    weights = weights,
    expansion_memo = {}
  }, {__index = methods})
end

function methods:validate_recipe(recipe, item_name)
  local output_quantity = expected_quantity.for_item(recipe, item_name)
  if output_quantity <= 0 then
    return failure("no-expected-output")
  end

  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "item" and ingredient.name == item_name then
      return failure("unsupported-catalyst")
    end
  end

  for _, product in ipairs(recipe.results) do
    local quantity = expected_quantity.for_product(product) or 0
    if quantity > 0 and (product.type ~= "item" or product.name ~= item_name) then
      return failure("multiple-products")
    end
  end

  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "fluid" then
      return failure("fluid-packaging-undefined")
    end
  end

  local target_weight = self.weights:resolve(item_name)
  if not target_weight.ok or target_weight.value <= 0 then
    return failure(target_weight.reason or "missing-item-weight")
  end
  for _, ingredient in ipairs(recipe.ingredients) do
    local ingredient_weight = self.weights:resolve(ingredient.name)
    if not ingredient_weight.ok or ingredient_weight.value <= 0 then
      return failure(ingredient_weight.reason or "missing-item-weight")
    end
  end

  return {
    ok = true,
    output_quantity = output_quantity,
    target_weight = target_weight.value,
    frontier = aggregate_item_ingredients(recipe)
  }
end

function methods:ratio(frontier, denominator)
  local numerator = 0
  for _, item_name in ipairs(sorted_keys(frontier)) do
    local amount = frontier[item_name]
    local weight = self.weights:resolve(item_name)
    if not weight.ok or weight.value <= 0 then
      return failure(weight.reason or "missing-item-weight")
    end
    numerator = numerator + amount * weight.value
  end
  return {ok = true, value = numerator / denominator}
end

function methods:expand_unit(item_name, active)
  if active[item_name] then
    return failure("cyclic-recipe")
  end
  local memoized = self.expansion_memo[item_name]
  if memoized then
    return memoized
  end

  local selected = recipe_selector.select(self.catalog, item_name)
  if not selected.ok then
    if selected.no_recipe then
      local leaf = {ok = true, frontier = {[item_name] = 1}}
      self.expansion_memo[item_name] = leaf
      return leaf
    end
    return failure(selected.reason)
  end
  if not selected.recipe.hand_crafting_intermediate then
    local leaf = {ok = true, frontier = {[item_name] = 1}}
    self.expansion_memo[item_name] = leaf
    return leaf
  end

  local validated = self:validate_recipe(selected.recipe, item_name)
  if not validated.ok then
    self.expansion_memo[item_name] = validated
    return validated
  end

  active[item_name] = true
  local frontier = {}
  for _, ingredient_name in ipairs(sorted_keys(validated.frontier)) do
    local amount = validated.frontier[ingredient_name]
    local expanded = self:expand_unit(ingredient_name, active)
    if not expanded.ok then
      active[item_name] = nil
      return expanded
    end
    copy_scaled(frontier, expanded.frontier, amount / validated.output_quantity)
  end
  active[item_name] = nil

  local result = {ok = true, frontier = frontier}
  self.expansion_memo[item_name] = result
  return result
end

function methods:calculate(item_name)
  local selected = recipe_selector.select(self.catalog, item_name)
  if not selected.ok then
    if selected.no_recipe then
      return {ok = false, no_recipe = true}
    end
    return failure(selected.reason)
  end

  local validated = self:validate_recipe(selected.recipe, item_name)
  if not validated.ok then
    return validated
  end
  local denominator = validated.output_quantity * validated.target_weight
  local direct_ratio = self:ratio(validated.frontier, denominator)
  if not direct_ratio.ok then
    return direct_ratio
  end

  local expanded_frontier = {}
  local active = {[item_name] = true}
  for _, ingredient_name in ipairs(sorted_keys(validated.frontier)) do
    local amount = validated.frontier[ingredient_name]
    local expanded = self:expand_unit(ingredient_name, active)
    if not expanded.ok then
      return {
        ok = true,
        recipe = selected.recipe,
        direct = {ratio = direct_ratio.value, frontier = validated.frontier},
        expanded_failure = expanded.reason
      }
    end
    copy_scaled(expanded_frontier, expanded.frontier, amount)
  end

  local result = {
    ok = true,
    recipe = selected.recipe,
    direct = {ratio = direct_ratio.value, frontier = validated.frontier}
  }
  if not frontiers_equal(validated.frontier, expanded_frontier) then
    local expanded_ratio = self:ratio(expanded_frontier, denominator)
    if not expanded_ratio.ok then
      result.expanded_failure = expanded_ratio.reason
    else
      result.expanded = {ratio = expanded_ratio.value, frontier = expanded_frontier}
    end
  end
  return result
end

function calculator.frontiers_equal(left, right)
  return frontiers_equal(left, right)
end

return calculator
