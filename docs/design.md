# Rocket Packing Ratios Design

## Identity and platform

- Public title: **Rocket Packing Ratios**
- Internal mod ID: `rocket-packing-ratios`
- Tooltip label: **Rocket packing ratio**
- Required platform: Factorio 2.1 with Space Age

## User-facing behavior

Add a custom item-tooltip row immediately below the native **Rocket capacity** row when possible:

```text
Rocket packing ratio: 0.775× vs [item=iron-plate][item=iron-gear-wheel][item=electronic-circuit] · 1.33× vs [item=iron-plate][item=copper-plate]
```

A value greater than `1×` means shipping the finished item delivers more finished-item equivalents for the same payload weight. A value below `1×` means shipping the displayed ingredients and crafting remotely delivers more equivalents.

Use three significant digits and continuous payload weight. Do not round to whole rockets, stacks, or recipe batches. Show every distinct comparison ingredient once as a rich-text `[item=name]` icon; ingredient amounts affect the ratio but are not printed. Do not cap the icon count. Allow the fixed-width native tooltip to wrap and do not rely on red/green color. When direct and expanded comparisons have the same ingredient frontier, show only one value.

## Calculation

For a selected recipe producing expected target quantity `q`:

```text
        sum(ingredient amount × ingredient item weight)
ratio = -------------------------------------------------
                  q × finished item weight
```

The rocket lift capacity cancels from this ratio and must not be included.

The direct comparison uses the selected recipe's immediate item ingredients. The expanded comparison recursively decomposes canonical hand-crafting intermediates. Expansion stops at ingredients that cannot be further produced as hand-crafting intermediates, yielding plate-level leaves for examples such as assembling machine 1 rather than continuing into ores, mining, or fluids.

## Canonical recipe selection

Apply Factorio's documented item-weight recipe selection at the root and each recursive step:

1. Exclude hidden recipes and recipes with decomposition disabled.
2. Prefer a recipe whose name equals the produced item name.
3. Prefer recipes that do not use the item as a catalyst.
4. Prefer recipes usable as hand-crafting intermediates.
5. Use category, subgroup, and order as the remaining precedence.

Do not show alternate-recipe values or min/max ranges. Use expected output quantities for probabilistic products. Ignore productivity, modules, quality, research state, and surface-specific availability.

## Coverage and compatibility

Process all eligible item prototypes from base, Space Age, and enabled third-party mods. Append to existing `custom_tooltip_fields`; never replace another owner's fields. Items with no eligible production recipe receive no row. Version one has no mod settings. Use localization keys for the field label and unavailable reasons; English is sufficient initially, but the structure must remain translation-ready.

## Unsupported cases

If an eligible recipe cannot be evaluated safely, show a short localized reason, for example:

```text
Rocket packing ratio: Unavailable — fluid packaging undefined
```

Initial structured reasons are:

- Multiple products
- Fluid packaging undefined
- Cyclic recipe
- Ambiguous production recipe
- Missing item weight
- No expected output
- Unsupported catalyst

If the direct ratio succeeds and only expansion fails, preserve the direct result:

```text
Rocket packing ratio: 0.920× vs [item icons] · expanded unavailable — cyclic recipe
```

Do not invent a cost allocation for multiple valuable products, a packaging rule for fluids, or a resolution for recipe cycles.

## Non-goals

Do not model rocket construction or launch cost; crafting time, energy, machines, or modules; productivity, quality, or research state; destination availability; spoilage; whole-rocket packing; incomplete batches; optimal alternative recipes; or economic allocation among multiple products. The metric is solely a payload-weight comparison.

## Intended implementation shape

1. Use `data-final-fixes.lua`; avoid a runtime `control.lua` unless data-stage testing disproves feasibility.
2. Enumerate finalized eligible item types and recipes.
3. Resolve explicit weights and reproduce Factorio's automatic item-weight behavior where effective finalized weights are unavailable.
4. Keep canonical recipe selection separately testable.
5. Build direct and recursive ingredient frontiers with memoization, cycle detection, and structured results.
6. Format localized values with rich-text item tags and append a `CustomTooltipField`.
7. Empirically choose and regression-test the tooltip `order` needed for adjacency to Rocket capacity.

## Verification checklist

- A one-step item-only recipe displays one ratio.
- Assembling machine 1 displays distinct direct and plate-level expanded ratios.
- Multi-count and probabilistic target outputs normalize by expected quantity.
- Explicit and automatically derived weights agree with native Rocket capacity semantics.
- A non-craftable raw item receives no row.
- Fluid, multi-product, catalyst, zero-output, and cyclic fixtures show the intended reason.
- Direct success is preserved when recursive expansion fails.
- Existing custom tooltip fields survive unchanged.
- Modded item and recipe prototypes are discovered automatically.
- Long icon lists wrap without truncation.
- Tooltip placement and Factoriopedia rendering are visually checked in Factorio 2.1.

## Primary references

- Factorio item-weight algorithm: <https://lua-api.factorio.com/latest/auxiliary/item-weight.html>
- `CustomTooltipField`: <https://lua-api.factorio.com/latest/types/CustomTooltipField.html>
- Rich-text item tags: <https://wiki.factorio.com/rich_text>
- `ItemPrototype.weight`: <https://lua-api.factorio.com/latest/prototypes/ItemPrototype.html>
- Native tooltip-order caveat: <https://forums.factorio.com/viewtopic.php?p=676076>
