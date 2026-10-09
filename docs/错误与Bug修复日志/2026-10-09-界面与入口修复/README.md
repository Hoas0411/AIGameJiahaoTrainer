# 2026-10-09 界面与入口修复

> 状态：已实现；验证见 §4。用户尚未确认。
> 触发：2026-10-09 实机游玩（Forward+，RTX 4080 Laptop）与源码对照。

## 1 规划
只修玩家可直接碰到、且有明确错误行为的问题；不改存档、关卡 ID、训练规则与碰撞。

| # | 问题 | 影响 |
|---|---|---|
| B1 | 大厅门户 Portal_2（Valorant随机反应）`metadata/station_id = 0`，站在它前面按 F 进入的是 AWM | 进错关 |
| B2 | 按键设置与暂停说明里，物理键显示为 “W - Physical” | 文字错误 |
| B3 | 设置页、操作栏与架门缝提示写 “T 循环瞄具/切瞄具”，实际 `laser` 动作绑定为 B（T 是语音） | 指引错误 |
| B4 | 暂停菜单点击“继续”的同一次鼠标按下会立刻打出一枪 | 误射、影响成绩 |
| B5 | 训练中伴随角色生成在玩家正前方，遮挡瞄准视野（基地保持原位） | 遮挡 |

## 2 诊断
- B1：`scenes/levels/circular_lobby_fit/circular_lobby.tscn` 中 `Stations/Portal_2` 的元数据为 0；射击命中走 `zone = portal_2` 所以射击正确，只有 F 键路径（读取 station_id）错误。
- B2：Godot 4.7 的 `InputEventKey.as_text()` 对物理键返回 “X - Physical”，现有代码只去掉旧格式 “ (Physical)”。位置：`scripts/interface.gd:359`、`scripts/keybindings.gd:43`。
- B3：`project.godot` 中 `laser` = physical_keycode 66（B）。过期文字位于 `scenes/ui/interface.tscn`（设置页说明、操作栏）、`scripts/interface.gd` OBJECTIVES[15]、`scripts/training/training_drill.gd:401`。
- B4：暂停按钮在鼠标按下时触发 `resume()`，恢复后武器轮询 `Input.is_action_pressed("fire")` / `just_pressed` 仍为真。
- B5：`scripts/companion_actor.gd` 训练关卡未区分出生站位。

## 3 实现
- B1：Portal_2 `station_id` 改为 2。
- B2：两处同时去掉 “ - Physical”。
- B3：上述文字改为 B。
- B4：`scripts/weapon.gd` 新增 `trigger_hold_block`；`scripts/main.gd: resume()` 置位，武器在开火键完全松开前不出枪，松开后自动解除。只影响从暂停恢复的这一次按压。
- B5：训练关中伴随角色在玩家身后/侧后方 4 个候选点生成，头顶名牌仅在基地显示。

## 4 验证
- 实机采集：`workbench/tmp/claude/out/pass3-forward_plus`（大厅 c12，门户与课程窗口）。
- B1：源码读回 `Portal_2 station_id = 2`；`activate(2)` → `PORTAL_LEVELS[2] = 7`（Valorant随机反应）。
- B2/B3：字符串读回；全工程 `grep "T 切\|T：循环\|T 循环"` 无结果。
- B4：逻辑检查——按住期间 `trigger_requests_shot()` 返回 false，松开后第一帧清除标记；键盘 Esc 恢复时开火键未按下，标记在下一帧清除，无副作用。待用户实机确认手感。
- 未覆盖：完整 AI/成绩回归。
