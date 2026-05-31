# 即时重试系统 (Instant Retry System)

> **Status**: Designed (Pending Review)
> **Author**: game-designer + systems-designer + art-director (Visual/Audio 修订)
> **Last Updated**: 2026-06-01 (Art Bible Section 7.5 同步修订)
> **Implements Pillar**: Pillar 4「失败是学习，不是惩罚」

## Overview

即时重试系统监听 `player_died` 信号（由伤害/生命系统在玩家 HP ≤ 0 时发出），在 Art Bible Section 7.5 定义的 1.5 秒死亡屏幕序列（红闪 → 渐入深灰 → Boss 相位符号 → 淡出）后**自动**将玩家重置至战斗场景起始位置，玩家无需任何输入。玩家可在死亡屏幕任意帧按键**跳过**剩余动画——但跳过只是缩短等待，重试始终发生。玩家 HP 恢复至满值（`player_max_hp = 100`），当前会话死亡计数器自增。重置时 Boss 当前血量**保留不变**——玩家每次重试都是从 Boss 被打掉血后的状态继续，而非从零重来。本系统不施加任何资源惩罚：无货币损失，无能力削减，无跑图惩罚。玩家感受到的是「我刚才差点过了，现在立刻再来」的节奏拉力，而非「我失去了什么」的挫败感——这是 Pillar 4「失败是学习，不是惩罚」的直接实现。

## Player Fantasy

死亡不是句号——是一个逗号。

屏幕短暂变暗，不是惩罚的仪式，是呼吸换气的间隙。然后你又站在了那个神明面前，它的血条停在上次你打到的地方。你做到的，全都还在那里。

这个系统提供的幻想不是「我不会死」——是「我死了，但代价只是 1.5 秒」。那 1.5 秒的价值是：它短到让你在返回战场前已经想好了下次要改变什么。`再来一次` 不是灰心，是意图——而这个"意图"不需要你按任何键去表达，游戏知道你会回来。

理想状态下，玩家根本不会意识到"重试系统"的存在——他们只会感受到：这个游戏让我学得很快，因为失败的代价刚好合理，不多不少。

## Detailed Design

### Core Rules

**重试触发序列（遵循 Art Bible Section 7.5「死亡屏幕 / 重试」规范）：**

1. 本系统在场景加载时订阅 `player_died` 信号（由伤害/生命系统发出）
2. 收到 `player_died` 信号后立即：暂停游戏逻辑时间（保护 Boss 状态不继续运行）；启动 **Art Bible 7.5 死亡屏幕序列**（详见 Visual/Audio Requirements 节，总时长 1.5s）
3. 在死亡屏幕期间，本系统准备 **RetryContext**（场景外持久对象）保留以下数据，并触发场景重置/重载（具体实现方式见 ADR；工程约束：必须在 1.5s 死亡屏幕窗口内完成）：
   - `preserved_boss_hp`：Boss 被打掉的血量（上次尝试结束时的 `current_boss_hp`）
   - `preserved_boss_phase`：Boss 当前所在阶段（Phase 1 / Phase 2…）
   - `session_death_count`：本会话累计死亡次数（自增后传入）
4. **自动恢复**：死亡屏幕 1500ms 时刻**自动**切回战斗场景，玩家无需任何输入。这是 Pillar 4「失败是学习不是惩罚」的直接实现——游戏代替玩家承担"决定继续"的认知负担。
5. **可跳过**：死亡屏幕**任意帧**玩家按任意键 → 立即跳至 1500ms 时刻，触发即时重开。这是"**跳过**死亡动画"，不是"**触发**重试"——玩家始终会重试，跳过只是缩短等待。
6. 场景恢复后：Boss 血量从 `preserved_boss_hp` 恢复；Boss 状态机重置为 IDLE（不继承上次结束时的动画/攻击状态）；玩家以满 HP（`player_max_hp = 100`）出现，进入短暂无敌期（`retry_invuln_duration = 2.0s`，与死亡屏幕时长无关）

**Boss 完全击败后的新战斗：**

