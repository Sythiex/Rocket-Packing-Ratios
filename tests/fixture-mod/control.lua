local prefix = "rocket-packing-ratios-test-"

local expected_weights = {
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
  ["selector"] = 100,
  ["selector-catalyst"] = 200,
  ["selector-hand"] = 100,
  ["selector-category"] = 200,
  ["selector-subgroup"] = 100,
  ["selector-order"] = 100,
  ["selector-omitted-order"] = 200,
  ["selector-omitted-order-no-main"] = 100,
  ["selector-subgroup-identifier"] = 200,
  ["selector-intermediate"] = 200,
  ["selector-hidden-filter"] = 200,
  ["selector-decomposition-filter"] = 200,
  ["selector-main-product"] = 50,
  ["selector-main-product-order"] = 100,
  ["cycle-a"] = 25,
  ["cycle-b"] = 50
}

script.on_init(function()
  storage.reported = false
end)

script.on_event(defines.events.on_tick, function()
  if storage.reported then
    return
  end
  storage.reported = true

  local failures = {}
  for suffix, expected in pairs(expected_weights) do
    local prototype = prototypes.item[prefix .. suffix]
    local actual = prototype and prototype.weight
    if actual == nil or math.abs(actual - expected) > 1 / 65536 then
      failures[#failures + 1] = string.format(
        "%s expected=%.12g actual=%s",
        suffix,
        expected,
        tostring(actual)
      )
    end
  end

  if #failures == 0 then
    log("[Rocket Packing Ratios test driver] PASS engine-weight-fixtures=" ..
      tostring(table_size(expected_weights)))
  else
    log("[Rocket Packing Ratios test driver] FAIL " .. table.concat(failures, "; "))
    log("[Rocket Packing Ratios test driver] probability-products " ..
      serpent.line(prototypes.recipe[prefix .. "weight-probability"].products))
  end
  game.set_game_state({
    game_finished = true,
    player_won = #failures == 0,
    can_continue = false
  })
end)
