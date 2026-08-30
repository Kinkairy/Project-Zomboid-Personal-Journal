# Changelog

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

## 1.01

- Fixed multiplayer journal writing and reading completion.
- Added server-authoritative page checkpoints and interrupted-action continuation.
- Added support for both vanilla diary variants.
- Generates writing and reading page counts from the amount of knowledge being
  recorded or restored, then applies the vanilla per-page book timing formula.
- Preserves server-accepted pages across repeated interruptions, including
  cases where the survivor learns additional state between attempts.
- Records exact skill-book read pages and active vanilla multiplier state.
- Prevents duplicate context-menu entries for stacked diaries by normalizing
  Build 42 inventory selections to unique actual item instances.
- Keeps localized journal presentation separate from authoritative persisted
  state so moving a journal between containers does not lock in server-language
  display text.
