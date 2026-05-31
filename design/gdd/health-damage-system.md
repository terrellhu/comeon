# 伤害/生命系统 (Health & Damage System)

> **Status**: Designed (Pending Review)
> **Author**: game-designer + systems-designer
> **Last Updated**: 2026-05-31
> **Implements Pillar**: Pillar 1「读懂才能赢」/ Pillar 4「失败是学习」

## Summary

伤害/生命系统记录玩家和每个 Boss 的 HP，将传入伤害换算为数值损失，并检测死亡条件。它是格挡/预警、反击连段、治疗等所有战斗系统的数学基础——这些系统最终都通过读取或写入本系统的数据产生意义。游戏的「失败是学习」原则在此系统得到实现：死亡无惩罚，但每次承伤都是玩家错误读取 Boss 预警的可量化代价。

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `None`

## Overview

伤害/生命系统管理两类 HP 池：玩家的生命条，以及每个 Boss 的多阶段血量。系统不直接与物理碰撞或动画交互——它通过信号接收外部系统传来的"伤害事件"，将其应用到 HP 上，并向订阅者广播变化结果。玩家 HP 归零时发出 `player_died` 信号，触发即时重试系统；Boss HP 降至阶段阈值时发出 `boss_phase_changed` 信号，触发 Boss 状态机的阶段转换。伤害系统不决定"格挡是否成功"——格挡/预警系统在传递伤害事件之前就完成了这一判断，只有穿透格挡的攻击才会到达本系统。

## Player Fantasy

承伤不是"数字减少"——是错误判断的物理化显现。每一滴血代表的是：我没有读懂它。

当玩家站在 Boss 面前，意识到"我只剩最后一格 HP"，战斗不会变得沮丧——它会变得清醒。注意力突然收窄，每个预警的橙光都变得不可回避，时间感受在成功格挡那一刻明显放慢。

反过来，当玩家全程无伤结束一局，这种感觉不是轻松——是凝固的成就感：*我完全读懂了这个神明的语言。*

HP 系统的幻想目标是**代价真实，但可控**。不是"失去资源的恐惧"，而是"失误成本"——可接受的失误代价让玩家保持投入，而不是退出游戏。

## Detailed Design

### Core Rules

**玩家 HP**

1. 玩家有一个连续数值 HP 池：`current_player_hp`（浮点数，范围 0–`player_max_hp`）。内部为连续值，HUD 将其转换为段数显示（每段 = `player_max_hp ÷ player_hp_segments`）。
2. 伤害事件通过 `apply_damage(target, amount)` 函数到达本系统。`target` 为 `PLAYER` 或 `BOSS`。**本系统不判断伤害是否应该被应用**——这由调用方（格挡/预警系统、闪避系统）负责。穿过格挡和闪避判断后，才调用此函数。
3. 受击后玩家进入**无敌帧窗口**（`player_hit_invuln_duration`，默认 0.5s）。窗口期内，`apply_damage(PLAYER, ...)` 调用被忽略。防止多段攻击动画的单次攻击产生多次伤害。
4. `current_player_hp` 降至 0 或以下：钳制为 0，立即发出 `player_died` 信号，无缓冲期。
5. 治疗事件通过 `apply_healing(PLAYER, amount)` 到达。治疗不能超过 `player_max_hp`。

**Boss HP**

6. 每场战斗开始时，Boss 有独立 HP 池：`current_boss_hp`（浮点数，0–`boss_max_hp`）。`boss_max_hp` 和阶段阈值定义在每个 Boss 的数据资产中，不在本系统硬编码。
7. 玩家死亡重试时，**Boss HP 不重置**——玩家从 Boss 当前血量继续挑战。（"失败是学习"：打掉的 HP 是学习的成果，不应被撤回。）
8. `current_boss_hp` 首次降至阶段阈值或以下时：发出 `boss_phase_changed(from_phase, to_phase)` 信号。HP 继续下降；阶段转换是通知，不是屏障。
9. `current_boss_hp` 降至 0 或以下：钳制为 0，发出 `boss_defeated` 信号。

---

### States and Transitions

**玩家 HP 状态：**

