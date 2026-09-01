# Personal Journal

[简体中文](#简体中文) | [English](#english)

## 简体中文

Personal Journal（个人日志）会把幸存者已掌握的知识记录到原版日记本中。人物死亡后，
同一多人账号的新角色只有找回实体日志并阅读，才会恢复日志中记录、且当前角色尚未掌握的知识。

当前版本：适用于 Project Zomboid Build 42.20 的 **1.02**。1.02 是当前版本，也是唯一认可的
回滚基线。

- [Steam 创意工坊](https://steamcommunity.com/sharedfiles/filedetails/?id=3788037313)
- Mod ID：`LegacyJournal`
- Workshop ID：`3788037313`
- 无其他 Mod 依赖

### 记录内容

- 已获得正进度的技能 XP
- 已知配方
- 技能书已读页数和有效的原版 XP 倍率状态
- 含永久技能、XP 或配方奖励的 CD/VHS 培训媒体

纯娱乐媒体不会被记录。阅读日志绝不会降低当前角色更高的已有状态；确定性的恢复比例也不能
通过反复阅读同一本日志重新抽取或累加。

### 原版风格

本 Mod 使用原版日记本（`Base.Diary1` 和 `Base.Diary2`）、书写工具、右键菜单、阅读动画、
TimedAction 和物品同步，不新增自定义物品或配方。读写中断后会从服务器最后接受的页数继续。
多人游戏中的计算与最终提交均由服务器执行，客户端不会上传知识快照。

1.02 直接把内容单位的原始页数公式从每 1000 单位 10 页改为 7 页，并且只在最后取整一次。
原来需要 1000 页的内容现在需要 700 页。读与写共用这一更新后的基础页数模型；原版快读和
慢读特质仍会影响阅读时间。

### 安装

可直接订阅 Steam 创意工坊，也可以把 `workshop/Contents/mods/LegacyJournal` 复制到
Project Zomboid 的 Mods 目录。仓库中的 `workshop/install_local.ps1` 可在 Windows 上执行
带校验和回滚的本地安装。

### 仓库规则

不可变的 `v1.02` 标签和 Release 归档保存已发布的完整 23 文件载荷。`main` 分支保留相同的
运行与元数据文件，但不包含已淘汰的非运行时 `common/readme.txt`。仓库只保留 1.02 的回滚
ZIP、manifest 和校验文件。内部测试工具、服务器运维信息、凭据、私有路径、原始日志、缓存、
重复的创意工坊说明、发布者本地构建文件，以及未确认可公开再分发的美术素材均不进入公开仓库。

这是非官方社区项目，与 The Indie Stone 无关联。项目采用 [MIT License](LICENSE)。

## English

Personal Journal records a survivor's learned knowledge in a vanilla diary. After
death, a successor on the same multiplayer account can recover the physical
journal and read it to restore only the knowledge the new character is missing.

Current release: **1.02** for Project Zomboid Build 42.20. Version 1.02 is the
current and sole accepted rollback baseline.

- [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3788037313)
- Mod ID: `LegacyJournal`
- Workshop ID: `3788037313`
- No external Mod dependencies

### What it records

- Skill XP with positive progress
- Known recipes
- Skill-book pages and active vanilla XP multiplier state
- CD/VHS media with permanent skill, XP, or recipe rewards

Entertainment-only media is ignored. Reading never lowers stronger existing
state, and deterministic recovery percentages cannot be rerolled by repeatedly
reading the same journal.

### Vanilla-style behavior

The Mod uses vanilla diaries (`Base.Diary1` and `Base.Diary2`), writing tools,
context menus, reading animations, timed actions, and item synchronization. It
adds no custom item or recipe. Interrupted writing and reading continue from the
last server-accepted page. Multiplayer calculations and commits are performed by
the server; clients do not submit knowledge snapshots.

Version 1.02 directly changes the content-unit page formula from 10 to 7 pages
per 1000 units, rounded once. Work that formerly produced 1000 pages now produces
700 pages. Both writing and reading use the same updated base page model; vanilla
reader traits still affect reading time.

### Installation

Subscribe through Steam Workshop, or copy
`workshop/Contents/mods/LegacyJournal` into the Project Zomboid Mods directory.
The included `workshop/install_local.ps1` performs a verified local Windows
installation with rollback.

### Repository policy

The immutable `v1.02` tag and release archive preserve the exact published
23-file payload. The `main` branch contains the same runtime and metadata files
but omits the obsolete non-runtime `common/readme.txt`. The repository retains
only the 1.02 rollback ZIP, manifest, and checksum. Internal test harnesses,
server operations, credentials, private paths, raw logs, caches, redundant
Workshop-description copies, publisher-local build files, and artwork without
confirmed public redistribution provenance are excluded.

This is an unofficial community project and is not affiliated with The Indie Stone.
Licensed under the [MIT License](LICENSE).
