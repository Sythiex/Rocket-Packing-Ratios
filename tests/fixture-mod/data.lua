local prefix = "rocket-packing-ratios-test-"
local icon = "__base__/graphics/icons/iron-plate.png"

data:extend({
  {
    type = "item-group",
    name = prefix .. "group",
    icon = icon,
    icon_size = 64,
    order = "zz[rocket-packing-ratios-test]"
  },
  {
    type = "item-subgroup",
    name = prefix .. "subgroup-a",
    group = prefix .. "group",
    order = "a"
  },
  {
    type = "item-subgroup",
    name = prefix .. "subgroup-b",
    group = prefix .. "group",
    order = "b"
  },
  {
    type = "item-subgroup",
    name = prefix .. "subgroup-id-a",
    group = prefix .. "group",
    order = "z"
  },
  {
    type = "item-subgroup",
    name = prefix .. "subgroup-id-z",
    group = prefix .. "group",
    order = "a"
  },
  {type = "recipe-category", name = prefix .. "category-a"},
  {type = "recipe-category", name = prefix .. "category-m"},
  {type = "recipe-category", name = prefix .. "category-z"},
  {
    type = "fluid",
    name = prefix .. "fluid",
    icon = "__base__/graphics/icons/fluid/water.png",
    icon_size = 64,
    default_temperature = 15,
    max_temperature = 100,
    base_color = {0.1, 0.4, 0.8},
    flow_color = {0.2, 0.6, 1}
  },
  {
    type = "fluid",
    name = prefix .. "failure-same-name-fluid-product",
    icon = "__base__/graphics/icons/fluid/water.png",
    icon_size = 64,
    default_temperature = 15,
    max_temperature = 100,
    base_color = {0.1, 0.4, 0.8},
    flow_color = {0.2, 0.6, 1}
  }
})

local prototypes = {}

