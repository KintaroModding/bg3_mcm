# About this fork

This repository is a fork of [BG3-MCM](https://github.com/AtilioA/BG3-MCM), the **Mod Configuration Menu** for
Baldur's Gate 3 by **Volitio** (AtilioA). All of the mod is Volitio's work. The official downloads are on
[Nexus Mods](https://www.nexusmods.com/baldursgate3/mods/9162).

## Why it exists

The upstream repository has no GitHub releases. This fork builds releases from the published source code, so that
the download and the source match, and so that the mod stays maintainable in any case. The fork is listed on
[openmods](https://openmods.nexus), which links to its releases.

## What this fork changes

Nothing in `Mod Configuration Menu/`, the content of the package: UUID (`755a8a72-407f-4f0d-9a33-274ac0f0b53d`),
folder (`BG3MCM`), name and version stay the author's. A mod that depends on MCM works with this build in the same
way. Players install only one copy: this build or the official one.

On 2026-10-20 this fork added these files (modified version under the AGPL-3.0, section 5):

- `build.ps1`: builds `output/bg3_mcm.pak`. It copies `Mod Configuration Menu/` without editor folders (`.vscode`),
  converts `Localization/<Language>/*.loca.xml` into the `.loca` files that the game reads, and packs the result with
  LSLib (`Divine.exe`).
- `deploy.ps1`: copies the package into the game's `Mods` folder.
- `openmods.json`, `openmods.md`: the listing on openmods.
- `FORK.md`: this file.

## Branches and releases

- `main` follows the upstream repository.
- `release` is the upstream commit that carries the released version, plus the files above. The first release is
  built from upstream commit `4d8a05c` (2026-03-21), which set version 1.41.0.0.
- A release is tagged `v<version>` with the version from `Mod Configuration Menu/Mods/BG3MCM/meta.lsx`, and has
  `bg3_mcm.pak` attached.
- To update: merge the upstream commit that raises the version into `release`, run `build.ps1`, test, and release.

## Reports

Problems with MCM itself belong to the [upstream repository](https://github.com/AtilioA/BG3-MCM/issues). Problems
with this build or its release belong to this fork.

## License

GNU Affero General Public License v3.0, unchanged (see [LICENSE](LICENSE)). Bundled third-party parts keep their own
licenses: the fonts Inter and OpenDyslexic (SIL Open Font License 1.1, with their license files) and reactivex (MIT,
`Lua/Lib/reactivex/LICENSE`).
