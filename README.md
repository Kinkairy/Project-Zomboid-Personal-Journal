# Personal Journal

Personal Journal records a survivor's learned knowledge in a vanilla diary. After
death, a successor on the same multiplayer account can recover the physical
journal and read it to restore only the knowledge the new character is missing.

Current release: **1.02** for Project Zomboid Build 42.20. Version 1.02 is the
current and sole accepted rollback baseline.

- [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3788037313)
- Mod ID: `LegacyJournal`
- Workshop ID: `3788037313`
- No external Mod dependencies

## What it records

- Skill XP with positive progress
- Known recipes
- Skill-book pages and active vanilla XP multiplier state
- CD/VHS media with permanent skill, XP, or recipe rewards

Entertainment-only media is ignored. Reading never lowers stronger existing
state, and deterministic recovery percentages cannot be rerolled by repeatedly
reading the same journal.

## Vanilla-style behavior

The Mod uses vanilla diaries (`Base.Diary1` and `Base.Diary2`), writing tools,
context menus, reading animations, timed actions, and item synchronization. It
adds no custom item or recipe. Interrupted writing and reading continue from the
last server-accepted page. Multiplayer calculations and commits are performed by
the server; clients do not submit knowledge snapshots.

Version 1.02 directly changes the content-unit page formula from 10 to 7 pages
per 1000 units, rounded once. Work that formerly produced 1000 pages now produces
700 pages. Both writing and reading use the same updated base page model; vanilla
reader traits still affect reading time.

## Installation

Subscribe through Steam Workshop, or copy
`workshop/Contents/mods/LegacyJournal` into the Project Zomboid Mods directory.
The included `workshop/install_local.ps1` performs a verified local Windows
installation with rollback.

## Repository policy

The immutable `v1.02` tag and release archive preserve the exact published
23-file payload. The `main` branch contains the same runtime and metadata files
but omits the obsolete non-runtime `common/readme.txt`. The repository retains
only the 1.02 rollback ZIP, manifest, and checksum. Internal test harnesses,
server operations, credentials, private paths, raw logs, caches, redundant
Workshop-description copies, publisher-local build files, and artwork without
confirmed public redistribution provenance are excluded.

This is an unofficial community project and is not affiliated with The Indie Stone.
Licensed under the [MIT License](LICENSE).