local function add(prototype)
  prototypes[#prototypes + 1] = prototype
  return prototype
end

local function item(suffix, options)
  options = options or {}
  local prototype = {
    type = "item",
    name = prefix .. suffix,
    icon = icon,
    icon_size = 64,
    subgroup = options.subgroup or prefix .. "subgroup-a",
    order = options.order or suffix,
    stack_size = options.stack_size or 1,
    weight = options.weight,
    ingredient_to_weight_coefficient = options.coefficient,
    flags = options.flags,
    custom_tooltip_fields = options.custom_tooltip_fields
  }
  return add(prototype)
end

local function ingredient(name, amount, ingredient_type)
  return {type = ingredient_type or "item", name = name, amount = amount}
end

local function product(name, amount, product_type)
  return {type = product_type or "item", name = name, amount = amount}
end

local function recipe(name, ingredients, results, options)
  options = options or {}
  return add({
    type = "recipe",
    name = name,
    icons = {{icon = icon, icon_size = 64}},
    category = options.category,
    categories = options.categories,
    main_product = options.main_product,
    subgroup = options.subgroup,
    order = options.order,
    hidden = options.hidden,
    allow_decomposition = options.allow_decomposition,
    allow_as_intermediate = options.allow_as_intermediate,
    allow_productivity = options.allow_productivity,
    enabled = true,
    energy_required = 0.5,
    ingredients = ingredients,
    results = results
  })
end

local source_a = item("source-a", {weight = 100, order = "b"}).name
local source_b = item("source-b", {weight = 200, subgroup = prefix .. "subgroup-b", order = "a"}).name
local source_c = item("source-c", {weight = 300, order = "a"}).name
local source_fractional = item("source-fractional", {weight = 2 / 3}).name
local cursor_source = item("cursor-source", {
  flags = {"only-in-cursor", "spawnable"},
  stack_size = 1
}).name

local selector = item("selector", {coefficient = 1}).name
recipe(selector, {ingredient(source_a, 1)}, {product(selector, 1)}, {allow_productivity = true})
recipe(prefix .. "selector-hidden", {ingredient(source_c, 1)}, {product(selector, 1)}, {
  hidden = true,
  allow_productivity = true
})
recipe(prefix .. "selector-no-decomposition", {ingredient(source_b, 1)}, {product(selector, 1)}, {
  allow_decomposition = false,
  allow_productivity = true
})

local selector_catalyst = item("selector-catalyst", {coefficient = 1}).name
recipe(prefix .. "selector-catalyst-a", {
  ingredient(selector_catalyst, 1),
  ingredient(source_c, 1)
}, {product(selector_catalyst, 1)}, {allow_productivity = true})
recipe(prefix .. "selector-catalyst-z", {ingredient(source_b, 1)}, {
  product(selector_catalyst, 1)
}, {allow_productivity = true})

local selector_hand = item("selector-hand", {coefficient = 1}).name
recipe(prefix .. "selector-hand-a", {ingredient(source_a, 1)}, {product(selector_hand, 1)}, {
  categories = {prefix .. "category-a"},
  allow_productivity = true
})
recipe(prefix .. "selector-hand-z", {ingredient(source_b, 1)}, {product(selector_hand, 1)}, {
  categories = {"crafting"},
  allow_productivity = true
})

local selector_intermediate = item("selector-intermediate", {coefficient = 1}).name
recipe(prefix .. "selector-intermediate-a", {ingredient(source_a, 1)}, {
  product(selector_intermediate, 1)
}, {allow_as_intermediate = false, allow_productivity = true})
recipe(prefix .. "selector-intermediate-z", {ingredient(source_b, 1)}, {
  product(selector_intermediate, 1)
}, {allow_as_intermediate = true, allow_productivity = true})

local selector_hidden_filter = item("selector-hidden-filter", {coefficient = 1}).name
recipe(selector_hidden_filter, {ingredient(source_a, 1)}, {
  product(selector_hidden_filter, 1)
}, {hidden = true, allow_productivity = true})
recipe(prefix .. "selector-hidden-filter-fallback", {ingredient(source_b, 1)}, {
  product(selector_hidden_filter, 1)
}, {allow_productivity = true})

local selector_decomposition_filter = item("selector-decomposition-filter", {coefficient = 1}).name
recipe(selector_decomposition_filter, {ingredient(source_a, 1)}, {
  product(selector_decomposition_filter, 1)
}, {allow_decomposition = false, allow_productivity = true})
recipe(prefix .. "selector-decomposition-filter-fallback", {ingredient(source_b, 1)}, {
  product(selector_decomposition_filter, 1)
}, {allow_productivity = true})

local selector_category = item("selector-category", {coefficient = 1}).name
recipe(prefix .. "selector-category-a-name", {ingredient(source_b, 1)}, {
  product(selector_category, 1)
}, {categories = {prefix .. "category-z"}, allow_productivity = true})
recipe(prefix .. "selector-category-z-name", {ingredient(source_a, 1)}, {
  product(selector_category, 1)
}, {categories = {prefix .. "category-a"}, allow_productivity = true})

local selector_subgroup = item("selector-subgroup", {coefficient = 1}).name
recipe(prefix .. "selector-subgroup-a-name", {ingredient(source_b, 1)}, {
  product(selector_subgroup, 1)
}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-b",
  allow_productivity = true
})
recipe(prefix .. "selector-subgroup-z-name", {ingredient(source_a, 1)}, {
  product(selector_subgroup, 1)
}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-a",
  allow_productivity = true
})

local selector_order = item("selector-order", {coefficient = 1}).name
recipe(prefix .. "selector-order-a-name", {ingredient(source_b, 1)}, {
  product(selector_order, 1)
}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-a",
  order = "z",
  allow_productivity = true
})
recipe(prefix .. "selector-order-z-name", {ingredient(source_a, 1)}, {
  product(selector_order, 1)
}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-a",
  order = "a",
  allow_productivity = true
})

local selector_omitted_order = item("selector-omitted-order", {coefficient = 1}).name
recipe(prefix .. "selector-omitted-order-a-name", {ingredient(source_a, 1)}, {
  product(selector_omitted_order, 1)
}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-a",
  allow_productivity = true
})
recipe(prefix .. "selector-omitted-order-z-name", {ingredient(source_b, 1)}, {
  product(selector_omitted_order, 1)
}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-a",
  order = "a",
  allow_productivity = true
})

