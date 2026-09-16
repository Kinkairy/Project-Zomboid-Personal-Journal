# Personal Journal 1.3.2: B42.20-only package cleanup

The obsolete `workshop/Contents/mods/LegacyJournal/mod.info` was removed.
`42.20/mod.info` is the sole Mod entry and remains version 1.3.2.
The `common` directory is preserved. All 22 remaining runtime files are unchanged.
No gameplay code, journal data schema, recipes, recovery rules or save data changed.

Clean runtime Git tree: `d6d43d081cc79e653b7f03b365a4cd15926b28b0`.
Previous 23-file tree: `8d596b117980754ef7ad0b5459b4c89224e6201b`.
Run `python3 validate_release.py` from this project to check the exact payload.
`release-manifest.json` is outside the distributable Mod folder and must not be
copied into `Contents`. The manifest pins the bytes of all 22 runtime files.

The private project's validator checks sealed historical recovery ZIPs independently;
it no longer requires current 1.3.2 source to equal the old 1.3 recovery package.
Historical archives remain immutable. NUC-native Lua fingerprint gates are retained.

Old deployment scripts pinned to the 23-file tree cannot package this layout.
Use the B42-only cleaned deployment script. Remove only the redundant root entry
from old installed copies; never delete `42.20/mod.info`, `common`, or backup folders.

This source cleanup is not a claim that Steam Workshop was uploaded. Publishing
must update existing item 3788037313 and return a same-item SteamCMD success receipt.
A Git push, generated VDF, prepared ZIP or Steam login is not an upload receipt.

## 简体中文

仅删除根目录的旧 `mod.info`，保留 `42.20/mod.info`（版本 1.3.2）及 `common`。
其余 22 个运行文件逐字不变，不修改历史恢复包或存档。旧的 23 文件部署器不再适用。

## 繁體中文

僅刪除根目錄的舊 `mod.info`，保留 `42.20/mod.info`（版本 1.3.2）及 `common`。
其餘 22 個執行檔案逐字不變，不修改歷史恢復包或存檔。舊的 23 檔案部署器不再適用。
