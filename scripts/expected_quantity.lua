local expected_quantity = {}

local function shared_probability(product)
  local shared = product.shared_probability
  if shared == nil then
    return 1
  end
  return shared.max - shared.min
end

function expected_quantity.for_product(product, include_extra_count_fraction)
  if type(product) ~= "table" then
    return nil
  end

  local amount
  if product.amount ~= nil then
    amount = product.amount
  elseif product.amount_min ~= nil and product.amount_max ~= nil then
    -- Factorio clamps a reversed product maximum to the minimum before using
    -- the range. Keep that loader behavior in pure fixtures and normalized
    -- data-stage calculations alike.
    amount = (product.amount_min + math.max(product.amount_min, product.amount_max)) / 2
  else
    return nil
  end

  if include_extra_count_fraction ~= false then
    amount = amount + (product.extra_count_fraction or 0)
  end
  return amount
    * (product.independent_probability or 1)
    * shared_probability(product)
end

function expected_quantity.for_item(recipe, item_name)
  local total = 0
  for _, product in ipairs(recipe.results or {}) do
    if product.type == "item" and product.name == item_name then
      total = total + (expected_quantity.for_product(product) or 0)
    end
  end
  return total
end

function expected_quantity.for_all_items(recipe, include_extra_count_fraction)
  local total = 0
  for _, product in ipairs(recipe.results or {}) do
    if product.type == "item" then
      total = total + (expected_quantity.for_product(product, include_extra_count_fraction) or 0)
    end
  end
  return total
end

return expected_quantity
