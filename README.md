# Personal Journal 1.3.2

Record and recover character progression using the journal.

- Game: Project Zomboid Build 42.20.
- Mod ID: `LegacyJournal`.
- Current complete runtime: `workshop/Contents/mods/LegacyJournal/`.
- Translation source: `translations/catalog.json` when included in this repository.
- License: [LICENSE](LICENSE).

This repository keeps current source and its required resources. Historical repair
packages, recovery archives and duplicate engineering documents have been retired
from the active tree. Git history remains available.

## Development

Use the translation catalog and included generators when changing localized text.
Preserve the matching EN, CN and CH entries. Run the available source validators
and regression tests before release. Offline validation does not establish
in-game or multiplayer acceptance.

Release validation is in tests/validate_release.py. Run python3 tests/validate_release.py
from the repository root, or pass --root to validate an explicit source directory.
