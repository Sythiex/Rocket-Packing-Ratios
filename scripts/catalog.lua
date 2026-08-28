local catalog_module = {}

local function sorted_keys(dictionary)
  local keys = {}
  for key in pairs(dictionary or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function normalize_type_names(item_type_definitions)
  local seen = {}
  for key, value in pairs(item_type_definitions or {}) do
    local type_name = type(key) == "string" and key or value
    if type(type_name) == "string" then
      seen[type_name] = true
    end
  end
  return sorted_keys(seen)
end

local function normalize_ingredient(ingredient)
  return {
    type = ingredient.type or "item",
    name = ingredient.name or ingredient[1],
    amount = ingredient.amount or ingredient[2]
  }
end

local function normalize_product(product)
  return {
    type = product.type or "item",
    name = product.name or product[1],
    amount = product.amount or product[2],
    amount_min = product.amount_min,
    amount_max = product.amount_max,
    extra_count_fraction = product.extra_count_fraction,
    independent_probability = product.independent_probability or product.probability,
    shared_probability = product.shared_probability
  }
end

local function normalize_results(recipe)
  local results = {}
  if recipe.results then
    for _, product in ipairs(recipe.results) do
      results[#results + 1] = normalize_product(product)
    end
  elseif recipe.result then
    results[1] = {
      type = "item",
      name = recipe.result,
      amount = recipe.result_count or 1
    }
  end
  return results
end

local function normalize_categories(recipe)
  local categories = {}
  if recipe.categories then
    for _, category in ipairs(recipe.categories) do
      categories[#categories + 1] = category
    end
  elseif recipe.category then
    categories[1] = recipe.category
  else
    categories[1] = "crafting"
  end
  return categories
end

local function has_flag(prototype, wanted)
  for key, value in pairs(prototype.flags or {}) do
    if key == wanted or value == wanted then
      return true
    end
  end
  return false
end

local function item_sort_key(data_raw, prototype)
  local subgroup_name = prototype.subgroup or "other"
  local subgroup = (data_raw["item-subgroup"] or {})[subgroup_name] or {}
  local group_name = subgroup.group or "other"
  local group = (data_raw["item-group"] or {})[group_name] or {}
  return {
    group.order or "",
    group_name,
    subgroup.order or "",
    subgroup_name,
    prototype.order or "",
    prototype.name
  }
end

local function lexicographic_less(left, right)
  for index = 1, math.max(#left, #right) do
    local left_value = left[index] or ""
    local right_value = right[index] or ""
    if left_value ~= right_value then
      return left_value < right_value
    end
  end
  return false
end

local function collect_hand_crafting_categories(data_raw)
  local categories = {crafting = true}
  for _, character in pairs(data_raw.character or {}) do
    for _, category in ipairs(character.crafting_categories or {}) do
      categories[category] = true
    end
  end
  return categories
end

local function is_hand_crafting_intermediate(recipe, hand_categories)
  if recipe.allow_as_intermediate == false then
    return false
  end
  for _, category in ipairs(recipe.categories) do
    if hand_categories[category] then
      return true
    end
  end
  return false
end

local function product_subgroup(catalog, product)
  if product.type == "item" then
    local item = catalog.items[product.name]
    return item and item.subgroup or nil
  end

  local prototype = (catalog.data_raw[product.type] or {})[product.name]
  return prototype and (prototype.subgroup or "other") or nil
end

local function product_order(catalog, product)
  if product.type == "item" then
    local item = catalog.items[product.name]
    return item and item.order or nil
  end

  local prototype = (catalog.data_raw[product.type] or {})[product.name]
  return prototype and (prototype.order or "") or nil
end

local function effective_recipe_subgroup(catalog, recipe)
  if recipe.subgroup ~= nil then
    return recipe.subgroup
  end

  local main_product = recipe.main_product
  if main_product ~= nil and main_product ~= "" then
    for _, product in ipairs(recipe.results) do
      if product.name == main_product then
        return product_subgroup(catalog, product)
      end
    end
  elseif main_product == nil and #recipe.results == 1 then
    return product_subgroup(catalog, recipe.results[1])
  end

  return nil
end

local function effective_recipe_order(catalog, recipe)
  if recipe.order ~= nil then
    return recipe.order
  end

  local main_product = recipe.main_product
  if main_product ~= nil and main_product ~= "" then
    for _, product in ipairs(recipe.results) do
      if product.name == main_product then
        return product_order(catalog, product)
      end
    end
  elseif main_product == nil and #recipe.results == 1 then
    return product_order(catalog, recipe.results[1])
  end

  return ""
end

function catalog_module.build(data_raw, item_type_definitions)
  local catalog = {
    data_raw = data_raw,
    item_type_names = normalize_type_names(item_type_definitions),
    items = {},
    item_names = {},
    recipes = {},
    recipe_names = {},
    recipes_by_product = {},
    hand_crafting_categories = collect_hand_crafting_categories(data_raw)
  }

  for _, type_name in ipairs(catalog.item_type_names) do
    for _, name in ipairs(sorted_keys(data_raw[type_name])) do
      local prototype = data_raw[type_name][name]
      catalog.items[name] = {
        name = name,
        type = type_name,
        prototype = prototype,
        stack_size = prototype.stack_size,
        weight = prototype.weight,
        ingredient_to_weight_coefficient = prototype.ingredient_to_weight_coefficient or 0.5,
        subgroup = prototype.subgroup or "other",
        order = prototype.order or "",
        only_in_cursor = has_flag(prototype, "only-in-cursor"),
        spawnable = has_flag(prototype, "spawnable"),
        sort_key = item_sort_key(data_raw, prototype)
      }
      catalog.item_names[#catalog.item_names + 1] = name
    end
  end
  table.sort(catalog.item_names)

  for _, name in ipairs(sorted_keys(data_raw.recipe)) do
    local prototype = data_raw.recipe[name]
    local recipe = {
      name = name,
      prototype = prototype,
      ingredients = {},
      results = normalize_results(prototype),
      categories = normalize_categories(prototype),
      hidden = prototype.hidden == true,
      allow_decomposition = prototype.allow_decomposition ~= false,
      allow_as_intermediate = prototype.allow_as_intermediate ~= false,
      allow_productivity = prototype.allow_productivity == true,
      main_product = prototype.main_product,
      subgroup = prototype.subgroup,
      order = prototype.order
    }
    for _, ingredient in ipairs(prototype.ingredients or {}) do
      recipe.ingredients[#recipe.ingredients + 1] = normalize_ingredient(ingredient)
    end
    recipe.hand_crafting_intermediate = is_hand_crafting_intermediate(
      recipe,
      catalog.hand_crafting_categories
    )
    recipe.allows_hand_crafting_intermediate = recipe.allow_as_intermediate
    recipe.effective_subgroup = effective_recipe_subgroup(catalog, recipe)
    recipe.effective_order = effective_recipe_order(catalog, recipe)
    catalog.recipes[name] = recipe
    catalog.recipe_names[#catalog.recipe_names + 1] = name

    local indexed = {}
    for _, product in ipairs(recipe.results) do
      if product.type == "item" and catalog.items[product.name] and not indexed[product.name] then
        local candidates = catalog.recipes_by_product[product.name]
        if candidates == nil then
          candidates = {}
          catalog.recipes_by_product[product.name] = candidates
        end
        candidates[#candidates + 1] = recipe
        indexed[product.name] = true
      end
    end
  end

  return catalog
end

function catalog_module.item_less(left, right)
  return lexicographic_less(left.sort_key, right.sort_key)
end

function catalog_module.sorted_keys(dictionary)
  return sorted_keys(dictionary)
end

return catalog_module
