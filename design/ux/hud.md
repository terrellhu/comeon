# HUD Design — 刃响 (Blade Echo)

> **Status**: Approved
> **Author**: user + ux-designer
> **Last Updated**: 2026-06-01
> **Template**: HUD Design
> **Accessibility Tier**: Standard (per `design/accessibility-requirements.md`)

---

## HUD Philosophy

HUD 是战场的「建筑铭文」，不是「浮于屏幕上的 UI 玻璃层」。它承认战斗信息的必要性，但永远不与 Boss 争夺注意力中心。

每一帧画面里，Boss 是主角，HUD 是背景。HUD 在战斗全程常驻，但它的亮度和动态强度永远低于 Boss 的预警视觉。

三条执行规则（来自 Art Bible Section 7）：
- **R-HUD-V1（几何语法）**：直线 + 45° 倒角，无圆角，无有机曲线。边框 1px。
- **R-HUD-V2（腐化美学）**：细节层微腐化（刻缝、锯齿上沿），功能层高亮（窗口开启时进度条是当帧最美元素）。
- **R-HUD-V3（透明度）**：战斗进行中 85% 不透明度。战斗开始后 1 秒内从 0% 线性升至 85%——Boss 出场是电影感时刻，HUD 不参与。

**设计检验**：冻结任意战斗帧——HUD 亮度最高点不得超过 Boss 预警视觉、Boss 受光面或玩家受光面。若 HUD 是最亮元素，重新设计。

---

## Information Architecture

### Full Information Inventory

HUD 需要向玩家传达的所有信息，来自 7 个 MVP GDD 的 UI Requirements 段：玩家 HP 段数、Boss HP 连续血条与阶段分隔线、反击窗口计时条（含连击计数、全连击反馈、BONUS_STAGGER 状态）、会话死亡计数（预留不显示）。预警进度条与攻击类型标识经设计决策移除，由 Boss 身体视觉承担全部预警信道职责。

> ⚠️ **GDD 偏差记录**：`design/gdd/hud-system.md` 包含预警进度条设计。本 UX spec 做出更严格的设计决策（移除），以保障 Pillar 1「读懂才能赢」完整性。该 GDD 应在下一次修订中更新以反映此决策（参见 `/propagate-design-change`）。

### Categorization

| 分类 | 元素 |
|------|------|
| **Must Show** | 玩家 HP 段数条 · Boss HP 血条（含阶段分隔线） |
| **Contextual** | 反击窗口计时条（COUNTER_WINDOW_OPEN / BONUS_STAGGER 期间）· 连击计数「hit n/3」· 全连击完成反馈「FULL COMBO」 |
| **Hidden** | ~~预警进度条~~（已移除；Boss 视觉是唯一预警信道）· ~~攻击类型标识~~（随进度条移除）· 会话死亡计数（MVP 不显示） |

**进度条移除的设计原则**：若进度条存在，玩家将读 HUD 而非 Boss（垂直切片 2026-06-01 证实）。移除进度条后，Boss 美术必须使 PRE_WINDOW / WINDOW_OPEN / POST_WINDOW 三态在无任何 UI 辅助的情况下完全可识别。这是 Art Production 阶段的强约束，不是可选项。

---

## Layout Zones

视口基准：1280×720。所有元素通过 CanvasLayer 渲染，不受摄像机影响。

| 分区 | 位置 | 内容 | 尺寸参考 |
|------|------|------|----------|
| **顶部信息带** | 顶部居中，距上边框 12px | Boss HP 血条（含阶段分隔线） | 宽 640px · 高 14px |
| **左下状态区** | 左下，距左/下边框各 20px | 玩家 HP 段数条（5 段） | 总宽 156px（28px段 + 4px间距）· 高 12px |
| **玩家伴随区** | 跟随玩家角色头顶偏移 | 反击窗口计时条 + 连击计数 + FULL COMBO 文字 | 计时条 80×8px；标签 12–24px |

**层级规则**：顶部信息带亮度 ≤ 左下状态区 < 玩家伴随区（反击条在战斗最激烈时是最醒目的 HUD 元素，但不超过 Boss 预警视觉）。

**视觉预算**：最多 3 个分区同时活跃；三区不重叠；估计最大屏幕占比 ~3%（Boss HP 640×14px + 玩家 HP 156×12px + 反击条 80×8px，合计约 12,000px² / 921,600px²）。

