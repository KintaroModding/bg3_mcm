# About this fork

This repository is a fork of [BG3-MCM](https://github.com/AtilioA/BG3-MCM), the **Mod Configuration Menu** for
Baldur's Gate 3 by **Volitio** (AtilioA). All of the mod is Volitio's work. The official downloads are on
[Nexus Mods](https://www.nexusmods.com/baldursgate3/mods/9162).

## Why it exists

The upstream repository has no GitHub releases. This fork builds releases from the published source code, so that
the download and the source match, and so that the mod stays maintainable in any case. The fork is listed on
[openmods](https://openmods.nexus), which links to its releases.

## What this fork changes

The package keeps the author's UUID (`755a8a72-407f-4f0d-9a33-274ac0f0b53d`), folder (`BG3MCM`) and name, so a mod
that depends on MCM works with this build in the same way. Players install only one copy: this build or the official
one.

Changes to the mod (modified version under the AGPL-3.0, section 5):

- 2026-10-20, version 1.41.0.1: the sidebar with the list of mods is always shown. It no longer collapses when a mod
  page opens, it never fades, and nothing toggles it: no expansion on hover, no Caps Lock key, no show/hide buttons,
  no gamepad Back toggle. The settings "Enable expansion on icon hover", "Enable automatic sidebar collapse", "Start
  collapsed", "Toggle sidebar (collapse/expand)" and "Sidebar animation duration (ms)" are removed. "Sidebar width"
  stays and now applies at once. Files: `DualPaneController.lua`, `LeftPane.lua`, `RightPaneHeaderActions.lua`,
  `InitHandles.lua`, `IMGUIAPI.lua`, `MCMProxy.lua`, `MCM_blueprint.json`, and the English and Brazilian Portuguese
  description of the width setting. Every changed place in the code carries a `bg3_mcm build` comment.
- 2026-10-20, version 1.41.0.2: the title of the MCM window ends with "(KintaroModding)", for example "Mod
  Configuration Menu 1.41.0.2 (KintaroModding)", so players can tell this build from the official one. File:
  `MCMRendering.lua`.
- The version is the upstream version, and its last digit counts the builds of this fork: 1.41.0.1 was the first
  changed build of upstream 1.41.0.0.

On 2026-10-20 this fork also added these files:

- `build.ps1`: builds `output/bg3_mcm.pak`. It copies `Mod Configuration Menu/` without editor folders (`.vscode`),
  converts `Localization/<Language>/*.loca.xml` into the `.loca` files that the game reads, and packs the result with
  LSLib (`Divine.exe`).
- `deploy.ps1`: copies the package into the game's `Mods` folder.
- `openmods.json`, `openmods.md`: the listing on openmods.
- `FORK.md`: this file.

## Branches and releases

- `main` follows the upstream repository.
- `release` is the upstream commit that carries the released version, plus the changes and files above. The first
  release is built from upstream commit `4d8a05c` (2026-03-21), which set version 1.41.0.0; with the changes above it
  is 1.41.0.2.
- A release is tagged `v<version>` with the version from `Mod Configuration Menu/Mods/BG3MCM/meta.lsx`, and has
  `bg3_mcm.pak` attached.
- To update: merge the upstream commit that raises the version into `release`, keep the changes at the
  `bg3_mcm build` comments, set the version to the upstream version plus 1 in the last digit, run `build.ps1`, test,
  and release.

## Reports

Problems with MCM itself belong to the [upstream repository](https://github.com/AtilioA/BG3-MCM/issues). Problems
with this build or its release belong to this fork.

## License

GNU Affero General Public License v3.0, unchanged (see [LICENSE](LICENSE)). Bundled third-party parts keep their own
licenses: the fonts Inter and OpenDyslexic (SIL Open Font License 1.1, with their license files) and reactivex (MIT,
`Lua/Lib/reactivex/LICENSE`).