local selector_omitted_order_no_main = item("selector-omitted-order-no-main", {
  coefficient = 1
}).name
recipe(prefix .. "selector-omitted-order-no-main-a-name", {ingredient(source_a, 2)}, {
  product(selector_omitted_order_no_main, 1),
  product(source_c, 1)
}, {
  categories = {prefix .. "category-a"},
  main_product = "",
  subgroup = prefix .. "subgroup-a",
  allow_productivity = true
})
recipe(prefix .. "selector-omitted-order-no-main-z-name", {ingredient(source_b, 2)}, {
  product(selector_omitted_order_no_main, 1),
  product(source_c, 1)
}, {
  categories = {prefix .. "category-a"},
  main_product = "",
  subgroup = prefix .. "subgroup-a",
  order = "a",
  allow_productivity = true
})

local selector_subgroup_identifier = item("selector-subgroup-identifier", {coefficient = 1}).name
recipe(prefix .. "selector-subgroup-identifier-a", {ingredient(source_a, 1)}, {
  product(selector_subgroup_identifier, 1)
}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-id-a",
  order = "a",
  allow_productivity = true
})
recipe(prefix .. "selector-subgroup-identifier-z", {ingredient(source_b, 1)}, {
  product(selector_subgroup_identifier, 1)
}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-id-z",
  order = "a",
  allow_productivity = true
})

local selector_tie = item("selector-tie", {coefficient = 1}).name
recipe(prefix .. "selector-tie-a", {ingredient(source_a, 1)}, {product(selector_tie, 1)}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-a",
  order = "a",
  allow_productivity = true
})
recipe(prefix .. "selector-tie-z", {ingredient(source_b, 1)}, {product(selector_tie, 1)}, {
  categories = {prefix .. "category-a"},
  subgroup = prefix .. "subgroup-a",
  order = "a",
  allow_productivity = true
})

local selector_multi_category = item("selector-multi-category", {coefficient = 1}).name
recipe(prefix .. "selector-multi-category-a", {ingredient(source_a, 1)}, {
  product(selector_multi_category, 1)
}, {
  categories = {prefix .. "category-a", prefix .. "category-z"},
  subgroup = prefix .. "subgroup-a",
  order = "a",
  allow_productivity = true
})
recipe(prefix .. "selector-multi-category-b", {ingredient(source_b, 1)}, {
  product(selector_multi_category, 1)
}, {
  categories = {prefix .. "category-m"},
  subgroup = prefix .. "subgroup-a",
  order = "a",
  allow_productivity = true
})

local selector_main_product = item("selector-main-product", {coefficient = 1}).name
local main_product_subgroup_a = item("main-product-subgroup-a", {
  weight = 100,
  subgroup = prefix .. "subgroup-a"
}).name
local main_product_subgroup_b = item("main-product-subgroup-b", {
  weight = 100,
  subgroup = prefix .. "subgroup-b"
}).name
recipe(prefix .. "selector-main-product-a-name", {ingredient(source_b, 1)}, {
  product(selector_main_product, 1),
  product(main_product_subgroup_b, 1)
}, {
  categories = {prefix .. "category-a"},
  main_product = main_product_subgroup_b,
  order = "a",
  allow_productivity = true
})
recipe(prefix .. "selector-main-product-z-name", {ingredient(source_a, 1)}, {
  product(selector_main_product, 1),
  product(main_product_subgroup_a, 1)
}, {
  categories = {prefix .. "category-a"},
  main_product = main_product_subgroup_a,
  order = "a",
  allow_productivity = true
})

local selector_main_product_order = item("selector-main-product-order", {
  coefficient = 1
}).name
local main_product_order_a = item("main-product-order-a", {
  weight = 100,
  order = "a"
}).name
local main_product_order_b = item("main-product-order-b", {
  weight = 100,
  order = "b"
}).name
recipe(prefix .. "selector-main-product-order-a-name", {ingredient(source_b, 2)}, {
  product(selector_main_product_order, 1),
  product(main_product_order_b, 1)
}, {
  categories = {prefix .. "category-a"},
  main_product = main_product_order_b,
  subgroup = prefix .. "subgroup-a",
  allow_productivity = true
})
recipe(prefix .. "selector-main-product-order-z-name", {ingredient(source_a, 2)}, {
  product(selector_main_product_order, 1),
  product(main_product_order_a, 1)
}, {
  categories = {prefix .. "category-a"},
  main_product = main_product_order_a,
  subgroup = prefix .. "subgroup-a",
  allow_productivity = true
})