7. `boss_defeated` 信号发出时：清除 RetryContext 中的 `preserved_boss_hp`（不保留）；下次进入该 Boss 战斗时，Boss 从满血开始（新战斗，而非重试）

**惩罚规则：**

8. 重试不扣除任何资源：无货币损失，无能力削减，无能力树进度退回
9. 本系统不根据累计死亡次数改变行为——第 1 次和第 50 次死亡的重试流程完全相同

---

### States and Transitions

| 状态 | 进入条件 | 退出条件 | 系统行为 |
|------|----------|----------|---------|
| `ACTIVE` | 场景加载完成 | `player_died` 信号 | 正常监听，不介入游戏逻辑 |
| `RED_FLASH` | 收到 `player_died` | 0.2s 计时到达 | 暂停游戏时间；触发 40% 红色全屏闪烁；并行准备 RetryContext |
| `FADE_TO_GREY` | RED_FLASH 退出 | 0.4s 计时到达（累计 0.6s）| 画面线性褪色至深灰 `#0A0A0C`；并行开始场景重置/重载 |
| `PHASE_SYMBOL` | FADE_TO_GREY 退出 | 0.6s 计时到达（累计 1.2s），或玩家输入 | 屏幕中央展示 Boss 相位符号，静止无动画 |
| `SYMBOL_FADE_OUT` | PHASE_SYMBOL 退出 | 0.3s 计时到达（累计 1.5s）| 相位符号线性淡出 |
| `RESUMING` | 累计 1.5s 到达 / 玩家输入跳过 | 场景就绪 + 渲染完成 | 切回战斗场景，传入 RetryContext 数据 |

**跳过逻辑**：在 `RED_FLASH`、`FADE_TO_GREY`、`PHASE_SYMBOL`、`SYMBOL_FADE_OUT` 任意状态期间（任意帧），玩家任意输入 → 跳转至 `RESUMING`（不等待剩余时间）。Art Bible 7.5 规范：「任意帧：玩家输入直接跳至 1500ms」。

---

### Interactions with Other Systems

| 系统 | 方向 | 接口 |
|------|------|------|
| 伤害/生命系统 | → 触发本系统 | 订阅 `player_died` 信号 |
| Boss 状态机系统 | ← 本系统读取/写入 | 重试前读取 `current_boss_hp` 和当前阶段；重载后传入 `preserved_boss_hp`、`preserved_boss_phase` |
| 玩家角色控制系统 | ← 本系统驱动 | 重载后玩家状态初始化：满 HP，起始位置，`retry_invuln_duration` 无敌期 |
| HUD 系统 | ← 本系统发出信号 | `retry_death_count_changed(count: int)` — HUD 订阅此信号显示死亡计数器 |
| 存档系统 | ← 本系统写入（待设计） | MVP：不涉及持久化；Alpha：Boss 被击败后写入胜利记录 |

> **⚠️ 实现注意**：RetryContext 的具体实现方式（Autoload 单例 vs 场景参数传递）属于架构决策，应在 `/architecture-decision` 中确定，不在本 GDD 中规定。

## Formulas

### 公式 1：`retry_invuln_duration`（重生无敌时长）

固定常量，不引入变量计算——无敌期是感知预算，不是数学问题。一致性优先于弹性。

```
retry_invuln_duration = RETRY_INVULN_BASE
```

**变量：**
| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 重生无敌基准 | `RETRY_INVULN_BASE` | float (const) | [1.5, 2.5] s | 固定值，调参安全范围 |
| 受击无敌下限 | `player_hit_invuln_duration` | float (注册表常量) | 0.5s | 硬约束：`RETRY_INVULN_BASE` 必须严格 > 此值 |
| 重生无敌时长 | `retry_invuln_duration` | float | = `RETRY_INVULN_BASE` | 本次重生的实际无敌持续时长 |

**输出范围：** 固定值。硬约束：严格 > `player_hit_invuln_duration = 0.5s`。低于 1.0s 时玩家来不及识别 Boss 意图；高于 3.0s 超过总重试预算。
**基准值：** `RETRY_INVULN_BASE = 2.0s`（120 帧）。覆盖落地动画 ~0.4s 后仍留 1.6s 读局。
**参考：** Hollow Knight 重生无敌 ~2.0s；Furi ~1.5s。