| 状态 | 进入条件 | 退出条件 | 行为 |
|------|----------|----------|------|
| ALIVE | 初始状态 / HP 恢复后 > 0 | HP ≤ 0 | 正常接收伤害 |
| INVULNERABLE | 受击后立即进入 | 无敌帧计时器结束（0.5s） | `apply_damage(PLAYER)` 调用被忽略 |
| DEAD | `current_player_hp` ≤ 0 | 即时重试系统重置场景 | 发出 `player_died`；等待重试 |

**Boss HP 阶段（以 2 阶段 Boss 为例）：**

| 阶段 | HP 范围 | 进入触发 | 退出触发 |
|------|---------|----------|----------|
| PHASE_1 | 100% → 60% | 战斗开始 | HP 首次 ≤ 60% |
| PHASE_2 | 60% → 0% | HP ≤ 60% | HP ≤ 0 |
| DEFEATED | 0% | HP ≤ 0 | — |

*阶段数量和阈值百分比为 Boss 数据资产的配置项，不在本系统写死。*

---

### Interactions with Other Systems

| 系统 | 方向 | 接口 |
|------|------|------|
| 格挡/预警系统 | → 调用本系统 | 未格挡的 Boss 攻击：`apply_damage(PLAYER, amount)` |
| 反击连段系统 | → 调用本系统 | 格挡成功后的反击：`apply_damage(BOSS, amount)` |
| 治疗系统 | → 调用本系统 | `apply_healing(PLAYER, amount)` |
| Boss 状态机 | ← 订阅信号 | 订阅 `boss_phase_changed`，触发阶段行为变化 |
| 即时重试系统 | ← 订阅信号 | 订阅 `player_died`，触发重试流程 |
| HUD 系统 | ← 订阅信号 | 订阅 `player_hp_changed(current, max)` 和 `boss_hp_changed(current, max, phase)` 更新显示 |
| 闪避系统 | → 调用本系统（或拦截） | 闪避无敌期间不调用 `apply_damage`（由闪避系统自行拦截） |

## Formulas

### 公式 1：玩家承伤公式 (Player Damage Intake)

```
player_damage_intake = attack_base_damage
```

每次未格挡命中为固定伤害，定义在 Boss 数据资产的每个攻击上（无阶段缩放乘数）。

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 攻击基础伤害 | attack_base_damage | float | 5–40 | Boss 数据资产中该次攻击的固定伤害值 |
| 玩家实际承伤 | player_damage_intake | float | 5–40 | 施加到 current_player_hp 的扣减量 |

**Output Range**: 5 to 40（由 Boss 数据资产配置）

**Example（player_max_hp=100，5 段 × 20 HP）：**
- 轻攻击：`attack_base_damage = 10` → 损失半格血
- 重攻击：`attack_base_damage = 25` → 损失 1.25 格血（玩家必须格挡）
- 致命技：`attack_base_damage = 40` → 损失 2 格血

**MVP Boss 攻击建议**：轻攻击 (10)、中攻击 (20)、重攻击/致命技 (40)；无格挡玩家 4–6 次命中内死亡。

---

### 公式 2：Boss 承伤公式 (Boss Damage Intake)

本公式的乘数表由**反击连段系统**（`design/gdd/counter-attack-combo.md` 公式 1）权威定义。本系统仅描述 Boss HP 如何接收伤害事件——伤害数值的计算与命中位置乘数表归属反击连段系统。

```
boss_damage_intake = hit_damage(n)
                   = counter_base_damage × multiplier[n]   # 见 counter-attack-combo.md 公式 1
```

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 反击基础伤害 | counter_base_damage | float | 20（注册表常量） | 反击连段基础参照值 |
| 击数 | n | int | {1, 2, 3} | 当前连击的击数 |
| 击数乘数 | multiplier[n] | float | {0.8, 1.1, 1.6} | 由 `counter-attack-combo.md` 公式 1 定义；本 GDD 不重复定义 |
| Boss 实际承伤 | boss_damage_intake | float | 16–32 | 施加到 current_boss_hp 的扣减量 |

