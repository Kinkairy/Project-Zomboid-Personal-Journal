# Recovery / 恢复载体

这里只保留两个版本，校验文件不是额外版本：

| 用途 | 原包 | ZIP SHA-256 |
| --- | --- | --- |
| 1.3，唯一正常开发/回滚基准 | legacy-journal-1.3-accepted-baseline.zip | bb3e37483cc931e88868936783771d10e89e2bbd50796a6bfd5c234ad76a8dc6 |
| 1.2，仅紧急兜底；历史标识 1.02 | legacy-journal-1.02-accepted-baseline.zip | e48055ec2694f0d9300b3df145f8ff0814a6b8ee9e4b504d00a16136919bef27 |

旧正式包保持原名、内容和校验值，不伪造曾发布过一个独立 v1.2。
The previous formal package retains its historical 1.02 identity; 1.2 is the owner's fallback label.

恢复时先验证对应 .zip.sha256，再解包到一个全新的空目录，不在备份内开发，也不直接覆盖运行目录。
1.3 解包为 LegacyJournal 下 22 个文件，build 为 1.3-native-actions-release；旧包为 23 个文件。
比较相对路径和逐文件 SHA-256，包含隐藏的 .gitkeep；随后按明确授权只替换目标 Mod。
恢复不包括世界、角色数据库、服务器配置、其他 Mod 或 Steam manifest。
服务器和客户端重新加载仍需单独授权，不能把磁盘一致当作运行态一致。

恢复后核对实际加载 build，快速验证写入、中断续作、读取及取消后名称。
Verify the archive, extract into a fresh directory, compare every file including dotfiles, and restore
only the authorized Mod. Reloading processes and restoring worlds are separate operations.