---

### 公式 2：死亡屏幕序列时长预算（Art Bible Section 7.5）

死亡屏幕由 4 个连续阶段组成，时长由 Art Bible 锁定，总时长固定 1.5s。

```
total_death_screen_duration = red_flash_duration + fade_to_grey_duration + phase_symbol_display + symbol_fade_out
                            = 0.2 + 0.4 + 0.6 + 0.3
                            = 1.5 s
```

**变量：**
| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 红色闪烁时长 | `red_flash_duration` | float (const) | 0.2s（Art Bible 锁定）| 死亡瞬间全屏 40% 红色 `#CC2200` 瞬闪 |
| 渐入深灰时长 | `fade_to_grey_duration` | float (const) | 0.4s（Art Bible 锁定）| 画面线性褪色至深灰 `#0A0A0C` |
| 相位符号显示时长 | `phase_symbol_display_duration` | float (const) | 0.6s（Art Bible 锁定）| Boss 相位符号静止居中展示 |
| 符号淡出时长 | `symbol_fade_out_duration` | float (const) | 0.3s（Art Bible 锁定）| 相位符号线性淡出 |
| 总死亡屏幕时长 | `total_death_screen_duration` | float | = 1.5s | Art Bible Section 7.5 硬约束 |

**输出范围：** 固定 1.5s（Art Bible 锁定）。

**工程约束：** 场景重置/重载必须在 1.5s 死亡屏幕窗口内完成（含 0.2s 红闪 + 0.4s 渐灰共 0.6s 时间可用于异步加载，余 0.9s 用于相位符号展示和淡出）。如果场景重置时间超过此预算，需要在 ADR 中明确实现策略（场景重用 vs 异步加载）。

**示例（自动恢复路径）：** 玩家死亡 → 1.5s 完整序列 → 自动重开。**示例（玩家跳过路径）：** 玩家死亡 → 任意时刻按键 → 立即跳至 1.5s 时刻重开（实际感知时长 < 1.5s）。

---

### 公式 3：`session_death_count`（会话死亡计数）

MVP 阶段为单纯整型累加器，不引入公式。

```
session_death_count = session_death_count + 1   （每次 player_died 触发时执行）
```

**变量：**
| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 会话死亡次数 | `session_death_count` | int | [0, +∞) | 当前会话累计死亡次数，Boss 击败后重置 |

**输出范围：** 无上限（MVP 不设截断）。
**示例：** 第 7 次死亡 → `session_death_count = 7` → 发出 `retry_death_count_changed(7)` 信号供 HUD 订阅。

## Edge Cases

- **如果 `player_died` 信号触发时重试系统已在死亡屏幕序列（任意非 ACTIVE 状态）**：忽略该信号，不重复触发序列（防止极端帧内多重 `player_died`）

- **如果玩家在 `retry_invuln_duration`（2.0s）期间承受攻击**：所有 `apply_damage(PLAYER, ...)` 调用被忽略（由伤害/生命系统的 INVULNERABLE 状态处理，本系统不干预）

- **如果场景重置/重载时间超过 1.5s 死亡屏幕窗口**：场景继续加载直至完成，玩家可见黑屏延伸——这是 Acceptance Criteria 的 FAIL 条件，工程需通过场景重用、异步加载或资产预加载等手段保证在 1.5s 内完成（具体策略由 ADR 决定）

- **如果玩家在死亡屏幕任意帧按键跳过**：立即跳至 `RESUMING` 状态触发即时重开（Art Bible 7.5 规范允许任意帧跳过）；本系统不区分跳过早晚

- **如果玩家和 Boss 同一帧同时归零（同归于尽）**：`boss_defeated` 信号优先于 `player_died`——算作玩家胜利，触发胜利序列，不触发死亡屏幕。同帧冲突规则：以 `boss_defeated` 优先（对玩家有利原则）

- **如果玩家在死亡屏幕序列中强制退出游戏**：MVP 无持久化，退出即重置——下次进入时 Boss 满血开始新战斗，符合预期