---

## HUD Elements

### 元素 1：玩家 HP 段数条
**Pattern**: `[Pattern: Segmented Status Bar]` · **分区**: 左下状态区

| 属性 | 规格 |
|------|------|
| 位置 | 左下，距左/下各 20px |
| 尺寸 | 5 段 × 28×12px，段间距 4px，总宽 156px |
| 颜色-亮段 | 枯骨白变体 `#C8BFA8` |
| 颜色-暗段 | 虚空墨 `#0D0B1A` |
| 段边框 | `#6B6358` 1px（亮/暗共用）|
| 临界状态 | `displayed_segments = 1` 时段 1 外框 0.5Hz 脉冲，锈金变体 `#8B6914` |
| 更新触发 | `player_hp_changed(current, max)` → `ceil(current / hp_per_segment)` |
| 空状态 | HP = 0 时所有段暗灭（特判，不走 ceil 计算）|

---

### 元素 2：Boss HP 血条 + 阶段分隔线
**Pattern**: `[Pattern: Continuous Bar + Phase Ticks]` · **分区**: 顶部信息带

| 属性 | 规格 |
|------|------|
| 位置 | 顶部居中，距上 12px；x = (1280 - 640) / 2 = 320 |
| 尺寸 | 640×14px（含 1px 外框共 644×18px）|
| 填充颜色 | Boss 主色降饱和 15%（破钟示例 `#D9571A`；各 Boss 独立定义）|
| 背景颜色 | Boss 主色降饱和 30%，亮度 -20% |
| 阶段分隔线-正常 | `#E8DFC8` 枯骨白，1.5px |
| 阶段分隔线-已过 | `#8B6914` 哑光锈金（永久不可逆，「此阶段已征服」）|
| 压过瞬间高光 | `#F5F0E8` 枯骨白高光，0.3s 后回到已过颜色（非霜白 `#EDF3FF`）|
| 分隔线位置 | `bar_total_width × phase_threshold_pct[n]`，战斗开始时一次性计算，战斗中不移动 |
| 更新触发 | `boss_hp_changed(current, max, phase)` |
| 除零保护 | `max ≤ 0` 时显示空条 + warning 日志，不执行除法 |

---

### 元素 3：反击窗口计时条 + 连击计数 + 全连击反馈
**Patterns**: `[Pattern: Contextual Timer Bar]` · `[Pattern: Hit Counter Badge]` · `[Pattern: Transient Confirmation Flash]` · `[Pattern: World-Space HUD Element]`
**分区**: 玩家伴随区

**跟随实现（GAP-03 解决）**：反击条位于 CanvasLayer 上的 Control 节点，每帧将 `player.global_position` 转换为 CanvasLayer 屏幕坐标后更新节点位置。
计算：`screen_pos = get_viewport().get_screen_transform() * player.global_position + Vector2(0, -48)`

| 属性 | 规格 |
|------|------|
| 位置 | 玩家头顶，Y 偏移 -48px（屏幕坐标）|
| 计时条尺寸 | 80×8px |
| 颜色-COUNTER_WINDOW | 淡冷青白 `#8AB8C8` |
| 颜色-BONUS_STAGGER | 衰减锈金 `#C8A020` |
| 连击计数文本 | 「hit {n}/3」，12px Serif，计时条上方 Y -12px |
| 全连击反馈 | 「FULL COMBO」24px Serif Bold `#C8A020`，Y -64px，持续 0.5s 后消失 |
| 可见条件 | 仅 COUNTER_WINDOW_OPEN 或 BONUS_STAGGER；关闭后 0.2s 渐隐 |
| 更新触发 | `counter_window_updated(hit_count, time_remaining, state)` 每物理帧 |
| 全连击触发 | `counter_full_combo_completed(attack_type)` |
| 反击条分母 | 始终使用 `base_counter_window[attack_type]`（BONUS_STAGGER 时不切换分母，避免条「跳回满格」误读）|

---

## Dynamic Behaviors