**Output Range**: 离散三值 {16, 22, 32} hp（基于 counter_base_damage=20）。

**Example（boss_max_hp=1000，counter_base_damage=20）：**
- 完整 3 连击：16 + 22 + 32 = **70 HP**（7% Boss 血量）
- 击败 Boss 需要约 **14–15 次完整反击序列**

**所有权说明**：调整连击伤害平衡时只编辑 `counter-attack-combo.md` 的 `multiplier[n]` 和相关 Tuning Knobs。本系统的接口（`apply_damage(BOSS, amount)`）对乘数表不可见——它只接收最终伤害值。

---

### 公式 3：Boss 阶段阈值检测 (Phase Threshold Detection)

```
phase_check_triggered = (current_boss_hp / boss_max_hp) <= phase_threshold_pct
                        AND phase_index NOT IN entered_phases
```

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 当前 Boss HP | current_boss_hp | float | 0–boss_max_hp | Boss 当前血量 |
| Boss 最大 HP | boss_max_hp | float | > 0 | Boss 数据资产定义的最大血量（基准：1000） |
| 阶段阈值百分比 | phase_threshold_pct | float | 0.0–1.0 | Boss 数据资产定义的触发百分比（如 0.6 = 60%） |
| 已进入阶段集合 | entered_phases | Set\<int\> | — | 本场战斗已触发过的阶段索引集合；玩家死亡重试后持久化 |
| 检测结果 | phase_check_triggered | bool | true / false | true = 发出 boss_phase_changed 信号 |

**Output Range**: boolean

**Example（2 阶段，阈值 60%，boss_max_hp=1000）：**
- Boss HP 650（65%）→ 受 75 伤害 → HP 575（57.5%）
- `(575/1000) = 0.575 ≤ 0.6` → true；阶段 2 不在 entered_phases → 触发
- 发出 `boss_phase_changed(PHASE_1, PHASE_2)`；玩家死亡重试后 HP 从 575 继续

---

### 公式 4：HUD 段数计算 (HP Segment Display)

```
displayed_segments = (current_player_hp <= 0) ? 0 : ceil(current_player_hp / hp_per_segment)
hp_per_segment = player_max_hp / player_hp_segments
```

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 当前玩家 HP | current_player_hp | float | 0.0–player_max_hp | 玩家当前连续 HP 值 |
| 玩家最大 HP | player_max_hp | float | > 0 | 玩家最大 HP（基准：100） |
| 每段 HP 值 | hp_per_segment | float | > 0 | player_max_hp ÷ player_hp_segments（基准：20） |
| 段数总数 | player_hp_segments | int | 1–10 | HUD 总段数（基准：5） |
| 显示段数 | displayed_segments | int | 0–player_hp_segments | HUD 实际渲染的亮段数量 |

**Output Range**: 0 to player_hp_segments（含两端）

**选择 ceil() 的理由**：玩家以"还有几格血"做战略决策；高估一点比低估安全（低估会导致"感觉有血却突然死亡"）。精确性让给段内的 HUD 渐变动画。

**Example（player_max_hp=100，player_hp_segments=5，hp_per_segment=20）：**

| current_player_hp | 计算 | displayed_segments |
|---|---|---|
| 100 | ceil(5.0) = 5 | 5（满血） |
| 61 | ceil(3.05) = 4 | 4（第 4 格有残血） |
| 60 | ceil(3.0) = 3 | 3（整数边界，掉段） |
| 1 | ceil(0.05) = 1 | 1（濒死，仍显示 1 格） |
| 0 | 特判 | **0**（强制归零） |

## Edge Cases