- **如果 Boss 数据资产中 `boss_max_hp = 0`（数据配置错误）**：RetryContext 加载时发现阶段数据异常，输出错误日志，以 Phase 1 满血启动（安全降级）

- **如果 Boss 数据资产中缺失 Boss 相位符号（`phase_symbol` 字段未配置）**：死亡屏幕跳过 `PHASE_SYMBOL` 和 `SYMBOL_FADE_OUT` 阶段（仍保留红闪 + 渐灰 0.6s + 0.9s 纯灰屏等待），并在日志中记录警告——Art Bible 7.5 要求该符号存在

## Dependencies

### 上游依赖（本系统需要它们）

| 系统 | 依赖类型 | 具体接口 | 状态 |
|------|----------|----------|------|
| **伤害/生命系统** | 硬依赖 | 订阅 `player_died` 信号——这是本系统的唯一触发点 | ✅ 已设计 |
| **Boss 状态机系统** | 硬依赖 | 重试时读取 `current_boss_hp`、`current_boss_phase`；重载后传入保留值 | ✅ 已设计 |
| **玩家角色控制系统** | 硬依赖 | 重载后设置玩家起始位置、初始化 `retry_invuln_duration` 无敌状态 | ✅ 已设计 |
| **存档系统** | 软依赖（MVP 可选） | MVP：不涉及；Alpha：Boss 击败后写入胜利记录 | ⚠️ 未设计（Alpha 优先级） |

### 下游（依赖本系统的系统）

| 系统 | 依赖类型 | 具体接口 |
|------|----------|----------|
| **HUD 系统** | 软依赖 | 订阅 `retry_death_count_changed(count: int)` 信号显示死亡计数器 |

### 双向一致性说明

- `伤害/生命系统` GDD 已在"Interactions with Other Systems"中列出本系统为订阅方 ✅
- `Boss 状态机系统` GDD 已在其核心规则中处理"重试时 Boss HP 保留"逻辑 ✅
- `HUD 系统` 尚未设计——本 GDD 中定义信号接口作为占位契约，HUD GDD 设计时需引用 ✅

## Tuning Knobs

唯一的真正可调旋钮是 `RETRY_INVULN_BASE`（游戏机制层）。死亡屏幕序列的 4 个时长由 Art Bible Section 7.5 锁定，调整需 Art Bible 修订流程批准。

| 旋钮名 | 基准值 | 调整范围 | 过高的影响 | 过低的影响 |
|--------|--------|---------|------------|------------|
| `RETRY_INVULN_BASE`（游戏机制）| 2.0s | 1.5s – 2.5s | 玩家无法被快速惩罚；失去「站稳后需立刻读预警」的紧张感 | 玩家落地就可能中弹，产生「重生即死」的挫败感 |
| `red_flash_duration`（Art Bible 锁定）| 0.2s | 不可调 | — | — |
| `fade_to_grey_duration`（Art Bible 锁定）| 0.4s | 不可调 | — | — |
| `phase_symbol_display_duration`（Art Bible 锁定）| 0.6s | 不可调 | — | — |
| `symbol_fade_out_duration`（Art Bible 锁定）| 0.3s | 不可调 | — | — |

**约束：**
- `RETRY_INVULN_BASE` 必须严格 > `player_hit_invuln_duration`（0.5s，注册表锁定值）
- 死亡屏幕 4 段时长总和必须等于 1.5s（Art Bible Section 7.5 总长锁定）。如需修改任一时段，需走 Art Bible 修订流程并同步更新整个序列。

## Visual/Audio Requirements

**严格遵循 Art Bible Section 7.5「死亡屏幕 / 重试」规范。本节复述该规范以确保实现一致性。**

### 视觉序列（1500ms 总时长）

