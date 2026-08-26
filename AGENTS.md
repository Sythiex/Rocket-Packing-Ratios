# Rocket Packing Ratios Agent Instructions

These instructions apply to the entire repository. Read `docs/design.md` before changing implementation code; it is the source of truth for accepted behavior, calculation semantics, compatibility, and scope.

## Baseline

- Target Factorio 2.1 and require Space Age.
- Keep the stable internal name `rocket-packing-ratios`. Prefix owned identifiers with `rocket-packing-ratios-` or `rocket_packing_ratios` as appropriate.
- Preserve the MIT license.
- Do not silently change an accepted design decision. When implementation evidence requires a change, update `docs/design.md` and explain the evidence.
- Keep this data-stage-only unless testing proves runtime code is necessary. Do not add `control.lua` preemptively.

## Read-only Factorio installation

The ignored `.factorio-local.json` normally identifies the local Factorio installation. `ROCKET_PACKING_RATIOS_FACTORIO_ROOT` may override its `factorio_root` value.

Treat that installation as read-only reference material. Agents may inspect `doc-html`, bundled definitions under `data`, official mod metadata, and the executable version. Do not modify the installation, install this mod into its `mods` directory, or use its writable game paths for validation.

Game-backed tests must use the isolated paths under `.factorio-test/` created by `tools/run-factorio.ps1`. Do not launch the GUI without user approval.

## Structure

Use conventional Factorio layout:

```text
info.json
data-final-fixes.lua
locale/en/rocket-packing-ratios.cfg
scripts/                 # pure calculation and data-stage support modules, when needed
tests/                   # unpublished fixtures and validation support, when needed
tools/
docs/design.md
```

Add `data.lua` or `data-updates.lua` only for a concrete ordering need. Put player-facing text in locale files. Use `__rocket-packing-ratios__/...` for mod-owned resources.

## Data-stage implementation

- Append to `custom_tooltip_fields`; never replace existing fields.
- Enumerate eligible finalized item prototype types and recipes.
- Separate canonical recipe selection, weight resolution, direct calculation, recursive expansion, and tooltip formatting into testable modules.
- Return structured successes and failures from calculation code. Localize only at the presentation boundary.
- Sort candidates and displayed names with explicit stable keys; never let `pairs` order affect behavior.
- Memoize recursive expansion and detect cycles without mutating prototypes.
- Preserve expected quantities and continuous weights; do not add stack, rocket, or batch rounding.
- Use official Factorio 2.1 documentation and bundled prototypes as authoritative. Cover any approximation of undocumented engine behavior with a game-backed fixture.

## Verification

Use the smallest relevant checks:

1. Validate JSON and PowerShell syntax.
2. Check Lua module paths, locale keys, rich-text item names, and deterministic ordering.
3. Run pure calculation fixtures once those modules exist.
4. Run `& .\tools\run-factorio.ps1 -Mode SmokeTest` for an isolated Factorio 2.1 load.
5. Inspect `.factorio-test/factorio-current.log` before claiming a game-backed pass.
6. Visually check native tooltip adjacency, wrapping, and Factoriopedia rendering before release.

Create `.factorio-local.json` from the tracked example if needed:

```json
{
  "factorio_root": "C:\\path\\to\\Factorio"
}
```

Useful commands:

```powershell
& .\tools\run-factorio.ps1 -Mode SmokeTest
& .\tools\run-factorio.ps1 -Mode Create
& .\tools\run-factorio.ps1 -Mode Gui
& .\tools\install-local.ps1 -WhatIf
```

`tools/package-mod.ps1` owns the release allowlist and ZIP layout. Keep packages, test saves, logs, and write-data out of Git. `tools/install-local.ps1` deliberately writes to the configured Factorio installation; agents may check it with `-WhatIf` but must not install without an explicit request.

## External references

External projects are references, not a source pool. Before copying or closely adapting third-party code or assets, identify the exact revision and license, confirm compatibility, obtain user approval, and record required attribution. Prefer independent implementation from official APIs and reference installed Factorio resources instead of redistributing Wube assets.