| 场景 | 预期行为 | 理由 |
|------|----------|------|
| **`apply_damage` 调用时玩家处于 INVULNERABLE 状态** | 调用被忽略，HP 不变，无敌帧计时器不重置 | 单次攻击动画的多段命中事件仅第一个生效 |
| **单次伤害超过当前 HP（如 HP=15，受 40 伤害）** | HP 钳制到 0，发出 `player_died`；不出现负 HP | 负 HP 值可能破坏 HUD 计算和治疗逻辑 |
| **单次 `apply_damage` 使 Boss HP 跨越多个阶段阈值** | 遍历所有未触发阶段，从低编号到高编号依次发出 `boss_phase_changed` | 保证 Boss 状态机不跳过中间阶段逻辑 |
| **`apply_healing` 使 HP 超过最大值** | HP 钳制到 `player_max_hp`；不出现 HP > max | 防止 HUD 显示超过最大段数 |
| **Boss 阶段已进入（`entered_phases` 中存在），再次 HP 跌破同一阈值** | 不重复发出 `boss_phase_changed` | 防止 Boss 状态机在边界 HP 附近反复触发阶段进入逻辑 |
| **玩家死亡重试时 Boss HP 低于下一个阶段阈值** | `entered_phases` 持久化到重试后；不重新触发已经历的阶段 | Boss HP 不重置是设计决策；阶段状态必须一致 |
| **`apply_damage(PLAYER, 0)` 或负伤害值** | 忽略，不修改 HP，不触发任何信号，不消耗无敌帧 | 防止 0 伤害事件意外消耗无敌帧窗口 |
| **`apply_damage(BOSS, amount)` 在 Boss 已 DEFEATED 后调用** | 忽略，HP 保持 0，不重复发出 `boss_defeated` | 防止动画结束前的残留攻击帧重复触发击败信号 |

## Dependencies

| 系统 | 方向 | 依赖性质 |
|------|------|----------|
| 格挡/预警系统 | 格挡系统依赖本系统 | 格挡失败时调用 `apply_damage(PLAYER, amount)` |
| 反击连段系统 | 反击系统依赖本系统 | 反击命中时调用 `apply_damage(BOSS, amount)` |
| 治疗系统 | 治疗系统依赖本系统 | 治疗时调用 `apply_healing(PLAYER, amount)` |
| 闪避系统 | 闪避系统依赖本系统 | 闪避无敌期间拦截对本系统的 `apply_damage` 调用 |
| Boss 状态机系统 | Boss 状态机依赖本系统 | 订阅 `boss_phase_changed` 信号触发阶段行为 |
| 即时重试系统 | 即时重试系统依赖本系统 | 订阅 `player_died` 信号触发重试流程 |
| HUD 系统 | HUD 系统依赖本系统 | 订阅 `player_hp_changed` 和 `boss_hp_changed` 更新显示 |
| 存档系统 | 存档系统依赖本系统（Alpha） | 玩家死亡重试后持久化 Boss HP 和 `entered_phases` 数据 |

## Tuning Knobs

| 参数 | 基准值 | 安全范围 | 增大效果 | 减小效果 |
|------|--------|----------|----------|----------|
| `player_max_hp` | 100 | 60–200 | 玩家更耐打，死亡前可接受更多失误 | 玩家更脆，每次失误代价更高 |
| `player_hp_segments` | 5 | 3–8 | HUD 段数更多，承伤粒度更细 | 段数少，每格代表更大代价 |
| `player_hit_invuln_duration` | 0.5s | 0.2–1.0s | 多段攻击中只受第一击，后续安全 | 多段攻击可叠加伤害（高风险） |
| `counter_base_damage` | 20 | 10–50 | 击败 Boss 所需连段数减少（更爽快） | 连段数增多（Boss 更耐打） |
| `boss_max_hp`（per Boss） | 1000（MVP 基准） | 600–3000 | Boss 更耐打，战斗更长 | Boss 更脆，战斗更短 |
| `phase_threshold_pct`（per Boss，per Phase） | [0.6, 0.3]（2 阶段示例） | 各阶段间距 ≥ 0.2 | 阶段转换提早，玩家更早面临变化 | 阶段转换推迟，一阶段更长 |

## Visual/Audio Requirements