| 时间段 | 视觉表现 | 颜色 / 资产 |
|--------|---------|------------|
| **0–200ms** `RED_FLASH` | 死亡动画最后一帧，叠加全屏 40% 红色瞬闪 | `#CC2200`，持续 2 帧后立即退出 |
| **200–600ms** `FADE_TO_GREY` | 画面线性褪色至深灰（**非纯黑**——纯黑是空无，深灰是沉默）| `#0A0A0C`，线性过渡 400ms |
| **600–1200ms** `PHASE_SYMBOL` | 屏幕中央出现该 Boss 的**相位符号**——Boss 身上某个视觉元素的最小几何抽象，静止无动画，直接出现 | 霜白邻近色绘制，唯一可见视觉元素 |
| **1200–1500ms** `SYMBOL_FADE_OUT` | 相位符号线性淡出 | 300ms 线性 |
| **1500ms** | 切回 Boss 战开始位置 | — |
| **任意帧** | 玩家输入 → 立即跳至 1500ms 时刻重开 | — |

### Boss 相位符号的设计原则

**教育价值（Art Bible 原话）：** 玩家多次失败时，他们会开始记住这个符号的细节——对符号越熟悉，说明越了解这个 Boss。符号本身是一道谜题，这是「死亡是教师」的视觉化。

每个 Boss 必须在其数据资产（BossData）中提供 `phase_symbol` 字段，由 art-director 在 Boss 美术设计阶段定义。

### 绝对禁止项（Art Bible 强制规则）

死亡屏幕**绝对禁止**包含以下任一元素：

- ❌ Retry / 重试按钮
- ❌ 加载进度条
- ❌ 死亡计数（如「第 N 次尝试」）
- ❌ 成就 / 掉落提示
- ❌ **任何提示文字**（包括按键提示）
- ❌ 「你死了」或任何类似文字

死亡屏幕是"一页翻过去的书页"，不是"惩罚仪式"——玩家面对的是 Boss 的相位符号，不是 UI。

### 重生视觉

场景恢复后，玩家角色处于 `retry_invuln_duration = 2.0s` 无敌状态，视觉上通过 0.3–0.5s 透明淡入 + 持续闪烁/微透明标示无敌。具体实现规范由玩家角色控制系统 GDD 的 Visual/Audio 节定义。

### 音效

| 事件 | 是否配音效 | 方向 |
|------|-----------|------|
| 死亡瞬间（红闪）| 由玩家角色控制系统处理 | 沉重打击/低频共鸣音 |
| FADE_TO_GREY 期间 | BGM 淡出 | 0.4s 内 BGM 静音 |
| PHASE_SYMBOL 期间 | 静默 | "沉默"——非"空白"；与深灰背景共同传达一页书页的翻动感 |
| 重开瞬间 | Boss 主题低音重启 | 与场景恢复同步 |
| 玩家跳过死亡屏幕 | 无额外音效 | 跳过不应有"反馈音"——它不是动作，是缩短等待 |

### 与 Art Bible 的同步义务

本节内容由 Art Bible Section 7.5 派生。若 Art Bible 修订（如改变时长、添加视觉元素），本节须同步更新。任何对死亡屏幕的修改提案必须通过 art-director 审批后才能进入本 GDD。

> 📌 **Asset Spec** — Visual/Audio 需求已定义。Art Bible 批准后，运行 `/asset-spec system:instant-retry-system` 生成死亡屏幕过渡动画和 Boss 相位符号的资产规格。

## UI Requirements

**本系统无 UI 元素**（Art Bible Section 7.5 强制规则）。死亡屏幕**不是 UI 界面**，是一段视觉/音频过渡序列——所有规范见 Visual/Audio Requirements 节。

仅有的"输入处理"是：任意键监听以触发死亡屏幕跳过（直接跳至 1500ms 时刻）。此监听不构成 UI，无视觉提示，无按键图标显示。

**输入支持：** 键盘任意键 / 手柄任意键 / 鼠标点击均可触发跳过。

> **本系统不需要 UX Spec**——无 UI 元素，无菜单导航，无可见控件。后续版本若要加入「放弃战斗 / 返回主菜单」等选项，应作为暂停菜单系统的功能，而非死亡屏幕的扩展。

## Acceptance Criteria

**AC-01 — 触发监听**
**GIVEN** 战斗场景已加载完成，RetrySystem 处于 `ACTIVE` 状态，**WHEN** 伤害/生命系统发出 `player_died` 信号，**THEN** 系统在同一帧内进入 `DYING` 状态，游戏逻辑时间暂停，死亡渐黑过渡开始播放。

