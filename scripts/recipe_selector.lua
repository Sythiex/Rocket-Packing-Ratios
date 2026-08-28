local recipe_selector = {}

local function target_is_ingredient(recipe, item_name)
  for _, ingredient in ipairs(recipe.ingredients) do
    if ingredient.type == "item" and ingredient.name == item_name then
      return true
    end
  end
  return false
end

local function category_key(recipe)
  -- Factorio 2.1 compares the greatest category identifier when a recipe has
  -- multiple categories; the comparison itself is descending (see less()).
  local categories = recipe.categories or {}
  local selected = categories[1] or "crafting"
  for index = 2, #categories do
    local category = categories[index]
    if category > selected then
      selected = category
    end
  end
  return selected
end

local function subgroup_key(catalog, subgroup_name)
  -- Recipe selection follows native group/subgroup ordering, not identifier
  -- ordering. A fixture reverses identifiers and orders to guard this detail.
  local data_raw = catalog.data_raw or {}
  local subgroup = (data_raw["item-subgroup"] or {})[subgroup_name] or {}
  local group_name = subgroup.group or "other"
  local group = (data_raw["item-group"] or {})[group_name] or {}
  return table.concat({
    group.order or "",
    group_name,
    subgroup.order or "",
    subgroup_name
  }, "\0")
end

local function selection_key(catalog, recipe, item)
  return {
    recipe.name == item.name and 0 or 1,
    target_is_ingredient(recipe, item.name) and 1 or 0,
    recipe.allows_hand_crafting_intermediate and 0 or 1,
    category_key(recipe),
    -- Omitted recipe subgroups inherit from the singular/explicit main
    -- product during catalog normalization, including when the evaluated item
    -- is only a coproduct.
    subgroup_key(catalog, recipe.effective_subgroup or item.subgroup or "other"),
    -- Omitted orders follow singular/explicit main-product inheritance during
    -- catalog normalization; a recipe without a main product defaults to "".
    recipe.effective_order or "",
    recipe.name
  }
end

local function less(left, right)
  for index = 1, math.max(#left, #right) do
    local left_value = left[index]
    local right_value = right[index]
    if left_value ~= right_value then
      if index == 4 then
        return left_value > right_value
      end
      return left_value < right_value
    end
  end
  return false
end

local function equal(left, right)
  if #left ~= #right then
    return false
  end
  for index = 1, #left do
    if left[index] ~= right[index] then
      return false
    end
  end
  return true
end

function recipe_selector.select(catalog, item_name)
  local item = catalog.items[item_name]
  if item == nil then
    return {ok = false, reason = "missing-item-weight"}
  end

  local ranked = {}
  for _, recipe in ipairs(catalog.recipes_by_product[item_name] or {}) do
    if not recipe.hidden and recipe.allow_decomposition then
      ranked[#ranked + 1] = {
        recipe = recipe,
        key = selection_key(catalog, recipe, item)
      }
    end
  end
  if #ranked == 0 then
    return {ok = false, no_recipe = true}
  end

  table.sort(ranked, function(left, right)
    return less(left.key, right.key)
  end)
  if #ranked > 1 and equal(ranked[1].key, ranked[2].key) then
    return {ok = false, reason = "ambiguous-production-recipe"}
  end
  return {ok = true, recipe = ranked[1].recipe}
end

function recipe_selector.selection_key(catalog, recipe, item)
  return selection_key(catalog, recipe, item)
end

return recipe_selector
