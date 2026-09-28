# Personal Journal 1.3.3

Record and recover character progression using the journal.

- Game: Project Zomboid Build 42.20.
- Mod ID: `LegacyJournal`.
- Current complete runtime: `workshop/Contents/mods/LegacyJournal/`.
- Translation source: `translations/catalog.json` when included in this repository.
- License: [LICENSE](LICENSE).

This repository keeps current source and its required resources. Historical repair
packages, recovery archives and duplicate engineering documents have been retired
from the active tree. Git history remains available.

## 1.3.3 native-action fix

Fixes recording/recovery startup on B42.21.0. Knowledge actions use the native
ISBaseTimedAction animation interfaces directly, while keeping the existing
native queue, server ownership, interruption checkpoints and item-field sync.
They no longer start the separate vanilla text-editor workflow. The existing
instant skill-book page-sync patch also covers the same reproduced native defect
on 42.21.0. Recorded knowledge, workload, restore rules and saves are preserved. The installed B42.21 Lua reproduces the outgoing failure; the repaired
source passes all 17 action, progress, storage, restore and presentation suites.
Workshop publication and owner game acceptance are tracked separately.

## Development

Use the translation catalog and included generators when changing localized text.
Preserve the matching EN, CN and CH entries. Run the available source validators
and regression tests before release. Offline validation does not establish
in-game or multiplayer acceptance.
