# RemainingCastCount

Shows on your action buttons how many times you can still cast each spell with your current mana. Requires WoW: Forever (interface 16001).

## Download

- [GitHub releases](https://github.com/alexbauerde/RemainingCastCount/releases)

## Features

- A number on every action button with a mana spell: how many casts your current mana still pays for.
- Warning colors: 0 in red, 1–2 in yellow (can be turned off).
- Works with the Blizzard action bars and with LibActionButton bars (Bartender, ElvUI and others).
- Turn the number off for single spells, or for single spell ranks.
- Font size and color, and drag the number to where it should sit on the button.
- Minimap button and addon compartment entry.
- English and German.

## Usage

- `/rcc` opens the settings.
- `/rcc debug` prints what the addon sees on your buttons (helpful in bug reports).

## Releasing

Releases are built by GitHub Actions ([release.yml](.github/workflows/release.yml)) with the [BigWigs packager](https://github.com/BigWigsMods/packager):

For a release, add a `## X.Y.Z (YYYY-MM-DD)` section with the changes at the top of [CHANGELOG.md](CHANGELOG.md), commit and push to `main`. Every new version heading that reaches `main` releases right away, so add it only when you want to release.

That's all: the [Tag workflow](.github/workflows/tag.yml) sees the new version at the top of the changelog, runs luacheck, tags the commit `vX.Y.Z` and starts the [Release workflow](.github/workflows/release.yml). That one writes the release notes from the changelog section, puts the version into the TOC (`@project-version@`) and attaches the zip to a GitHub release.

CurseForge and Wago uploads switch on once the TOC has `## X-Curse-Project-ID` / `## X-Wago-ID` and the repository has the `CF_API_KEY` / `WAGO_API_TOKEN` secrets.

Every push is checked by [luacheck](.github/workflows/lint.yml); run `luacheck .` locally before committing.

## Bugs and ideas

[Open an issue](https://github.com/alexbauerde/RemainingCastCount/issues).
