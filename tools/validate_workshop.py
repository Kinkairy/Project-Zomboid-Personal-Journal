#!/usr/bin/env python3
"""Cross-platform static contract gate for the Legacy Journal Workshop payload."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path


FLAGS = re.MULTILINE | re.DOTALL


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.project_root.resolve()
    errors: list[str] = []

    workshop = root / "workshop"
    mod = workshop / "Contents" / "mods" / "LegacyJournal"
    media = mod / "42.20" / "media"
    paths = {
        "mod_info": mod / "mod.info",
        "version_mod_info": mod / "42.20" / "mod.info",
        "workshop_metadata": workshop / "workshop.txt",
        "changelog": root / "CHANGELOG.md",
        "technical_reference": workshop / "docs" / "TECHNICAL_REFERENCE.md",
        "options": media / "sandbox-options.txt",
        "shared": media / "lua" / "shared" / "legacyjournal" / "legacyjournal_shared.lua",
        "actions": media / "lua" / "shared" / "legacyjournal" / "legacyjournal_actions.lua",
        "skillbook": media / "lua" / "shared" / "legacyjournal" / "legacyjournal_skillbook_compat.lua",
        "client": media / "lua" / "client" / "legacyjournal" / "legacyjournal_client.lua",
        "presentation": media / "lua" / "client" / "legacyjournal" / "legacyjournal_presentation.lua",
        "server": media / "lua" / "server" / "legacyjournal" / "legacyjournal_server.lua",
        "installer": workshop / "install_local.ps1",
        "windows_runner": root / "run_offline_tests.ps1",
        "nuc_runner": root / "run_nuc_tests.sh",
        "previous_zip": root / "recovery" / "legacy-journal-1.01-previous-release.zip",
        "previous_manifest": root / "recovery" / "legacy-journal-1.01-previous-release.manifest.sha256",
        "previous_zip_hash": root / "recovery" / "legacy-journal-1.01-previous-release.zip.sha256",
        "baseline_zip": root / "recovery" / "legacy-journal-1.02-accepted-baseline.zip",
        "baseline_manifest": root / "recovery" / "legacy-journal-1.02-accepted-baseline.manifest.sha256",
        "baseline_zip_hash": root / "recovery" / "legacy-journal-1.02-accepted-baseline.zip.sha256",
    }
    for label, path in paths.items():
        if not path.is_file():
            errors.append(f"Missing {label}: {path}")

    scan_directories = {
        "common AnimSets": mod / "common" / "media" / "AnimSets",
        "common actiongroups": mod / "common" / "media" / "actiongroups",
        "42.20 AnimSets": media / "AnimSets",
        "42.20 actiongroups": media / "actiongroups",
    }
    for label, path in scan_directories.items():
        if not path.is_dir():
            errors.append(f"Missing engine-scanned directory {label}: {path}")

    retired_public_files = (
        mod / "common" / "readme.txt",
        workshop / "legacyjournal_build.vdf",
        workshop / "workshop-description.bbcode",
    )
    for path in retired_public_files:
        if path.exists():
            errors.append(f"Retired or redundant public file must stay absent: {path}")

    test_names = (
        "skillbook_policy_test.lua",
        "instant_skillbook_sync_test.lua",
        "media_policy_test.lua",
        "server_protocol_test.lua",
        "client_action_protocol_test.lua",
        "journal_continuation_test.lua",
        "client_presentation_test.lua",
        "inventory_item_type_guard_test.lua",
        "context_menu_stack_test.lua",
        "write_delta_no_change_test.lua",
        "restore_paths_test.lua",
        "dynamic_page_count_test.lua",
    )
    for name in test_names:
        path = root / "tests" / name
        if not path.is_file():
            errors.append(f"Missing test {name}: {path}")

    if errors:
        return finish(errors)

    text = {
        name: path.read_text(encoding="utf-8-sig")
        for name, path in paths.items()
        if not name.endswith("_zip")
    }
    lua_files = sorted(media.rglob("*.lua"))
    all_lua = "\n".join(path.read_text(encoding="utf-8-sig") for path in lua_files)

    def require(source: str, pattern: str, label: str) -> None:
        if re.search(pattern, source, FLAGS) is None:
            errors.append(f"Missing {label}")

    def forbid(source: str, pattern: str, label: str) -> None:
        if re.search(pattern, source, FLAGS) is not None:
            errors.append(label)

    expected_recovery_files = {
        "legacy-journal-1.01-previous-release.zip",
        "legacy-journal-1.01-previous-release.manifest.sha256",
        "legacy-journal-1.01-previous-release.zip.sha256",
        "legacy-journal-1.02-accepted-baseline.zip",
        "legacy-journal-1.02-accepted-baseline.manifest.sha256",
        "legacy-journal-1.02-accepted-baseline.zip.sha256",
    }
    actual_recovery_files = {
        path.name for path in (root / "recovery").iterdir() if path.is_file()
    }
    if actual_recovery_files != expected_recovery_files:
        errors.append(
            "Recovery directory must contain only the retained 1.01 previous release "
            "and the 1.02 accepted baseline artifacts"
        )

    def verify_release_archive(prefix: str, expected_count: int, label: str) -> dict[str, str]:
        manifest_entries: dict[str, str] = {}
        for line in text[f"{prefix}_manifest"].splitlines():
            digest, relative_path = line.split(maxsplit=1)
            manifest_entries[relative_path.strip()] = digest
        if len(manifest_entries) != expected_count:
            errors.append(
                f"{label} manifest must contain {expected_count} files, "
                f"found {len(manifest_entries)}"
            )
        expected_zip_hash = text[f"{prefix}_zip_hash"].split()[0]
        actual_zip_hash = hashlib.sha256(paths[f"{prefix}_zip"].read_bytes()).hexdigest()
        if actual_zip_hash != expected_zip_hash:
            errors.append(f"{label} ZIP SHA-256 does not match its pinned hash")
        with zipfile.ZipFile(paths[f"{prefix}_zip"]) as archive:
            archive_entries = {
                name.removeprefix("LegacyJournal/"): hashlib.sha256(archive.read(name)).hexdigest()
                for name in archive.namelist()
                if name.startswith("LegacyJournal/") and not name.endswith("/")
            }
            bad_member = archive.testzip()
        if bad_member:
            errors.append(f"{label} ZIP integrity failure at {bad_member}")
        if archive_entries != manifest_entries:
            errors.append(
                f"{label} ZIP file set or per-file SHA-256 differs from the pinned manifest"
            )
        return manifest_entries

    verify_release_archive("previous", 22, "1.01 previous release")
    baseline_entries = verify_release_archive("baseline", 23, "1.02 accepted baseline")
    current_entries = {
        path.relative_to(mod).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
        for path in mod.rglob("*")
        if path.is_file()
    }
    baseline_runtime_entries = dict(baseline_entries)
    retired_readme = baseline_runtime_entries.pop("common/readme.txt", None)
    if retired_readme is None:
        errors.append("1.02 accepted baseline must contain the retired common/readme.txt")
    if baseline_runtime_entries != current_entries:
        errors.append(
            "Current runtime and metadata payload must match the 1.02 accepted baseline"
        )

    require(text["mod_info"], r"B42\.20", "B42.20 test marker in mod.info")
    for metadata in (text["mod_info"], text["version_mod_info"]):
        require(metadata, r"^name=Personal Journal\s*$", "English in-game mod name")
        require(metadata, r"^id=LegacyJournal\s*$", "stable Mod ID")
        require(metadata, r"^modversion=1\.02\s*$", "1.02 mod version")
    require(text["workshop_metadata"], r"^id=3788037313\s*$", "stable Workshop ID")
    require(text["workshop_metadata"], r"^visibility=public\s*$", "public Workshop visibility")
    changelog_versions = re.findall(r"^## ([0-9.]+)\s*$", text["changelog"], re.MULTILINE)
    if changelog_versions != ["1.02", "1.01"]:
        errors.append("Public changelog must contain only versions 1.02 and 1.01")
    require(text["technical_reference"], r"12 个 Fengari 行为测试", "current behavior-test count in technical reference")
    forbid(
        text["technical_reference"],
        r"MULTIPLAYER_SERVER_RUNBOOK|README_TEST|真人测试辅助 Mod|11 个 Fengari",
        "Technical reference contains retired internal or stale test content",
    )
    for name in ("SkillXP", "KnownRecipes", "SkillBooks", "TrainingMedia"):
        require(
            text["options"],
            rf"option LegacyJournal\.{name}\s*=\s*\{{\s*type = boolean, default = true",
            f"boolean sandbox option {name}",
        )

    sandbox_translation_keys = (
        "Sandbox_LegacyJournal",
        "Sandbox_LegacyJournal_SkillXP",
        "Sandbox_LegacyJournal_KnownRecipes",
        "Sandbox_LegacyJournal_SkillBooks",
        "Sandbox_LegacyJournal_TrainingMedia",
        "Sandbox_LegacyJournal_TrainingMedia_tooltip",
        "Sandbox_LegacyJournal_WriteTimeMultiplier",
        "Sandbox_LegacyJournal_WriteTimeMultiplier_tooltip",
        "Sandbox_LegacyJournal_ReadTimeMultiplier",
        "Sandbox_LegacyJournal_ReadTimeMultiplier_tooltip",
        "Sandbox_LegacyJournal_RecoveryPercent",
        "Sandbox_LegacyJournal_RecoveryPercent_tooltip",
    )
    for locale in ("EN", "CN", "CH"):
        locale_dir = media / "lua" / "shared" / "Translate" / locale
        translation_paths = {
            "sandbox_json": locale_dir / "Sandbox.json",
            "context_json": locale_dir / "ContextMenu.json",
            "ui_json": locale_dir / "IG_UI.json",
        }
        for label, path in translation_paths.items():
            if not path.is_file():
                errors.append(f"Missing {label} {locale} translation: {path}")
                continue
            content = path.read_text(encoding="utf-8-sig")
            if label == "sandbox_json":
                for key in sandbox_translation_keys:
                    require(content, rf'"{key}"\s*:', f"{locale} sandbox translation key {key}")
            elif label == "context_json":
                expected_context_keys = {
                    "ContextMenu_LegacyJournal_Write",
                    "ContextMenu_LegacyJournal_CannotWrite",
                }
                expected_cannot_write = {
                    "CN": "无内容可写",
                    "CH": "無內容可寫",
                    "EN": "Nothing to write",
                }
                try:
                    context_values = json.loads(content)
                    if set(context_values) != expected_context_keys:
                        errors.append(
                            f"{locale} context-menu translation keys must be exactly "
                            "Write and CannotWrite"
                        )
                    if context_values.get("ContextMenu_LegacyJournal_CannotWrite") != expected_cannot_write[locale]:
                        errors.append(f"{locale} CannotWrite text does not match the approved vanilla-style wording")
                except json.JSONDecodeError:
                    pass
            else:
                require(content, r"IGUI_LegacyJournal_Name", f"{locale} journal-name translation key")
            if path.suffix == ".json":
                try:
                    json.loads(content)
                except json.JSONDecodeError as exc:
                    errors.append(f"Invalid {label} JSON for {locale}: {exc}")
        legacy_sandbox = locale_dir / f"Sandbox_{locale}.txt"
        if legacy_sandbox.exists():
            errors.append(f"Obsolete pre-B42 sandbox translation must be removed: {legacy_sandbox}")

    scripts_dir = media / "scripts"
    if scripts_dir.is_dir():
        scripts = "\n".join(path.read_text(encoding="utf-8-sig") for path in scripts_dir.rglob("*") if path.is_file())
        forbid(scripts, r"^\s*(item|recipe)\s+", "Custom item or recipe declaration found under media/scripts")

    shared = text["shared"]
    actions = text["actions"]
    skillbook = text["skillbook"]
    client = text["client"]
    presentation = text["presentation"]
    server = text["server"]

    forbid(all_lua, r"sendSyncXp", "Forbidden sendSyncXp reference found")
    shared_requirements = (
        (r"function LJ\.captureSkillBooks", "skill-book capture function"),
        (r"function LJ\.getPermanentRewardMedia", "permanent-reward media index"),
        (r"function LJ\.captureKnownMediaRewards", "recorded-media capture function"),
        (r"for mediaType = 0, 1 do", "CD and VHS media enumeration"),
        (r"mediaData:getId\(\)", "stable media ID capture"),
        (r"getTextGuid\(\)", "VHS line GUID capture"),
        (r"addKnownMediaLine", "VHS restore"),
        (r"LJ_mediaRewards", "compact media reward persistence"),
        (r'LJ_mediaRewardMode\s*=\s*"whole-media"', "whole-media restore policy"),
        (r"function LJ\.applySkillBookProgress", "skill-book restore function"),
        (r"getLevelSkillTrained\(\)", "B42 script-item skill-book minimum level"),
        (r"getLvlSkillTrained\(\)", "inventory-item compatibility fallback"),
        (r"effectivePages\s*=\s*math\.max\(currentPages, targetPages\)", "non-decreasing skill-book read policy"),
        (r"normalizeStoredSkillBookMultiplier\(multiplier\).*?>\s*normalizeStoredSkillBookMultiplier\(currentMultiplier\)", "precision-safe non-decreasing skill-book multiplier policy"),
        (r"must not alone enable the menu.*read action", "multiplayer multiplier exclusion note"),
        (r"normalizeStoredSkillXp\(targetValue\).*?>\s*normalizeStoredSkillXp\(currentXp\)", "precision-safe missing skill XP read detection"),
        (r"function LJ\.encodeSkillBookStates", "exact skill-book state encoder"),
        (r"function LJ\.decodeSkillBookStates", "exact skill-book state decoder"),
        (r"function LJ\.captureSkillBookStates", "actual skill-book multiplier capture"),
        (r"xpObject:getMultiplier\(", "public XP multiplier capture"),
        (r"state\.minLevel", "skill-book multiplier minimum-level persistence"),
        (r"state\.maxLevel", "skill-book multiplier maximum-level persistence"),
        (r"LJ_skillBookStates", "exact skill-book state persistence"),
        (r"function LJ\.getRecordVersion", "journal version validation"),
        (r"function LJ\.migrateRecord", "journal version migration"),
        (r"return version, version == LJ\.VERSION", "exact-version journal acceptance"),
        (r"function mergeSkillBookSnapshot", "loss-safe skill-book snapshot merge"),
        (r"if not captured then return mergedBooks end", "skill-book enumeration failure retention"),
        (r"mergedBooks\[fullType\] = pages", "observable latest skill-book snapshot update"),
        (r"function LJ\.getSkillBookEntries", "all recorded skill-book entries function"),
        (r"function LJ\.getApplicableSkillBookEntries", "skill-book level eligibility function"),
        (r"player:hasTrait\(CharacterTrait\.ILLITERATE\)", "illiterate skill-book restriction"),
        (r"entry\.minLevel\s*<=\s*nextLevel\s*and\s*nextLevel\s*<=\s*entry\.maxLevel", "vanilla skill-book level range restriction"),
        (r"table\.sort\(fullTypes\)", "deterministic skill-book restore order"),
        (r"addXpNoMultiplier\(player, perk", "native no-multiplier XP path"),
        (r"addXpMultiplier", "native skill-book multiplier rebuild"),
        (r"function LJ\.hasDelta", "new-category delta test"),
        (r'\["Base\.Diary1"\]\s*=\s*true', "first vanilla diary support"),
        (r'\["Base\.Diary2"\]\s*=\s*true', "second vanilla diary support"),
        (r"function LJ\.getActionPageCount", "content-derived page model"),
        (r"LJ\.ACTION_PAGE_RATE_NUMERATOR\s*=\s*7", "page-rate numerator"),
        (r"LJ\.ACTION_PAGE_RATE_DENOMINATOR\s*=\s*1000", "page-rate denominator"),
        (r"LJ\.ACTION_PROGRESS_MODEL_VERSION\s*=\s*2", "progress-model version"),
        (r"function LJ\.getPagesForContentUnits", "single content-unit page formula"),
        (r"math\.ceil\(math\.max\(0, tonumber\(units\) or 0\).*?LJ\.ACTION_PAGE_RATE_NUMERATOR / LJ\.ACTION_PAGE_RATE_DENOMINATOR\)", "single-rounding page-rate formula"),
        (r"function LJ\.getSavedActionPage", "saved continuation lookup"),
        (r"LJ_progressAction", "continuation action binding"),
        (r"LJ_progressActor", "continuation actor binding"),
        (r"savedPage \* totalPages / savedTotalPages", "legacy proportional continuation migration"),
        (r"return clamp\(savedPage, 0, totalPages\)", "same-model continuation clamp"),
        (r"function LJ\.saveActionProgress", "saved continuation update"),
        (r"md\.LJ_progressModelVersion = LJ\.ACTION_PROGRESS_MODEL_VERSION", "saved progress-model marker"),
        (r"function LJ\.clearActionProgress", "completed continuation cleanup"),
        (r"md\.LJ_progressModelVersion = nil", "progress-model cleanup"),
        (r"gameTime:getMinutesPerDay\(\)", "vanilla reading-time day length"),
        (r"delta\.books", "book duration/delta accounting"),
        (r"delta\.vhs", "VHS duration/delta accounting"),
        (r"function LJ\.isAuthor", "author-only restore gate"),
        (r"function LJ\.refreshJournalPresentation", "localized journal presentation"),
        (r"function LJ\.getActionSignature", "shared action snapshot binding"),
        (r"LJ\.encodeSkillBookStates\(delta\.mergedBookStates\)", "write signature binds skill-book state"),
        (r"md\.LJ_skillBookStates", "read signature binds skill-book state"),
        (r"getItemWithIDRecursiv", "recursive inventory lookup"),
    )
    for pattern, label in shared_requirements:
        require(shared, pattern, label)
    forbid(shared, r"getMultiplierMap\(\)", "Forbidden direct XP multiplier-map access found")
    read_delta = re.search(r"function LJ\.getReadDelta.*?function LJ\.hasDelta", shared, FLAGS)
    if read_delta and re.search(r"getActiveSkillBookMultiplier|targetMultiplier|multiplierMissing", read_delta.group(0)):
        errors.append("getReadDelta must not enable reading from an unobservable multiplier-only difference")
    forbid(shared, r"savedTotalPages\s*~=\s*totalPages", "Protocol 6 must preserve continuation across signature/page-count changes")

    require(skillbook, r"character:setAlreadyReadPages\(self\.item:getFullType\(\), pages\)", "instant skill-book character-page repair")
    require(skillbook, r"character:isTimedActionInstant\(\)", "instant-only skill-book compatibility guard")

    for source, requirements in (
        (client, (
            (r"LJ\.getActionPageCount\(action, delta\)", "singleplayer-derived action pages"),
            (r'"begin"', "client begin command"),
            (r"Events\.OnServerCommand\.Add", "client server-command handler"),
            (r"ISInventoryPane\.getActualUniqueItems\(items\)", "B42 vanilla unique-stack representative extraction"),
            (r"ISInventoryPaneContextMenu\.transferIfNeeded\(player, item\)", "vanilla transfer-before-journal action"),
            (r"LegacyJournalBeginRequestAction", "post-transfer journal request action"),
            (r"inventory:containsRecursive\(self\.item\)", "post-transfer inventory verification"),
            (r"local function syncWrittenJournal", "server-driven client journal presentation sync"),
            (r'require "legacyjournal/legacyjournal_presentation"', "client presentation module load"),
            (r"item:setCustomName\(true\)", "native custom-name persistence"),
            (r"LegacyJournalTooltipInstalled", "idempotent tooltip hook"),
            (r"writeOption\.notAvailable\s*=\s*true|disableOption\(writeOption", "always-visible disabled write option"),
            (r"ContextMenu_LegacyJournal_CannotWrite", "single custom write-disabled tooltip"),
            (r"ContextMenu_EmptyNotebook", "vanilla no-readable-content tooltip"),
            (r"ContextMenu_Read_Note", "vanilla note-option removal"),
            (r"ISInventoryPaneContextMenu\.onWriteSomething\(item, false, playerIndex\)", "vanilla read-only journal window"),
        )),
        (presentation, (
            (r"ISInventoryPane\.refreshContainer", "vanilla visible-container refresh hook"),
            (r"LJ\.refreshJournalPresentation", "localized visible journal refresh"),
            (r"LegacyJournalPresentationInstalled", "idempotent presentation hook"),
        )),
        (actions, (
            (r"action\.item:getID\(\)", "timed-action itemId payload"),
            (r"journalJobType\(\s*getText\(LJ\.WRITE_TEXT_KEY\), self\.item, self\.character\)", "localized written-journal write title"),
            (r'journalJobType\(\s*getText\("ContextMenu_Read"\), self\.item, self\.character\)', "localized written-journal read title"),
            (r"if not LJ\.isWritten\(item\) then return actionText end", "first-write action-only title boundary"),
            (r"item:getName\(character\)", "player-aware vanilla item-name lookup"),
            (r"CharacterActionAnims\.Read", "vanilla read animation"),
            (r"setOverrideHandModels\(nil, item\)", "vanilla journal hand model"),
            (r"action\.forceProgressBar\s*=\s*true", "vanilla timed-action progress bar"),
            (r"action\.character:setReading\(true\)", "local reading-state start"),
            (r"action\.character:setReading\(false\)", "local reading-state cleanup"),
            (r"function LegacyJournalWriteAction:forceCancel\(\)", "queued write cancellation cleanup"),
            (r"function LegacyJournalReadAction:forceCancel\(\)", "queued read cancellation cleanup"),
            (r'saveProgress\(action, "cancel"\)', "multiplayer interruption cancellation command"),
            (r'saveProgress\(self, "checkpoint"\)', "multiplayer page checkpoint command"),
            (r'LJ\.MODULE, "commit"', "client completion commit command"),
        )),
        (server, (
            (r"LJ\.getActionPageCount\(action, delta\)", "server-derived action pages"),
            (r"LJ\.isAuthor\(player, item\)", "server author-only read validation"),
            (r"function LJ\.serverBeginAction", "server begin protocol"),
            (r"function LJ\.serverCommitAction", "server commit protocol"),
            (r"function LJ\.serverCancelAction", "server interrupted-action cancellation"),
            (r"function LJ\.serverCheckpointAction", "server page checkpoint protocol"),
            (r'command == "commit"', "server completion command route"),
            (r'command == "checkpoint"', "server checkpoint command route"),
            (r'command == "cancel"', "server cancellation command route"),
            (r"delta = delta", "server-side begin delta state"),
            (r'state\.token ~= tostring\(token or ""\)', "server token validation"),
            (r"pendingActions\[player\] = nil", "server duplicate commit prevention"),
            (r"LJ\.getActionSignature\(action, item, delta\) ~= state\.signature", "server changed-payload rejection"),
            (r"written=", "begin trace written state summary"),
            (r"deltaXp=", "begin trace XP delta summary"),
            (r"skills=", "begin trace skill delta summary"),
            (r"recipes=", "begin trace recipe delta summary"),
            (r"books=", "begin trace skill-book delta summary"),
            (r"vhs=", "begin trace training-media delta summary"),
            (r"local ACTION_ABANDON_MS = 2 \* 60 \* 60 \* 1000", "independent abandoned-action lease"),
            (r"startedAt \+ ACTION_ABANDON_MS", "duration-independent abandoned-action cleanup"),
            (r"function LJ\.serverExpireActions", "server abandoned-action cleanup"),
            (r'sendServerCommand\(player, LJ\.MODULE, "begin"', "server begin acknowledgement"),
            (r"item:syncItemFields\(\)", "native journal-item synchronization"),
            (r"local function syncJournalItem", "server-authoritative journal item synchronization"),
            (r'require "legacyjournal/legacyjournal_skillbook_compat"', "server instant skill-book compatibility load"),
            (r"local function sendItemFields", "server-to-client journal presentation fields"),
            (r"LJ\.isSupportedItem\(item\)", "server vanilla-item validation"),
            (r"LJ\.hasWritingTool\(player\)", "server writing-tool validation"),
            (r"LJ\.canCurrentCharacterUpdate\(player, item\)", "server author validation"),
        )),
    ):
        for pattern, label in requirements:
            require(source, pattern, label)

    forbid(client, r"sendClientCommand.{0,350}(skills|recipes|skillBooks|vhsLines)", "Client command appears to send journal knowledge data")
    forbid(all_lua, r"ContextMenu_LegacyJournal_NoReadableContent", "Custom no-readable-content key must not remain in payload Lua")
    forbid(client, r"getContextMenuItem|getContextMenuGroupKey|getContextMenuGroups", "Journal context menu must use the vanilla unique-stack representative path")
    forbid(client, r"item:syncItemFields\(\)", "Client must not send stale journal ModData through syncItemFields")
    forbid(client, r"entry\.items\[1\]", "Invalid B42 dummy inventory-stack entry selection found")
    forbid(presentation, r"syncItemFields|sendClientCommand", "Client presentation layer must remain local-only")
    forbid(actions, r"function LegacyJournal(?:Write|Read)Action:complete", "Journal client actions must finish through perform")
    forbid(actions, r"function LegacyJournal(?:Write|Read)Action:isUsingTimeout", "Journal actions must inherit normal timeout completion")
    forbid(actions, r"serverStartReading|serverStopReading", "Legacy Journal must not persist reading state through custom server callbacks")
    forbid(server, r"expiresAt\s*=\s*startedAt\s*\+\s*durationMs", "Journal action expiry must not derive from duration")
    forbid(all_lua, r"的\s*(?:日志|日誌)", "Hardcoded Chinese journal name found in Lua")
    for locale in ("EN", "CN", "CH"):
        context_path = media / "lua" / "shared" / "Translate" / locale / "ContextMenu.json"
        forbid(context_path.read_text(encoding="utf-8-sig"), r"ContextMenu_LegacyJournal_NoReadableContent",
            f"Custom no-readable-content translation must not remain for {locale}")

    for source_name in ("actions", "server"):
        require(text[source_name], r"20260831-page-rate7of1000-localized-job-item-write-tooltip-guard-5",
            f"1.02 build marker in {source_name}")

    require(shared, r'instanceof\(item, "InventoryItem"\)',
        "B42 InventoryItem type guard before journal item APIs")

    forbid(actions, r"item:getName\(\)",
        "Timed-action job titles must not append the internal English item name")
    forbid(all_lua, r"ContextMenu_LegacyJournal_(?:NoRecordableContent|NeedWritingTool|WrongAuthor|NoReadableContent)",
        "Obsolete reason-specific journal tooltip key found")

    require(text["installer"], r"Assert-TreeEqual", "installer SHA-256 readback")
    require(text["installer"], r"\[guid\]::NewGuid", "collision-free installer staging")
    require(text["installer"], r"\$rollbackError", "installer rollback error handling")
    require(text["installer"], r"Move-Item -LiteralPath \$backup -Destination \$targetRoot", "installer backup restore path")
    for runner_name in ("windows_runner", "nuc_runner"):
        require(text[runner_name], r"luaparse@0\.3\.0", f"pinned Lua parser in {runner_name}")
        require(text[runner_name], r"fengari-node-cli@0\.1\.0", f"pinned Lua runtime in {runner_name}")
        require(text[runner_name], r"--offline", f"offline cached-package mode in {runner_name}")
        for test_name in test_names:
            require(text[runner_name], re.escape(test_name), f"{test_name} declaration in {runner_name}")
    require(text["nuc_runner"], r"stack traceback", "Lua error-text detection in nuc_runner")
    require(text["nuc_runner"], r"behavior test process failed", "process exit-code detection in nuc_runner")

    return finish(errors)


def finish(errors: list[str]) -> int:
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("Legacy Journal cross-platform static validation: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