| 事件 | 视觉反馈 | 音频反馈 | 优先级 |
|------|----------|----------|--------|
| **玩家受击（未格挡）** | 短暂画面边缘红光（0.3s淡出）+ 玩家角色受击动画 | 沉重打击音效（低频，有重量感） | 必须 |
| **玩家 HP 段数减少** | HUD 对应格变暗/消失（参考 HUD 系统 GDD） | 短促低沉音效（区别于受击音效） | 必须 |
| **玩家 HP 临界（1 格剩余）** | HUD 最后一格轻微闪烁（0.5 Hz，不干扰战斗读取） | 无额外音效（避免信息过载） | 推荐 |
| **玩家死亡（`player_died`）** | 玩家倒下动画 → 画面缓慢变暗（1.5s）→ Boss 阶段符号（艺术圣经 Section 7.5） | 静默（死亡瞬间无音效，反衬重量感）→ 1.5s 后 Boss 主题低音 | 必须 |
| **Boss 受击（反击命中）** | Boss 受击动画（每连击递增强度）+ hitpause（80ms on 第 3 连击） | 打击音效（随连击位置音调升高，第 3 击最响） | 必须 |
| **Boss 阶段转换（`boss_phase_changed`）** | Boss 视觉效果变化（由 Boss 状态机 GDD 定义）+ 画面轻微震动 | Boss 主题音乐层切换（由音频系统 GDD 定义） | 必须 |
| **Boss 击败（`boss_defeated`）** | Boss 倒下特效（由 Boss 数据资产定义） | 击败音效 → 叙事解锁过渡 | 必须 |

> **📌 Asset Spec** — Visual/Audio 需求已定义。艺术圣经批准后，运行 `/asset-spec system:health-damage-system` 生成每项资产的视觉描述和尺寸规格。

## Game Feel

**Feel Reference**：目标手感参考 Sekiro（《只狼》）受击感——承伤有重量，死亡瞬间清晰明确。受击帧是画面中最直接的信息，不是最吵的信息。

**反参考**：不要依赖受击后的无敌帧规避伤害——HP 代价是被动 outcome，主动防御是格挡和闪避的职责。

### Impact Moments

| Impact 类型 | 持续时间 | 效果描述 | 可调 |
|------------|---------|----------|------|
| 受击帧冻结 (hitpause) | 玩家受击：60ms；Boss 受第 3 连击：80ms | 两者同时冻结，强化接触感 | 是 |
| 画面边缘红光 | 300ms 淡出 | 玩家受击的空间反馈 | 是 |
| 画面震动 | Boss 阶段转换：200ms | 低振幅，定向（Boss 方向） | 是 |
| 手柄震动 | 玩家受击：150ms（强）；Boss 受第 3 连击：100ms（轻） | 区分"受害"和"施害"的触感 | 是 |

### Feel Acceptance Criteria

- [ ] 玩家受击后，测试者不使用"感觉没命中"或"不确定有没有受到伤害"描述
- [ ] 连击尾击（第 3 击）被测试者描述为"最响"或"最重"的那一击
- [ ] 玩家死亡瞬间，测试者明确知道是哪一次攻击击杀了他们

## UI Requirements

| 信息 | 显示位置 | 更新频率 | 触发条件 |
|------|----------|----------|----------|
| 玩家 HP 段数 | 屏幕左下 HUD | 每次 `player_hp_changed` 信号 | 任何 HP 变化 |
| Boss HP 连续血条 | 屏幕顶部 HUD | 每次 `boss_hp_changed` 信号 | Boss 受击或治疗 |
| Boss 阶段标记 | Boss HP 条内的分隔线 | 战斗开始时静态渲染 | Boss 数据资产的 `phase_threshold_pct` 数组 |
| Boss 当前阶段（视觉变化） | Boss HP 条颜色/形态变化 | `boss_phase_changed` 信号后 | 阶段转换 |

> **📌 UX Flag — 伤害/生命系统**：此系统有 UI 需求。在 Pre-Production 阶段运行 `/ux-design` 创建 HUD 的 UX 规格——在编写包含 HUD 相关内容的 Stories 之前完成。

## Cross-References