local weight_default = item("weight-default").name
local weight_automatic = item("weight-automatic", {coefficient = 0.5}).name
recipe(weight_automatic, {ingredient(source_a, 4)}, {product(weight_automatic, 2)}, {
  allow_productivity = true
})
local weight_fluid = item("weight-fluid", {coefficient = 0.5}).name
recipe(weight_fluid, {ingredient(prefix .. "fluid", 2, "fluid")}, {product(weight_fluid, 1)}, {
  categories = {prefix .. "category-a"},
  allow_productivity = true
})
local weight_simple = item("weight-simple", {coefficient = 0.5, stack_size = 100}).name
recipe(weight_simple, {ingredient(source_a, 1)}, {product(weight_simple, 1)}, {
  allow_productivity = false
})
local weight_stack_rounded = item("weight-stack-rounded", {coefficient = 1, stack_size = 100}).name
recipe(weight_stack_rounded, {ingredient(source_a, 5)}, {product(weight_stack_rounded, 1)}, {
  allow_productivity = true
})
local weight_stack_fractional = item("weight-stack-fractional", {coefficient = 1}).name
recipe(weight_stack_fractional, {ingredient(source_a, 3)}, {
  product(weight_stack_fractional, 1)
}, {allow_productivity = true})
local weight_probability = item("weight-probability", {coefficient = 1}).name
recipe(weight_probability, {ingredient(source_a, 40000)}, {{
  type = "item",
  name = weight_probability,
  amount_min = 2,
  amount_max = 4,
  extra_count_fraction = 0.5,
  independent_probability = 0.5,
  shared_probability = {min = 0.2, max = 0.6}
}}, {allow_productivity = true})

local weight_range = item("weight-range", {coefficient = 1}).name
recipe(weight_range, {ingredient(source_a, 40000)}, {{
  type = "item",
  name = weight_range,
  amount_min = 2,
  amount_max = 4
}}, {allow_productivity = true})
local weight_reversed_range = item("weight-reversed-range", {coefficient = 1}).name
recipe(weight_reversed_range, {ingredient(source_a, 10)}, {{
  type = "item",
  name = weight_reversed_range,
  amount_min = 5,
  amount_max = 3
}}, {allow_productivity = true})
local weight_extra = item("weight-extra", {coefficient = 1}).name
recipe(weight_extra, {ingredient(source_a, 40000)}, {{
  type = "item",
  name = weight_extra,
  amount = 3,
  extra_count_fraction = 0.5
}}, {allow_productivity = true})
local weight_independent = item("weight-independent", {coefficient = 1}).name
recipe(weight_independent, {ingredient(source_a, 40000)}, {{
  type = "item",
  name = weight_independent,
  amount = 3,
  independent_probability = 0.5
}}, {allow_productivity = true})
local weight_shared = item("weight-shared", {coefficient = 1}).name
recipe(weight_shared, {ingredient(source_a, 40000)}, {{
  type = "item",
  name = weight_shared,
  amount = 3,
  shared_probability = {min = 0.2, max = 0.6}
}}, {allow_productivity = true})
local weight_combined = item("weight-combined", {coefficient = 1}).name
recipe(weight_combined, {ingredient(source_a, 40000)}, {{
  type = "item",
  name = weight_combined,
  amount_min = 2,
  amount_max = 4,
  independent_probability = 0.5,
  shared_probability = {min = 0.2, max = 0.6}
}}, {allow_productivity = true})

local cycle_a = item("cycle-a", {coefficient = 0.5}).name
local cycle_b = item("cycle-b", {coefficient = 0.5}).name
recipe(cycle_a, {ingredient(cycle_b, 1)}, {product(cycle_a, 1)}, {allow_productivity = true})
recipe(cycle_b, {ingredient(cycle_a, 1)}, {product(cycle_b, 1)}, {allow_productivity = true})

