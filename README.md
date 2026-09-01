# Personal Journal

[简体中文](#简体中文) | [English](#english)

## 简体中文

Personal Journal（个人日志）是面向 Project Zomboid Build 42.20 的服务端权威知识记录 Mod。
它使用原版日记本保存人物知识快照，并允许同一多人账号的新角色在找回实体日志后恢复自己尚未
掌握的部分。

- 当前版本：`1.02`
- Mod ID：`LegacyJournal`
- Workshop ID：`3788037313`
- 数据格式：`LJ_version=6`
- 运行依赖：无
- 当前唯一认可回滚基线：`v1.02`

详细字段、公式、协议与兼容规则见
[技术参考](https://github.com/Kinkairy/Project-Zomboid-Personal-Journal/blob/main/docs/TECHNICAL_REFERENCE.md)。

### 设计目标与核心不变量

- 只支持原版 `Base.Diary1` 和 `Base.Diary2`，不新增物品或配方。
- 多人模式由服务器计算知识差值、验证物品和作者、签发事务令牌并提交最终状态。
- 客户端只发送动作意图、日志实体 ID 和整页进度，不上传 XP、配方或媒体快照。
- 恢复只补充当前人物缺少的状态，不降低或覆盖人物已经拥有的更高 XP、更多页数或新配方。
- 配方、技能书和培训媒体采用稳定排序与确定性配额；重复阅读不能重新抽取或逐次刷满。
- 只接受精确的 v6 数据，不猜测迁移无版本、旧版、损坏版或未来版日志。
- 中断进度绑定实体日志、动作和人物，并由服务器按单调页码保存。

### 架构

| 模块 | 职责 |
| --- | --- |
| `legacyjournal_shared.lua` | 数据模型、快照、差值、页数、签名、写入与恢复规则 |
| `legacyjournal_actions.lua` | 原版风格 TimedAction、动画、进度条和整页检查点 |
| `legacyjournal_client.lua` | 右键菜单、物品转移、请求发送和结果接收 |
| `legacyjournal_server.lua` | 服务端验证、事务令牌、检查点、提交和字段同步 |
| `legacyjournal_presentation.lua` | 本地化物品名称与显示刷新 |
| `legacyjournal_skillbook_compat.lua` | Build 42 技能书页数与倍率兼容 |

多人写入或阅读事务：

```text
右键菜单
  -> begin(action, itemId)
  -> 服务器重新定位物品、计算差值并签发一次性 token
  -> TimedAction 提交 checkpoint/cancel
  -> commit(action, itemId, token)
  -> 服务器重新验证签名并原子写入或恢复
  -> 原生物品字段和人物字段同步
```

服务端提交时会再次执行以下验证，而不是信任 `begin` 时的旧状态：递归背包内重新定位物品、
确认日记本类型和精确 schema、校验作者与书写工具、重新计算差值和签名、先消费一次性令牌，
最后调用共享层的 `commitWrite` 或 `applyRead`。每名玩家同时只保留一个待提交动作；配方与
媒体结果分批下发，避免单个同步包无限增长。

单人模式复用相同的共享差值、页数和恢复函数，不维护第二套玩法规则。

### 持久化与恢复语义

知识记录保存在实体日记本的 `modData`，主要包括技能 XP、已知配方、技能书页数与倍率状态、
有效培训媒体、作者身份、写入时间和中断进度。

| 字段组 | 主要字段 | 含义 |
| --- | --- | --- |
| 身份 | `LJ_written`、`LJ_version` | 日志标记与精确数据格式 |
| 作者 | `LJ_authorName`、`LJ_authorUser`、`LJ_authorDescId` | 展示名、账号和人物描述符 |
| 知识 | `LJ_skills`、`LJ_recipes` | 历史技能 XP 与已知配方集合 |
| 技能书 | `LJ_skillBooks`、`LJ_skillBookStates` | 已读页数、技能 ID、倍率和等级区间 |
| 培训媒体 | `LJ_mediaRewards`、`LJ_mediaRewardMode` | 稳定媒体 ID 与奖励类型掩码 |
| 续作 | `LJ_progressAction`、`LJ_progressSignature`、`LJ_progressActor`、`LJ_progressPage`、`LJ_progressTotalPages`、`LJ_progressModelVersion` | 中断动作的服务器检查点 |

集合编码前按稳定键排序，用于得到可重复的快照签名、恢复选择和差值结果。

- 技能 XP 保存历史最高值；恢复目标为记录值乘恢复比例，只补足缺失 XP。
- 配方只学习当前人物未知的条目，因此死亡后先学会的新配方不会被日志覆盖。
- 技能书恢复只提高已读页数和当前等级适用的倍率状态。
- 只有含永久技能、XP 或配方奖励的 CD/VHS 才进入记录；纯娱乐媒体忽略。
- 成功写入或恢复后清理临时续作字段，日志主体数据继续保留在原版物品上。

### 页数与时间模型

读写内容先换算为内容单位，再直接使用：

```text
writeUnits = 600
           + changedSkills * 120
           + ceil(XP / 100)
           + newRecipes * 90
           + changedSkillBooks * 100
           + mediaLines * 8

readUnits  = 900
           + changedSkills * 90
           + ceil(XP / 100) * 0.8
           + missingRecipes * 75
           + missingSkillBooks * 85
           + missingMediaLines * 6

pages = max(1, ceil(units * 7 / 1000))
```

1.02 修改的是原始累计率，不是先按旧公式得到整数页数再乘 `0.70`。读与写共用该基础页数
模型；阅读继续保留原版快读、慢读、阅读眼镜和坐地修正，沙盒读写倍率仍独立生效。

### 中断续作与版本兼容

- 历史检查点必须匹配同一实体日志、动作类型和 `actorKey`；另一人物不能继承未完成动作。
- 同一页数模型内，知识变化会重新计算总页数，但保留已完成的绝对页数并截断到新上限。
- 1.01 没有模型版本的旧进度按完成比例映射，例如 `500/1000 -> 350/700`，并向下取整。
- 未知的显式未来页数模型不进行猜测，按没有可续作进度处理。
- 当前事务令牌仍绑定开始时的完整知识签名；动作期间状态变化后旧令牌不能提交。
- 服务端用最大值合并检查点，较小或重复页码不能让进度倒退。

### 兼容与安全边界

- 目标版本仅为 Project Zomboid Build 42.20。
- 移除 Mod 后物品仍是原版日记本；重新安装后可再次识别有效的 v6 数据。
- 作者授权优先绑定服务器认证 username；缺少 username 的早期日志会回退人物显示名。
- 服务端权威保护知识内容与事务重放，但当前不把现实耗时作为强防作弊边界。
- `begin` 回包丢失时客户端没有独立超时；极端网络故障可能需要重新连接。

### 仓库结构

```text
docs/TECHNICAL_REFERENCE.md           详细技术参考
recovery/                             唯一认可的 1.02 恢复载体
workshop/Contents/mods/LegacyJournal  Mod 运行源码与元数据
workshop/install_local.ps1            带校验和回滚的本地安装器
CHANGELOG.md                          公开变更记录
CONTRIBUTING.md                       贡献边界
SECURITY.md                           漏洞报告方式
```

公开仓库不包含 NUC/Windows 内部测试工具、服务器地址、发布凭据、原始日志或私有运维流程。
当前版本通过内部静态门禁、6 个 Lua 文件解析和 12 项行为测试后发布。

### 获取与安装

玩家请使用 [Steam 创意工坊](https://steamcommunity.com/sharedfiles/filedetails/?id=3788037313)。
源码安装时，将 `workshop/Contents/mods/LegacyJournal` 复制到 Project Zomboid Mods 目录。

这是非官方社区项目，与 The Indie Stone 无关联。项目采用 [MIT License](LICENSE)。

## English

Personal Journal is a server-authoritative knowledge-recording Mod for Project Zomboid Build 42.20.
It stores a character knowledge snapshot on a vanilla diary and lets a successor on the same
multiplayer account restore only the state they are still missing after recovering the physical item.

- Current release: `1.02`
- Mod ID: `LegacyJournal`
- Workshop ID: `3788037313`
- Data schema: `LJ_version=6`
- Runtime dependencies: none
- Sole accepted rollback baseline: `v1.02`

See the
[technical reference](https://github.com/Kinkairy/Project-Zomboid-Personal-Journal/blob/main/docs/TECHNICAL_REFERENCE.md)
for field definitions, formulas, protocol details, and compatibility rules.

### Design Goals and Invariants

- Only vanilla `Base.Diary1` and `Base.Diary2` items are supported; no item or recipe is added.
- In multiplayer, the server computes knowledge deltas, validates ownership and the item, issues the
  transaction token, and commits the final state.
- Clients submit action intent, the physical item ID, and whole-page progress; they never upload XP,
  recipe, or media snapshots.
- Recovery only fills missing state. It never lowers or overwrites stronger XP, newer recipes, or more
  advanced skill-book progress already owned by the reader.
- Recipes, skill books, and training media use stable ordering and deterministic quotas, so repeated
  reads cannot reroll or gradually accumulate the result.
- Only exact v6 records are accepted. Unversioned, old, damaged, and future schemas are not guessed.
- Interrupted progress is bound to the physical journal, action, and character, and is stored by the
  server as a monotonic whole-page checkpoint.

### Architecture

| Module | Responsibility |
| --- | --- |
| `legacyjournal_shared.lua` | Data model, snapshots, deltas, page counts, signatures, writes, and recovery |
| `legacyjournal_actions.lua` | Vanilla-style TimedActions, animation, progress, and page checkpoints |
| `legacyjournal_client.lua` | Context menus, item transfer, request dispatch, and result handling |
| `legacyjournal_server.lua` | Server validation, tokens, checkpoints, commits, and field synchronization |
| `legacyjournal_presentation.lua` | Localized item-name presentation |
| `legacyjournal_skillbook_compat.lua` | Build 42 skill-book page and multiplier compatibility |

Multiplayer write/read transaction:

```text
context menu
  -> begin(action, itemId)
  -> server relocates the item, computes the delta, and issues a one-use token
  -> TimedAction submits checkpoint/cancel
  -> commit(action, itemId, token)
  -> server revalidates the signature and atomically writes or restores state
  -> native item-field and player-field synchronization
```

At commit time, the server does not trust the state captured by `begin`. It recursively relocates the
item, verifies the diary type and exact schema, checks the author and writing tool, recomputes the delta
and signature, consumes the one-use token first, and only then calls shared `commitWrite` or `applyRead`.
Each player has at most one pending action. Recipe and media results are sent in bounded batches.

Single-player mode reuses the same shared delta, page-count, and recovery functions instead of keeping
a second gameplay implementation.

### Persistence and Recovery Semantics

The physical diary stores skill XP, known recipes, skill-book pages and multiplier state, qualifying
training media, author identity, write time, and interrupted-action progress in `modData`.

| Field group | Main fields | Meaning |
| --- | --- | --- |
| Identity | `LJ_written`, `LJ_version` | Journal marker and exact data schema |
| Author | `LJ_authorName`, `LJ_authorUser`, `LJ_authorDescId` | Display name, account, and character descriptor |
| Knowledge | `LJ_skills`, `LJ_recipes` | Historical skill XP and known recipe set |
| Skill books | `LJ_skillBooks`, `LJ_skillBookStates` | Read pages, skill ID, multiplier, and level range |
| Training media | `LJ_mediaRewards`, `LJ_mediaRewardMode` | Stable media ID and reward-type mask |
| Continuation | `LJ_progressAction`, `LJ_progressSignature`, `LJ_progressActor`, `LJ_progressPage`, `LJ_progressTotalPages`, `LJ_progressModelVersion` | Server checkpoint for an interrupted action |

Collections are encoded in stable key order so snapshot signatures, recovery selection, and delta results
remain reproducible.

- Skill XP stores the highest observed value; recovery only adds XP missing from the scaled target.
- Recipes are learned only when unknown, so recipes learned by the new character before reading are not
  overwritten by the journal.
- Skill-book recovery only raises pages and multiplier state applicable to the current skill range.
- CD/VHS media is recorded only when it contains a permanent skill, XP, or recipe reward.
- A successful write or recovery clears temporary continuation fields while retaining the journal data.

### Page and Time Model

Read and write deltas are converted into content units and then use:

```text
writeUnits = 600
           + changedSkills * 120
           + ceil(XP / 100)
           + newRecipes * 90
           + changedSkillBooks * 100
           + mediaLines * 8

readUnits  = 900
           + changedSkills * 90
           + ceil(XP / 100) * 0.8
           + missingRecipes * 75
           + missingSkillBooks * 85
           + missingMediaLines * 6

pages = max(1, ceil(units * 7 / 1000))
```

Version 1.02 changes the original accumulation rate directly; it does not calculate rounded pages with
the old formula and then multiply by `0.70`. Reading and writing share this base page model. Vanilla fast
and slow reader traits, reading glasses, sitting modifiers, and independent sandbox multipliers remain.

### Interrupted Actions and Version Compatibility

- Historical checkpoints must match the physical journal, action type, and `actorKey`; another character
  cannot inherit unfinished work.
- Within the same page model, a knowledge change recalculates total pages but retains completed absolute
  pages, clamped to the new total.
- Old 1.01 progress without a model version is mapped by completion ratio, for example
  `500/1000 -> 350/700`, rounded down.
- An explicit unknown future page model is not guessed and resumes from no checkpoint.
- The active token remains bound to the complete knowledge signature captured at `begin`; a changed state
  invalidates that token.
- The server merges checkpoints by maximum page, so smaller or duplicate updates cannot move progress back.

### Compatibility and Security Boundaries

- The supported target is Project Zomboid Build 42.20 only.
- Removing the Mod leaves a vanilla diary; reinstalling can recognize valid v6 data again.
- Author access prefers the server-authenticated username. Early records without it fall back to the
  character display name.
- Server authority protects knowledge state and transaction replay, but elapsed real time is not a hard
  anti-cheat boundary.
- A lost `begin` response has no independent client timeout and may require reconnecting in an extreme
  network failure.

### Repository Layout

```text
docs/TECHNICAL_REFERENCE.md           Detailed technical reference
recovery/                             Sole accepted 1.02 recovery artifacts
workshop/Contents/mods/LegacyJournal  Runtime source and Mod metadata
workshop/install_local.ps1            Verified local installer with rollback
CHANGELOG.md                          Public change history
CONTRIBUTING.md                       Contribution boundaries
SECURITY.md                           Vulnerability reporting
```

The public repository excludes internal NUC/Windows test harnesses, server addresses, publishing
credentials, raw logs, and private operational procedures. The release passed the internal static gate,
parsing of all six Lua payload files, and twelve behavior tests.

### Distribution

Players should use the [Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3788037313).
For a source installation, copy `workshop/Contents/mods/LegacyJournal` into the Project Zomboid Mods
directory.

This is an unofficial community project and is not affiliated with The Indie Stone.
Licensed under the [MIT License](LICENSE).
