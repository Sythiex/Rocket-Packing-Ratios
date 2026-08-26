# Rocket Packing Ratios

Rocket Packing Ratios is a Factorio 2.1 data-stage mod for Space Age. It will add an item-tooltip comparison between shipping a finished item and shipping the ingredients needed to craft the same expected quantity at the destination.

The accepted behavior and calculation rules are recorded in [`docs/design.md`](docs/design.md). The implementation is not included in this initial development scaffold.

## Development setup

Copy `.factorio-local.example.json` to the ignored `.factorio-local.json` and set `factorio_root` to a Factorio 2.1 installation containing Space Age. This workspace is already configured locally when `.factorio-local.json` is present.

Package and smoke-test the mod without writing to the Factorio installation:

```powershell
& .\tools\run-factorio.ps1 -Mode SmokeTest
```

The runner packages the source, creates a clean save, and reloads it with every writable game path isolated under `.factorio-test/`. Generated files are ignored by Git.

Other development commands:

```powershell
# Create or replace the isolated development save.
& .\tools\run-factorio.ps1 -Mode Create

# Open that save in the game UI (user-invoked only).
& .\tools\run-factorio.ps1 -Mode Gui

# Preview a local install without changing the Factorio installation.
& .\tools\install-local.ps1 -WhatIf
```

Release ZIPs produced by the tooling use Factorio's required `rocket-packing-ratios_<version>/` root directory and exclude repository metadata, documentation, tools, tests, and isolated game state.
