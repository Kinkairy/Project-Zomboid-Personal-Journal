# Personal Journal 1.3.2 — Progress presentation

This addendum supersedes the multiplayer progress-presentation description in
TECHNICAL_REFERENCE.md. Gameplay data, ownership and restoration rules are unchanged.

## One authority, one displayed progress

Only an active, matching native server action can answer a progress request.
The client sends identification (journal, action kind and an action-instance routing
key), never a page number, completion percentage, duration or knowledge snapshot.
The server returns its actual NetTimedAction progress and its plan's start/total pages.

An active client action polls every 500 real milliseconds. The server applies the
same per-action reply limit. Polls also sample the existing authoritative whole-page
checkpoint implementation, so checkpointing does not stop just because a client
previously thought its bar was full. No global tick scan is added.

The client pins native action progress to the most recently received sample. A fixed
1,000,000-unit presentation scale is a normalized fraction scale, NOT a duration or
an estimate in seconds. It does not change getDuration() on the server. There is no
local extrapolation to a guessed finish time. The inventory and overhead bars both
show (startPage + remainingPages * serverProgress) / totalPages. Only the currently
active local player's overhead bar is repainted, after native per-frame drawing.

The native action still determines Done, Reject, cancellation and queue release.
Progress telemetry never awards knowledge or calls forceComplete. Reading animation
remains owned by the same native action. This implementation does not explicitly
stop or restart it during progress updates and introduces no replacement animation.
Actual animation lifetime still requires in-game acceptance.

## Visible phases

Before a sample, or after more than three seconds without a fresh sample, the job
text says it is waiting for server progress. It retains the last actual fraction.
During authoritative result application the job text describes result processing.
After server progress reaches completion, native-completion acknowledgement is
explicitly labelled until native perform() clears the job. These are distinct
states, not a hardcoded 99% cap or a fabricated extra countdown.

Every response is checked against local OnlineID, actor identity, the physical
journal, action kind, the action-instance key, a monotonic sequence and the fixed
server plan. Non-finite, regressive, mismatched and late responses are ignored.
Cancellation and completion remove the local action's presentation reference.

## Upgrade and verification boundary

Client and server must both load 1.3.2. The routing key is an added native constructor
argument, so mixed runtime versions are not a supported deployment. Public version
is 1.3.2; LJ_version remains 6. No recorded knowledge is migrated or discarded.
A source-directory update does not update an installed Mod or an already running game.

The candidate has offline Lua regression coverage for clock divergence, native
update ordering, resume plans, late/out-of-order responses, split-screen routing,
malformed inputs, cancellation, signature rejection and exceptions. Engine methods,
network transport and knowledge effects are doubles in that test. This is not an
in-game multiplayer or animation acceptance result. Test an actual long read and a
resume on matching B42.20 client/server builds before describing it as live-verified.

## 简体中文

1.3.2 将多人阅读/书写的显示进度改为服务端实际进度采样，物品栏与头顶条使用相同的
累计进度；续读页数也采用服务端计划。等待服务端、处理结果和等待原生动作确认分别
显示状态。补丁不缩短阅读时间、不提前恢复经验、不建立第二套提交机制。

## 繁體中文

1.3.2 將多人閱讀/書寫的顯示進度改為伺服器實際進度取樣，物品欄與頭頂條使用相同的
累計進度；續讀頁數也採用伺服器計畫。等待伺服器、處理結果和等待原生動作確認分別
顯示狀態。補丁不縮短閱讀時間、不提前恢復經驗、不建立第二套提交機制。