**AC-02 — 死亡屏幕序列时长（Art Bible 7.5）**
**GIVEN** RetrySystem 收到 `player_died` 信号且玩家不按任何键，**WHEN** 死亡屏幕完整序列执行，**THEN** 各阶段时长精确匹配：RED_FLASH 0.2s ± 16.6ms / FADE_TO_GREY 0.4s ± 16.6ms / PHASE_SYMBOL 0.6s ± 16.6ms / SYMBOL_FADE_OUT 0.3s ± 16.6ms / 总时长 1.5s ± 16.6ms。

**AC-03 — 死亡屏幕任意帧可跳过**
**GIVEN** 死亡屏幕序列正在进行（任意状态：RED_FLASH / FADE_TO_GREY / PHASE_SYMBOL / SYMBOL_FADE_OUT），**WHEN** 玩家按任意键，**THEN** 系统立即跳至 `RESUMING` 状态，剩余时间不再等待，无 UI 提示或视觉反馈表明"已跳过"。

**AC-04 — RetryContext 数据传递**
**GIVEN** Boss 当前 HP 为 X、处于阶段 P，死亡前 `session_death_count` 为 N，**WHEN** 死亡屏幕序列结束（自动或跳过），场景重置/重载完成，**THEN** RetryContext 存储：`preserved_boss_hp = X`、`preserved_boss_phase = P`、`session_death_count = N + 1`，且新场景启动后可读取这三个值。

**AC-05 — Boss 血量保留**
**GIVEN** 上次尝试结束时 Boss HP 为 X（例：347），**WHEN** 场景重载完成，Boss 实体初始化，**THEN** `Boss.current_hp = 347`（与 `preserved_boss_hp` 精确匹配，允许 ±0）。

**AC-06 — Boss 状态机重置**
**GIVEN** 重试前 Boss 处于任意非 IDLE 状态（如攻击中），**WHEN** 场景重载完成，**THEN** Boss 状态机处于 `IDLE`，无进行中的攻击动画，Boss 位置回到战斗起始点。

**AC-07 — 玩家满 HP 出生**
**GIVEN** 玩家上次尝试中途掉血（HP < 100），**WHEN** 重试后场景加载完成，**THEN** `player.current_hp = 100`（= `player_max_hp`），HP 条显示满值。

**AC-08 — 重生无敌期时长**
**GIVEN** 场景重载完成，玩家以满 HP 出现，`RETRY_INVULN_BASE = 2.0s`，**WHEN** Boss 在玩家出生后 0.5s 内造成攻击，**THEN** 玩家 HP 不变（仍为 100），无敌持续至 2.0s 时刻后失效（允许 ±16.6ms 误差）。

**AC-09 — 无敌期结束后可正常受伤**
**GIVEN** 玩家重生后无敌期已满 2.0s，**WHEN** Boss 造成一次伤害，**THEN** 玩家 HP 正常扣减，无敌保护关闭；且确认 `retry_invuln_duration = 2.0s` 严格 > `player_hit_invuln_duration = 0.5s`。

**AC-10 — Boss 击败后新战斗满血**
**GIVEN** 玩家将 Boss HP 打至 0，`boss_defeated` 信号已发出，**WHEN** 玩家重新进入同一 Boss 战斗（新战斗，非重试），**THEN** `Boss.current_hp = boss_max_hp`（满血），RetryContext 无 `preserved_boss_hp` 残留值。

**AC-11 — 无资源惩罚**
**GIVEN** 玩家重试前持有资源值 G、能力树状态为 S，**WHEN** 重试序列完成，玩家以满 HP 出现，**THEN** 资源值仍为 G，能力树状态仍为 S，无任何扣减。

**AC-12 — 死亡次数不改变行为**
**GIVEN** 分别在 `session_death_count = 1` 和 `session_death_count = 50` 时触发重试，**WHEN** 两次序列各自执行完成（均不跳过），**THEN** 死亡屏幕 4 段时长、Boss 相位符号呈现、Boss HP 传递、玩家出生 HP、无敌时长完全相同，无分支行为。