local one_step = item("one-step", {weight = 50}).name
recipe(one_step, {ingredient(source_a, 2)}, {product(one_step, 2)}, {allow_productivity = true})

local probability = item("probability", {weight = 100}).name
recipe(probability, {ingredient(source_a, 1)}, {{
  type = "item",
  name = probability,
  amount = 1,
  independent_probability = 0.5
}}, {allow_productivity = true})

local reversed_range = item("reversed-range", {weight = 100}).name
recipe(reversed_range, {ingredient(source_a, 5)}, {{
  type = "item",
  name = reversed_range,
  amount_min = 5,
  amount_max = 3
}}, {allow_productivity = true})

local duplicate_target = item("duplicate-target", {weight = 100}).name
recipe(duplicate_target, {ingredient(source_a, 3)}, {
  product(duplicate_target, 1),
  product(duplicate_target, 2)
}, {allow_productivity = true})

local intermediate = item("intermediate", {weight = 50}).name
recipe(intermediate, {ingredient(source_a, 2)}, {product(intermediate, 2)}, {
  allow_productivity = true
})
local expanded = item("expanded", {weight = 100}).name
recipe(expanded, {ingredient(intermediate, 2)}, {product(expanded, 1)}, {
  allow_productivity = true
})

local identical = item("identical-frontier", {weight = 100}).name
recipe(identical, {ingredient(source_a, 1)}, {product(identical, 1)}, {
  allow_productivity = true
})

local existing = item("existing-tooltip", {
  weight = 100,
  custom_tooltip_fields = {{
    name = {"", "Existing fixture"},
    value = {"", "kept"},
    order = 17
  }}
}).name
recipe(existing, {ingredient(source_a, 1)}, {product(existing, 1)}, {allow_productivity = true})

local fluid_failure = item("failure-fluid", {weight = 100}).name
recipe(fluid_failure, {ingredient(prefix .. "fluid", 1, "fluid")}, {
  product(fluid_failure, 1)
}, {categories = {prefix .. "category-a"}, allow_productivity = true})

local multiple_failure = item("failure-multiple", {weight = 100}).name
recipe(multiple_failure, {ingredient(source_a, 1)}, {
  product(multiple_failure, 1),
  product(source_b, 1)
}, {allow_productivity = true})

local same_name_fluid_product_failure = item("failure-same-name-fluid-product", {
  weight = 100
}).name
recipe(same_name_fluid_product_failure, {ingredient(source_a, 1)}, {
  product(same_name_fluid_product_failure, 1, "item"),
  product(same_name_fluid_product_failure, 1, "fluid")
}, {
  categories = {prefix .. "category-a"},
  allow_productivity = true
})

local catalyst_failure = item("failure-catalyst", {weight = 100}).name
recipe(catalyst_failure, {
  ingredient(catalyst_failure, 1),
  ingredient(source_a, 1)
}, {product(catalyst_failure, 1)}, {allow_productivity = true})

local zero_failure = item("failure-zero-output", {weight = 100}).name
recipe(zero_failure, {ingredient(source_a, 1)}, {{
  type = "item",
  name = zero_failure,
  amount = 1,
  independent_probability = 0
}}, {allow_productivity = true})

local missing_failure = item("failure-missing-weight", {weight = 100}).name
recipe(missing_failure, {ingredient(cursor_source, 1)}, {product(missing_failure, 1)}, {
  allow_productivity = true
})

local long_sources = {}
for index = 1, 24 do
  long_sources[index] = item(string.format("long-source-%02d", index), {
    weight = index,
    subgroup = index % 2 == 0 and prefix .. "subgroup-a" or prefix .. "subgroup-b",
    order = string.format("%02d", 25 - index)
  }).name
end
local long_target = item("long-target", {weight = 100}).name
local long_ingredients = {}
for index, name in ipairs(long_sources) do
  long_ingredients[index] = ingredient(name, index)
end
recipe(long_target, long_ingredients, {product(long_target, 1)}, {allow_productivity = true})

data:extend(prototypes)
