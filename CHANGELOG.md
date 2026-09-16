# Changelog

## 1.3.2

- Drives multiplayer journal progress from server samples rather than a separate
  client countdown, including the inventory and overhead bars and resumed work.
- Labels server-progress, result-application and native-completion waits instead
  of leaving an unexplained full reading bar.
- Scopes progress responses to an individual action; late, regressive and invalid
  responses cannot update a later read or a different local player.
- Keeps native server completion, knowledge validation and whole-page checkpoints.

## 1.3.1

- Keeps unavailable skill fields without producing unusable restore deltas.
- Restores a missing valid skill-book multiplier even when read pages already match.
- Routes multiplayer supplemental responses to the authenticated local actor.

## 1.3

- 优化性能

## 1.02

- Changed the original content-unit page formula from 10 to 7 pages per 1000
  units, with a single final rounding step; content that produced 1000 pages
  now produces 700.
- Preserves the completed proportion of unversioned 1.01 interrupted actions
  when first resumed under the new page formula.
- Reuses vanilla `ContextMenu_EmptyNotebook` when an author's journal contains
  no recoverable content and removes the redundant custom translation.
- Keeps an already-written journal's localized/custom title visible while it is
  updated or read, using vanilla's player-aware name lookup instead of the
  item's internal English name. A first write remains action-text-only.
- Removes the obsolete pre-B42 `Sandbox_*.txt` translation duplicates; Build 42
  now has one maintained JSON sandbox translation source per locale.
- Consolidates Mod-specific write-disabled reasons into one vanilla-style
  tooltip; read-disabled state continues to reuse vanilla `ContextMenu_EmptyNotebook`.