**AC-13 — 死亡计数累加**
**GIVEN** `session_death_count` 当前为 N，**WHEN** `player_died` 触发，RetryContext 完成记录，**THEN** `session_death_count = N + 1`，HUD 收到 `retry_death_count_changed(N + 1)` 信号。

**AC-14 — 总死亡屏幕时长硬约束（Art Bible 7.5）**
**GIVEN** 标准测试机配置（满足最低规格），玩家不按键，从 `player_died` 信号触发时计时，**WHEN** 完整死亡屏幕序列执行 + 场景重置/重载在窗口内完成，**THEN** 总时间从信号到玩家角色可操作 = 1.5s ± 16.6ms（1 帧）。

**AC-14b — 场景重载工程约束**
**GIVEN** 标准测试机配置，**WHEN** 死亡屏幕 1.5s 窗口结束，**THEN** 场景已就绪可渲染玩家可操作状态——若场景加载超过 1.5s 导致玩家看到额外黑屏延伸，AC 标记 FAIL。

**AC-15b — 死亡屏幕无任何禁止 UI 元素**
**GIVEN** 死亡屏幕序列进行中（任意阶段）, **WHEN** 截屏检查可见元素, **THEN** 屏幕上不出现以下任一元素：Retry/重试按钮 / 加载进度条 / 死亡计数文字 / 成就提示 / 按键提示 / "你死了"或类似文字。仅可见的视觉元素为：红闪（0-200ms）/ 深灰背景 / Boss 相位符号（600-1500ms）。

**AC-17b — Boss 相位符号缺失安全降级**
**GIVEN** Boss 数据资产 `phase_symbol` 字段未配置, **WHEN** 死亡屏幕进入 PHASE_SYMBOL 阶段, **THEN** 输出警告日志（包含 boss_id），保持深灰屏 0.9s（PHASE_SYMBOL 600ms + SYMBOL_FADE_OUT 300ms 合并为纯灰等待），1.5s 总时长不变，游戏不崩溃。

**AC-15 — 重复信号防护**
**GIVEN** RetrySystem 已处于死亡屏幕序列（任意非 ACTIVE 状态：RED_FLASH / FADE_TO_GREY / PHASE_SYMBOL / SYMBOL_FADE_OUT / RESUMING），**WHEN** `player_died` 信号再次触发，**THEN** 系统忽略该信号，不重置 `preserved_boss_hp`，序列继续正常执行。

**AC-16 — 同归于尽优先规则**
**GIVEN** 玩家 HP = 1，Boss HP = 1，同一帧双方均受致命伤害，**WHEN** `player_died` 与 `boss_defeated` 同帧触发，**THEN** 胜利序列执行（`boss_defeated` 优先），不触发重试过渡，不显示「再试一次」界面。

**AC-17 — Boss 数据异常安全降级**
**GIVEN** 某 Boss 数据资产中 `boss_max_hp = 0`（配置错误），**WHEN** RetryContext 尝试传入 `preserved_boss_hp`，**THEN** 错误日志包含可识别警告，Boss 以 Phase 1 满血启动（安全降级），游戏不崩溃，重试流程可正常完成。

## Open Questions

1. **Boss 阶段保留是否需要视觉反馈**（owner: 设计负责人）：重试时玩家面对 Phase 2 Boss，是否需要 UI 提示「Boss 已进入阶段 2」？待 HUD GDD 设计时决定。

2. **场景重置/重载在 1.5s 死亡屏幕窗口内完成的实现策略**（owner: 引擎/性能负责人）：Art Bible 7.5 锁定 1.5s 总时长，场景必须在此窗口内就绪。可选策略：场景重用（in-place reset）vs 异步加载（async load）。MVP 简单场景下可能两者皆可；Alpha 阶段 Boss 资产增加后选项收窄。需要 ADR 决议，在 `/gate-check pre-production` 时验证。

3. **主菜单/放弃战斗的交互**（owner: UX 设计）：MVP 重试界面无「放弃」选项——玩家退出依赖系统级暂停（Alt+F4 或平台暂停菜单）。正式版需独立设计。