| 事件 | 行为 |
|------|------|
| 战斗开始 | HUD 整体透明度从 0% 在 1s 内线性升至 85%（R-HUD-V3）|
| 玩家受击 | 段数条触发掉段（瞬时暗灭）|
| HP 临界（1 段剩余）| 段 1 以 0.5Hz 脉冲（纯视觉，无音效）|
| Boss 阶段被压过 | 分隔线在 0.3s 内从枯骨白过渡至哑金，永久不可逆 |
| 反击窗口开启 | 计时条 + 连击计数淡入（< 0.1s），冷青白色 |
| BONUS_STAGGER 激活 | 计时条颜色切换为锈金 `#C8A020`（不切换分母）|
| 全连击完成 | 「FULL COMBO」0.5s 闪烁后渐隐；金属共振音效同步 |
| Boss 被击败 | HUD 停止响应 `telegraph_updated` / `counter_window_updated`；相关元素冻结或隐藏 |
| Reduce Motion ON | 关闭：段数条脉冲、Boss HP 条过渡动画、反击条淡入/淡出；保留：「FULL COMBO」文字（无运动动画）|
| 系统暂停（Esc/Start）| HUD 随游戏时间暂停（PROCESS_MODE_PAUSEABLE）；死亡屏幕期间 HUD 元素已覆盖，无需特殊处理；Alpha 阶段引入暂停菜单时补充此节 |

---

## Platform & Input Variants

- **目标平台**：PC（Steam），1280×720 基准，支持 16:9、16:10、21:9
- **输入方式**：键盘/鼠标 + 手柄（Primary: 手柄）；HUD 为纯输出型，无输入交互，无导航焦点需求
- **DPI 缩放**：CanvasLayer `stretch_mode = canvas_items`；各元素锚点固定（左下 / 顶部居中 / 跟随玩家）
- **超宽屏（21:9）**：HUD 位置规则不变（顶部居中、左下绝对位置），中央空区留给 Boss 战场；MVP 不单独优化极小分辨率

---

## Accessibility

遵循 `design/accessibility-requirements.md` Standard 层级。

| 检查项 | 实现方式 |
|--------|----------|
| A-03 WCAG-AA 对比度 | 枯骨白 `#C8BFA8` on 虚空墨 `#0D0B1A`：11:1 ✅；琥珀金 `#E8941A` on 虚空墨：8.5:1 ✅ |
| A-04 色非依存（HP 临界）| 段数 + 颜色 + 脉冲三重信号 |
| A-04 色非依存（阶段压过）| 分隔线颜色变化 + 永久位置状态不变 |
| A-04 预警信道（进度条已移除）| Boss 视觉必须提供颜色 + 形状 + 动作三重信号（Art Production 责任，不在 HUD 层实现）|
| A-06 Reduce Motion | 关闭脉冲 / 过渡动画；「FULL COMBO」保留（纯文字）|
| R-HUD-CHK-04 灰度模式 | HP 段亮/暗亮度差 ≥ 40%（L74 vs L4，差 70%）✅ |
| R-HUD-CHK-06 亮度竞争 | 战斗高潮帧中 HUD 亮度最高点不超过预警 / Boss 受光面 / 玩家受光面 |

---

## Open Questions

1. **玩家旅程图尚未创建**：无 `design/player-journey.md`，HUD「首次发现」节拍未有依据。建议 Pre-Production 阶段创建（模板：`.claude/docs/templates/player-journey.md`）。
2. **无进度条后的 Boss 视觉责任**：移除预警进度条后，Boss 美术须在无 UI 辅助的情况下传达 PRE_WINDOW / WINDOW_OPEN / POST_WINDOW 三态并满足 A-04 三重信号要求。须在 `/art-bible` Boss 美术规格中明确——这是 Art Production 阶段的强约束。
3. **Godot 4.6 世界→屏幕坐标转换验证**：`get_viewport().get_screen_transform()` 在 `stretch_mode = canvas_items` 下的行为须在首个 HUD story 实现时验证（参见 `docs/engine-reference/godot/modules/ui.md`）。
4. **GDD 偏差待同步**：`design/gdd/hud-system.md` 包含预警进度条设计，已被本 spec 覆盖。Production 前运行 `/propagate-design-change` 将决策同步至 GDD 和 story files。
5. **调参旋钮**：hp_bar_flash_frequency、telegraph_bar_fade_in_duration、counter_bar_fade_out_duration 等可调参数已定义于 `design/gdd/hud-system.md` Tuning Knobs 节；本 spec 不重复定义，Stories 引用 GDD 调参节。
