# Personal Journal

[简体中文](#简体中文) | [English](#english)

## 简体中文

Personal Journal（个人日志）是面向 Project Zomboid Build 42.20 的服务端权威知识记录 Mod。
它使用原版日记本保存人物知识，让同一多人账号的新角色在找回实体日志后，恢复自己尚未掌握的
部分。

- 当前版本：`1.3`
- Mod ID：`LegacyJournal`
- Workshop ID：`3788037313`
- 数据格式：`LJ_version=6`
- 外部依赖：无
- 当前唯一正常开发/回滚基准：`1.3`；上个正式版 `1.2` 仅作兜底（历史标识 `1.02`）
- 维护状态：冷维护，仅按明确维护需求修复

完整字段、协议、兼容规则和已知边界见
[TECHNICAL_REFERENCE.md](https://github.com/Kinkairy/Project-Zomboid-Personal-Journal/blob/main/docs/TECHNICAL_REFERENCE.md)。

### 核心设计

- 只使用原版 `Base.Diary1` 和 `Base.Diary2`，不新增物品或配方。
- 多人模式由服务器计算差值、验证作者和物品、提交最终状态；客户端不上传知识快照。
- 恢复只补充当前人物缺少的知识，不降低或覆盖更高 XP、更多技能书页数或已经学会的新配方。
- 配方、技能书和培训媒体使用稳定排序与确定性恢复配额，重复阅读不能重新抽取或逐次刷满。
- 只接受精确的 v6 数据，不猜测迁移无版本、旧版、损坏版或未来版日志。
- 中断进度绑定实体日志、动作和人物，并由服务器保存单调整页检查点。
- 移除 Mod 后物品仍是原版日记本，重新安装后可再次识别有效日志数据。

### 架构

| 模块 | 职责 |
| --- | --- |
| `legacyjournal_shared.lua` | 数据模型、快照、差值、页数、写入与恢复规则 |
| `legacyjournal_actions.lua` | 原生网络动作生命周期、动画和整页检查点 |
| `legacyjournal_client.lua` | 右键菜单、物品转移和多人请求 |
| `legacyjournal_server.lua` | 活动动作检查点提示及恢复结果补充同步 |
| `legacyjournal_presentation.lua` | 本地化名称与显示刷新 |
| `legacyjournal_skillbook_compat.lua` | Build 42 技能书兼容 |

多人数据流复用原生网络 TimedAction：客户端排入动作，服务端建立计划并在原生 `complete`
边界重新验证物品、身份和知识状态，然后执行写入或恢复。检查点提示不携带页码，服务端从
原生动作进度计算已完成整页。单人模式复用相同共享规则，不维护第二套玩法实现。

### 记录与恢复

- 技能 XP 保存历史最高值，恢复时只补足恢复比例目标以下的缺失 XP。
- 配方只学习当前人物未知的条目，因此人物死亡后先学会的新配方不会被日志覆盖。
- 技能书只提高已读页数和当前等级适用的倍率状态。
- 只有含永久技能、XP 或配方奖励的 CD/VHS 才会记录；纯娱乐媒体忽略。

### 页数与时间

读写内容先换算为内容单位，再直接计算：

```text
pages = max(1, ceil(units * 7 / 1000))
```

1.02 修改的是原始累计率，不是先按旧公式得到整数页数再乘 `0.70`。读与写共用该基础页数
模型；阅读继续保留原版快读、慢读、阅读眼镜和坐地修正，沙盒读写倍率仍独立生效。

### 兼容与边界

- 目标版本仅为 Project Zomboid Build 42.20。
- 作者授权优先绑定服务器认证 username；缺少 username 的早期日志会回退人物显示名。
- 原生动作负责多人计时与生命周期；该 Mod 不承诺防御被修改的游戏引擎。
- 中断只保存完成的整页，不保证从精确百分比继续；正式写入按内容量计时，不固定 30 秒。

### 仓库结构

```text
docs/TECHNICAL_REFERENCE.md           完整技术参考
recovery/                             1.3 基准与 1.2 兜底恢复载体
workshop/Contents/mods/LegacyJournal  Mod 运行源码与元数据
workshop/install_local.ps1            本地安装器
CHANGELOG.md                          公开变更记录
CONTRIBUTING.md                       贡献说明
SECURITY.md                           漏洞报告方式
```

公开仓库不包含内部测试工具、服务器地址、发布凭据、原始日志或私有运维流程。

### 获取

玩家请使用 [Steam 创意工坊](https://steamcommunity.com/sharedfiles/filedetails/?id=3788037313)。
源码安装时，将 `workshop/Contents/mods/LegacyJournal` 复制到 Project Zomboid Mods 目录。

这是非官方社区项目，与 The Indie Stone 无关联。项目采用 [MIT License](LICENSE)。

## English

Personal Journal is a server-authoritative knowledge-recording Mod for Project Zomboid Build 42.20.
It stores character knowledge on a vanilla diary and lets a successor on the same multiplayer account
restore only the state they are still missing after recovering the physical item.

- Current version: `1.3`
- Mod ID: `LegacyJournal`
- Workshop ID: `3788037313`
- Data schema: `LJ_version=6`
- External dependencies: none
- Sole normal development/rollback baseline: `1.3`; previous formal `1.2` is emergency fallback only
  (historically identified as `1.02`)
- Maintenance: cold maintenance; fixes only for explicit maintenance needs

See
[TECHNICAL_REFERENCE.md](https://github.com/Kinkairy/Project-Zomboid-Personal-Journal/blob/main/docs/TECHNICAL_REFERENCE.md)
for complete fields, protocol details, compatibility rules, and known boundaries.

### Core Design

- Only vanilla `Base.Diary1` and `Base.Diary2` items are used; no item or recipe is added.
- In multiplayer, the server computes deltas, validates the author and item, and commits the final state.
  Clients never upload knowledge snapshots.
- Recovery only fills missing knowledge. It never lowers or overwrites stronger XP, further skill-book
  progress, or recipes already learned by the reader.
- Recipes, skill books, and training media use stable ordering and deterministic recovery quotas, so
  repeated reads cannot reroll or gradually accumulate the result.
- Only exact v6 records are accepted. Unversioned, old, damaged, and future schemas are not guessed.
- Interrupted work is bound to the physical journal, action, and character, with monotonic whole-page
  checkpoints stored by the server.
- Removing the Mod leaves a vanilla diary; reinstalling can recognize valid journal data again.

### Architecture

| Module | Responsibility |
| --- | --- |
| `legacyjournal_shared.lua` | Data model, snapshots, deltas, page counts, writes, and recovery |
| `legacyjournal_actions.lua` | Native network action lifecycle, animation, and page checkpoints |
| `legacyjournal_client.lua` | Context menus, item transfer, and multiplayer requests |
| `legacyjournal_server.lua` | Active-action checkpoint hints and supplementary recovery synchronization |
| `legacyjournal_presentation.lua` | Localized names and presentation refresh |
| `legacyjournal_skillbook_compat.lua` | Build 42 skill-book compatibility |

Multiplayer uses native network TimedActions. The client queues an action; the server prepares its plan
and revalidates the item, identity, and knowledge state at native completion before writing or restoring.
Checkpoint hints carry no page value: completed pages come from authoritative native action progress.
Single-player reuses the same shared rules rather than maintaining a second gameplay implementation.

### Recording and Recovery

- Skill XP stores the highest observed value; recovery only fills XP below the scaled target.
- Recipes are learned only when unknown, so recipes learned after death but before reading are preserved.
- Skill books only raise read pages and multiplier state applicable to the current skill range.
- CD/VHS media is recorded only when it contains a permanent skill, XP, or recipe reward.

### Page and Time Model

Read and write content is converted into content units and then calculated directly:

```text
pages = max(1, ceil(units * 7 / 1000))
```

Version 1.02 changes the original accumulation rate directly; it does not calculate rounded pages with
the old formula and then multiply by `0.70`. Reading and writing share this base page model. Vanilla
reader traits and independent sandbox multipliers remain in effect.

### Compatibility and Boundaries

- The supported target is Project Zomboid Build 42.20 only.
- Author access prefers the server-authenticated username; early records without it fall back to the
  character display name.
- Native actions own multiplayer timing and lifecycle; the Mod does not promise protection against a
  modified game engine.
- Interrupted work saves whole pages, not the exact displayed percentage. Formal writing scales with
  content rather than taking a fixed 30 seconds.

### Repository Layout

```text
docs/TECHNICAL_REFERENCE.md           Complete technical reference
recovery/                             1.3 baseline and 1.2 emergency fallback artifacts
workshop/Contents/mods/LegacyJournal  Runtime source and Mod metadata
workshop/install_local.ps1            Local installer
CHANGELOG.md                          Public change history
CONTRIBUTING.md                       Contribution guide
SECURITY.md                           Vulnerability reporting
```

The public repository excludes internal test harnesses, server addresses, publishing credentials, raw
logs, and private operational procedures.

### Distribution

Players should use the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3788037313).
For a source installation, copy `workshop/Contents/mods/LegacyJournal` into the Project Zomboid Mods
directory.

This is an unofficial community project and is not affiliated with The Indie Stone.
Licensed under the [MIT License](LICENSE).