| 本文档引用 | 目标 GDD | 引用的具体元素 | 性质 |
|-----------|----------|---------------|------|
| 格挡失败后 apply_damage | `design/gdd/parry-telegraph-system.md`（待创建） | 格挡成功/失败判断逻辑 | State trigger |
| 反击命中后 apply_damage | `design/gdd/counter-combo-system.md`（待创建） | 反击伤害触发时机 | Data dependency |
| 死亡后重试流程 | `design/gdd/instant-retry-system.md`（待创建） | player_died 信号消费者 | State trigger |
| HUD 显示格数 | `design/gdd/hud-system.md`（待创建） | displayed_segments 公式输出 | Data dependency |
| Boss 阶段行为变化 | `design/gdd/boss-state-machine.md`（待创建） | boss_phase_changed 信号消费者 | State trigger |
| Boss HP 数据 | Boss 数据资产（per-Boss Resource） | boss_max_hp, phase_threshold_pct[] | Ownership handoff |

## Acceptance Criteria

- [ ] **GIVEN** 新战斗开始，默认配置，**WHEN** 检查玩家 HP 状态，**THEN** `current_player_hp` 等于 100.0，HUD 显示恰好 5 段亮格
- [ ] **GIVEN** 玩家 ALIVE，`current_player_hp`=100.0，**WHEN** 调用 `apply_damage(PLAYER, 10)`，**THEN** `current_player_hp` 变为 90.0，发出 `player_hp_changed(90.0, 100.0)`，无其他信号
- [ ] **GIVEN** 玩家 ALIVE，`current_player_hp`=100.0，**WHEN** 调用 `apply_damage(PLAYER, 10)` 后 0.3s 内再次调用 `apply_damage(PLAYER, 20)`，**THEN** 第二次调用被完全忽略，HP 保持 90.0，无敌帧计时器不重置
- [ ] **GIVEN** 玩家 INVULNERABLE（剩余 0.2s），**WHEN** 调用 `apply_damage(PLAYER, 20)`，**THEN** HP 不变，无信号，无敌帧计时器仍为约 0.2s（不重置为 0.5s）
- [ ] **GIVEN** 玩家 ALIVE，`current_player_hp`=15.0，**WHEN** 调用 `apply_damage(PLAYER, 40)`，**THEN** `current_player_hp` 钳制为 0.0（不出现 -25.0），同帧立即发出 `player_died`，无缓冲期
- [ ] **GIVEN** 玩家 ALIVE，`current_player_hp`=80.0，**WHEN** 调用 `apply_healing(PLAYER, 30)`，**THEN** `current_player_hp` 变为 100.0（不出现 110.0），发出 `player_hp_changed(100.0, 100.0)`
- [ ] **GIVEN** 新战斗开始，`boss_max_hp`=1000.0 来自 Boss 数据资产，**WHEN** 检查系统源文件，**THEN** 数字 1000.0 不以字面常量形式出现在任何 `.gd` 文件中——仅从数据资产读取
- [ ] **GIVEN** 玩家死亡时 Boss HP=750.0，**WHEN** 即时重试系统重置场景，新一轮战斗开始，**THEN** `current_boss_hp` 仍为 750.0，未重置为 1000.0
- [ ] **GIVEN** Boss 阶段 2 未在 `entered_phases` 中，`current_boss_hp` 从 650.0 受伤降至 575.0（低于 60% 阈值 600.0），**WHEN** 伤害应用，**THEN** `boss_phase_changed(PHASE_1, PHASE_2)` 发出恰好一次，阶段 2 加入 `entered_phases`
- [ ] **GIVEN** `current_boss_hp`=30.0，**WHEN** 调用 `apply_damage(BOSS, 30)`，**THEN** `current_boss_hp` 钳制为 0.0，`boss_defeated` 发出恰好一次，无重复信号
- [ ] **GIVEN** `attack_base_damage`=25（来自 Boss 数据资产），**WHEN** 调用 `apply_damage(PLAYER, 25)`，`current_player_hp`=100.0，**THEN** HP 变为 75.0——无缩放乘数，平坦扣减
- [ ] **GIVEN** `attack_base_damage`=40，`current_player_hp`=80.0，**WHEN** 调用 `apply_damage(PLAYER, 40)`，**THEN** `current_player_hp` 恰好变为 40.0，公式 1 无额外缩放
- [ ] **GIVEN** `counter_base_damage`=20，完成 3 连击反击序列（乘数 [0.8, 1.1, 1.6] 来自 `counter-attack-combo.md` 公式 1），**WHEN** 三次 `apply_damage(BOSS, ...)` 依次执行，**THEN** 第 1 击减 16.0，第 2 击减 22.0，第 3 击减 32.0，合计 70.0 HP
- [ ] **GIVEN** `player_max_hp`=100.0，`player_hp_segments`=5，`current_player_hp`=61.0，**WHEN** 计算 HUD 段数，**THEN** `displayed_segments`=4（`ceil(61/20)=ceil(3.05)=4`）
- [ ] **GIVEN** `current_player_hp`=60.0，**WHEN** 计算 HUD 段数，**THEN** `displayed_segments`=3（`ceil(60/20)=ceil(3.0)=3`，整数边界触发掉段）
- [ ] **GIVEN** `current_player_hp`=0.0，**WHEN** 计算 HUD 段数，**THEN** `displayed_segments`=0（特判守卫优先触发）
- [ ] **GIVEN** 玩家 INVULNERABLE，**WHEN** 调用 `apply_damage(PLAYER, 25)`，**THEN** HP 不变，计时器不重置，零信号发出
- [ ] **GIVEN** `current_player_hp`=15.0，**WHEN** 调用 `apply_damage(PLAYER, 40)`，**THEN** HP 为 0.0（不为 -25.0），`player_died` 发出一次，系统状态中不存在负 HP 值
- [ ] **GIVEN** Boss 有阈值 60% 和 30%，两个阶段均未进入，`current_boss_hp`=650.0，**WHEN** 单次调用 `apply_damage(BOSS, 400)` 使 HP 降至 250.0，**THEN** 先发出 `boss_phase_changed(PHASE_1, PHASE_2)`，再发出 `boss_phase_changed(PHASE_2, PHASE_3)`，顺序不颠倒，无阶段跳过
- [ ] **GIVEN** `current_player_hp`=80.0，**WHEN** 调用 `apply_healing(PLAYER, 40)` 会超过上限，**THEN** HP 钳制为 100.0，120.0 从未写入 HP 字段
- [ ] **GIVEN** 玩家 ALIVE，**WHEN** 调用 `apply_damage(PLAYER, 0)`，**THEN** HP 不变，无信号，不进入 INVULNERABLE（无敌帧窗口未被消耗）
- [ ] **GIVEN** 玩家 ALIVE，**WHEN** 调用 `apply_damage(PLAYER, -10)`（负值），**THEN** HP 不变，无信号，不进入 INVULNERABLE
- [ ] **GIVEN** Boss 已 DEFEATED（`boss_defeated` 已发出，HP=0.0），**WHEN** 调用 `apply_damage(BOSS, 20)`（残留攻击帧），**THEN** HP 保持 0.0，`boss_defeated` 不重复发出，无信号
- [ ] **GIVEN** 每帧均有伤害事件，连续 1000 帧处理，**WHEN** 所有调用和信号完成，**THEN** 系统单帧处理耗时低于 1.0ms，通过 Godot 性能监视器验证
- [ ] **GIVEN** GDD 规定各基准值（`player_max_hp`=100 等），**WHEN** 搜索系统源文件，**THEN** 任何 `.gd` 文件中均不存在这些硬编码数字——全部通过导出变量或数据资产读取

## Open Questions

| 问题 | 负责人 | 解决时机 | 解决状态 |
|------|--------|----------|----------|
| 反击连段若超过 3 连击（进阶/能力系统解锁），`multiplier[n]` 数组（见 `counter-attack-combo.md`）如何扩展？ | 进阶/能力系统 GDD | 设计进阶/能力系统时 | 待定 |
| 治疗系统中"消耗资源"的资源类型是什么？本系统的 `apply_healing` 接口是否需要携带资源成本参数？ | 治疗系统 GDD | 设计治疗系统时 | 待定 |
| Boss 数据资产的具体格式（GDScript Resource 子类 vs JSON）？影响 `boss_max_hp` 和 `phase_threshold_pct` 的读取方式 | 架构决策（ADR） | /create-architecture 阶段 | 待定 |
