# Boss 状态机系统 (Boss State Machine System)

> **Status**: Designed (Pending Review)
> **Author**: game-designer + ai-programmer
> **Last Updated**: 2026-05-31
> **Implements Pillar**: Pillar 2「每个神明都是一首歌」/ Pillar 1「读懂才能赢」

## Overview

Boss 状态机系统是每个 Boss 战斗的"意志"——它决定 Boss 在任何时刻做什么，以及这些行为如何随战斗进程演化。**基础设施层**：系统维护一个多层状态机（阶段层 → 行为层 → 攻击层），通过 Boss 数据资产（每 Boss 独立的 Resource 文件）驱动具体行为，使所有 Boss 共享同一状态机框架，但拥有完全不同的攻击词汇表、节奏模式和阶段转换逻辑。**玩家层**：玩家感受到的是"每个神明独特的攻击语言"——一组可识别但不可完全预测的攻击模式。Boss 的"歌"（Pillar 2）通过攻击序列编排实现：轻攻击、重攻击、横扫的节奏组合构成 Boss 特有的战斗节奏，玩家逐渐"听懂"这首歌并精准格挡（Pillar 1）。

系统与格挡/预警系统通过信号完全解耦：Boss 状态机发出 `attack_telegraphed(type, damage)` 通知格挡系统攻击即将到来，收到 `stagger_ended` 后恢复行动，收到伤害/生命系统发出的 `boss_phase_changed(from, to)` 后触发阶段行为变化。**Boss 状态机不直接修改 HP**——它只响应 HP 变化的结果（阶段转换），也不决定玩家伤害数值（均在 Boss 数据资产中配置）。Boss 数据资产结构（Resource 子类 vs JSON）和 Boss 工厂/注册模式将在 `/create-architecture` 阶段定义为 ADR。

## Player Fantasy

Boss 状态机系统不是玩家直接使用的东西——它是玩家要"破解"的谜题。

每场战斗开始时，Boss 就像一首陌生的歌。你不知道它的节奏，不知道下一击是轻还是重，不知道它什么时候会改变节奏。头几次死亡是数据采集——你在读懂这个神明的语言。

然后某个时刻，Boss 的行为开始变得可预测。你察觉到"它在连续用两次 LIGHT 之后必定会来一次 HEAVY"。这不是随机——这是可学习的模式。状态机系统的任务是保证这个模式**存在且可识别**，而不是完全随机。

阶段转换是故事的转折：Boss 的 HP 跌破阈值，世界发生了变化。新的攻击出现，节奏加快，原来熟悉的那首歌变成了下一章。这种"Boss 的歌发生了质变"的感受，是 Pillar 2「每个神明都是一首歌」的核心实现。

> **设计成功标准**：玩家击败 Boss 后能用语言描述"它的攻击模式"——这说明状态机的节奏模式清晰且可学习。如果玩家只说"它是随机的"，状态机设计失败。

## Detailed Design

### Core Rules

**多层状态机结构 (Multi-Layer State Machine)**

1. Boss 状态机分三层：
   - **阶段层 (Phase Layer)**：当前处于哪个阶段（PHASE_1、PHASE_2...）。阶段由 Boss 数据资产定义，数量不固定。
   - **行为层 (Behavior State)**：当前行为状态（IDLE / TELEGRAPHING / ATTACKING / STAGGERED / PHASE_TRANSITION / DEFEATED）。
   - **序列索引 (Sequence Index)**：当前执行攻击序列的第几个攻击（整型，0-based）。

2. Boss 状态机由 Boss 数据资产（BossData Resource）驱动。每个 Boss 有独立的数据资产；所有 Boss 共享同一状态机实现代码（工厂模式，具体架构见 ADR）。

**BossData 资产结构（概念级，非 GDScript 语法）：**

```
BossData {
  boss_id: String
  phases: Array[PhaseData]
}

PhaseData {
  phase_index: int
  attack_sequence: Array[AttackData]   # 完全脚本化攻击顺序
  idle_duration_after_attack: float    # 每次攻击后的停顿时长（秒）
  phase_transition_anim: String        # 进入本阶段的过渡动画名
}

AttackData {
  attack_type: AttackType              # LIGHT / HEAVY / SWEEP
  damage: float                        # 穿透格挡的伤害值（5–40）
  telegraph_duration_override: float   # 0 = 使用 AttackType 默认值
}
```

**攻击序列规则**

3. IDLE 状态下，等待 `idle_duration_after_attack` 秒后，自动取序列中 `sequence_index` 位置的攻击。
4. 序列执行到末尾后，索引归零，从头循环——每个阶段的序列是无限循环的。
5. 阶段转换时，`sequence_index` 重置为 0。STAGGERED 后恢复时，序列索引**保持递进**（sequence_index++），被打断的攻击不重播，从下一位置继续。
6. 若 `telegraph_duration_override > 0`，使用覆盖值代替 AttackType 基准预警时长（允许单个 Boss 的特定攻击比全局基准更快或更慢）。

**攻击执行流程**

7. 从 IDLE 到发出攻击，依序：
   - a. `idle_timer` 倒计时完成
   - b. 从当前 PhaseData 取出 `attack_sequence[sequence_index]` 的 AttackData
   - c. 发出 `attack_telegraphed(attack_type, damage)` 信号
   - d. 启动内部 `telegraph_timer = telegraph_duration`（或 override 值）
   - e. 进入 TELEGRAPHING 状态

8. TELEGRAPHING 期间：
   - 若收到 `parry_succeeded` → 取消 telegraph_timer → 进入 STAGGERED
   - 若 `telegraph_timer` 耗尽 → 进入 ATTACKING（攻击伤害已由格挡/预警系统处理）

9. ATTACKING 期间：
   - 播放攻击动画（时长由动画资产决定，不由本系统硬编码）
   - 可选：收到 `parry_failed(attack_type)` 时叠加命中反应层动画
   - 动画结束 → sequence_index++ → 进入 IDLE

10. STAGGERED 期间：
    - 播放硬直动画；拒绝新的攻击调度
    - 收到 `stagger_ended` 信号 → sequence_index++ → 进入 IDLE

11. DEFEATED 状态：
    - 收到 `boss_defeated` 信号 → **任何时刻**立即进入 DEFEATED
    - 取消所有进行中的计时器（telegraph_timer、idle_timer）
    - 播放击败动画（TERMINAL 状态，无退出条件）

**阶段转换规则**

12. 收到 `boss_phase_changed(from_phase, to_phase)` 信号：
    - 若当前在 IDLE 或 ATTACKING → 立即进入 PHASE_TRANSITION
    - 若当前在 TELEGRAPHING → 等待本次预警周期结束后再进入 PHASE_TRANSITION（避免在攻击进行中插入过渡动画）
    - PHASE_TRANSITION 期间：播放 `PhaseData.phase_transition_anim`，不发新 `attack_telegraphed`
    - 过渡动画结束 → 更新 PhaseData 为 `to_phase`，sequence_index = 0 → 进入 IDLE

---

### States and Transitions

| 状态 | 进入条件 | 退出条件 | 行为 |
|------|----------|----------|------|
| **IDLE** | 初始状态 / ATTACKING 动画结束 / stagger_ended / PHASE_TRANSITION 结束 | idle_timer 耗尽 → TELEGRAPHING；boss_defeated → DEFEATED | 播放待机动画；倒计时 idle_duration_after_attack |
| **TELEGRAPHING** | 从 IDLE 取出下一攻击后 | parry_succeeded → STAGGERED；telegraph_timer 耗尽 → ATTACKING；boss_defeated → DEFEATED | 已发出 attack_telegraphed；内部计时 telegraph_timer；播放蓄力动画 |
| **ATTACKING** | telegraph_timer 耗尽（格挡失败或无格挡） | 攻击动画结束 → IDLE（sequence_index++）；boss_defeated → DEFEATED | 播放出击动画；可叠加 parry_failed 命中反应层 |
| **STAGGERED** | 收到 parry_succeeded | stagger_ended → IDLE（sequence_index++）；boss_defeated → DEFEATED | 播放硬直动画；不调度新攻击；等待 stagger_ended |
| **PHASE_TRANSITION** | 收到 boss_phase_changed（在合适时机） | 过渡动画结束 → IDLE（PhaseData 更新，sequence_index = 0） | 播放阶段过渡动画；不发新 attack_telegraphed |
| **DEFEATED** | 收到 boss_defeated（任何时刻） | 无（TERMINAL） | 播放击败动画；取消所有计时器 |

---

### Interactions with Other Systems

| 系统 | 方向 | 接口 |
|------|------|------|
| 格挡/预警系统 | → 发出 | `attack_telegraphed(type: AttackType, damage: float)` — 宣布即将到来的攻击 |
| 格挡/预警系统 | ← 订阅 | `parry_succeeded(attack_type)` → 进入 STAGGERED |
| 格挡/预警系统 | ← 订阅 | `stagger_ended` → 退出 STAGGERED，进入 IDLE |
| 格挡/预警系统 | ← 订阅 | `parry_failed(attack_type)` → 可选命中反应层动画（不改变状态） |
| 伤害/生命系统 | ← 订阅 | `boss_phase_changed(from, to)` → 进入 PHASE_TRANSITION（适当时机） |
| 伤害/生命系统 | ← 订阅 | `boss_defeated` → 立即进入 DEFEATED |
| 叙事解锁系统 | — | 叙事系统直接订阅伤害/生命系统的 boss_defeated，无需本系统中转 |
| HUD 系统 | — | HUD 订阅伤害/生命系统的 boss_phase_changed；无需本系统额外信号 |

## Formulas

### 公式 1：序列索引推进 (Sequence Index Advance)

```
next_index = (current_index + 1) mod N
```

**变量表：**

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 当前序列索引 | `current_index` | int | [0, N−1] | 当前攻击在 attack_sequence 中的位置（0-based） |
| 序列长度 | `N` | int | [1, +∞) | 当前 PhaseData.attack_sequence 的元素数量（空序列为非法，加载时断言） |
| 推进后索引 | `next_index` | int | [0, N−1] | 写回 sequence_index 的新值 |

**Output Range**: 始终在 [0, N−1] 内。取模运算保证边界安全，无需额外分支。  
**调用时机**: ATTACKING 动画结束时；`stagger_ended` 收到后（跳过已被打断的攻击，从下一位置继续）。  
**不经此公式的重置**: 阶段转换时直接赋值 `sequence_index = 0`。

**示例（N=4，序列末尾循环）**: `current_index=3` → `(3+1) mod 4 = 0` → 重新从头

---

### 公式 2：有效预警时长选择 (Effective Telegraph Duration)

```
T_eff = telegraph_duration_override   若 telegraph_duration_override > 0
T_eff = T_default[attack_type]        若 telegraph_duration_override = 0
```

**变量表：**

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 覆盖预警时长 | `telegraph_duration_override` | float | [0.0, +∞) | AttackData 字段；0.0 = 不覆盖，使用 AttackType 全局默认值 |
| 攻击类型 | `attack_type` | AttackType | {LIGHT, HEAVY, SWEEP} | 用于查表取默认值 |
| LIGHT 默认值 | `T_default[LIGHT]` | float | 0.8s | 常量，来自格挡/预警系统 GDD（注册表：`telegraph_duration_light`） |
| HEAVY 默认值 | `T_default[HEAVY]` | float | 1.2s | 常量，来自格挡/预警系统 GDD（注册表：`telegraph_duration_heavy`） |
| SWEEP 默认值 | `T_default[SWEEP]` | float | 1.5s | 常量，来自格挡/预警系统 GDD（注册表：`telegraph_duration_sweep`） |
| 有效预警时长 | `T_eff` | float | (0.0, +∞) | 最终写入 telegraph_timer 的初始值 |

**Output Range**: 始终 > 0（默认值为正；覆盖值应在 TELEGRAPHING 进入时 assert > 0，否则 clamp 至 0.1s 并记 warning）。  
**示例（有覆盖）**: `attack_type=LIGHT`，`override=0.5` → `T_eff = 0.5s`（比全局基准 0.8s 快 37.5%，适用于高阶段加速攻击）

---

### 公式 3：攻击序列循环时长估算 (Sequence Cycle Duration)

> **设计时工具，非运行时公式。** 帮助设计师评估一个 PhaseData 的"节拍长度"，确保玩家在一轮循环内听到完整的攻击词汇表。状态机实现不调用此计算。

```
T_cycle = Σᵢ T_eff(i) + Σᵢ T_attack(i) + N × T_idle
```

**变量表：**

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 序列长度 | `N` | int | [1, +∞) | 同公式 1 |
| 第 i 次攻击有效预警时长 | `T_eff(i)` | float | (0.0, +∞) | 由公式 2 决定 |
| 第 i 次攻击动画时长 | `T_attack(i)` | float | (0.0, +∞) | 由动画资产决定，设计时使用估算值 |
| 攻击后 IDLE 停顿 | `T_idle` | float | [0.0, +∞) | PhaseData.idle_duration_after_attack（整个 Phase 统一值） |
| 循环总时长 | `T_cycle` | float | (0.0, +∞) | 一轮完整序列估算时长（秒）；STAGGERED 时长不计入（属于玩家反击行为） |

**Output Range**: 实践参考范围 5–20 秒/轮（过短则玩家无法学习节奏；过长则需等待过久才能看到完整序列）。

**示例（Phase 2，N=3）**:

| 攻击 | attack_type | T_eff | T_attack（估算）|
|------|-------------|-------|----------------|
| 0 | LIGHT | 0.8s | 0.6s |
| 1 | HEAVY（override=1.0s） | 1.0s | 1.0s |
| 2 | SWEEP | 1.5s | 1.2s |

`T_idle = 0.5s` → `T_cycle = (0.8+1.0+1.5) + (0.6+1.0+1.2) + 3×0.5 = 3.3 + 2.8 + 1.5 = **7.6s/轮**`

## Edge Cases

- **如果 TELEGRAPHING 期间收到 `boss_phase_changed`**: 继续完成当前预警计时（不中断）；预警结束（无论攻击落地还是被格挡）后，立即进入 PHASE_TRANSITION。阶段转换信号被"暂存"，不丢弃。
- **如果 ATTACKING 期间（攻击动画播放中）收到 `boss_phase_changed`**: 等待当前攻击动画播放完毕，正常执行 `sequence_index++` 并进入 IDLE；随后立即跳过 idle 计时直接进入 PHASE_TRANSITION。视觉连贯性优先于转换即时性。
- **如果 STAGGERED 期间收到 `boss_phase_changed`**: 等待 `stagger_ended` 信号（硬直自然结束）后，跳过 IDLE 直接进入 PHASE_TRANSITION（不执行新的攻击调度）。
- **如果 PHASE_TRANSITION 期间再次收到 `boss_phase_changed`**: 丢弃新信号并记录 warning；当前过渡动画继续完整播放后，进入最新目标阶段（暂存最新的 `to_phase` 值，用于过渡结束后更新 PhaseData）。
- **如果任意状态下收到 `boss_defeated`**: 立即进入 DEFEATED（TERMINAL 状态）。取消所有进行中计时器（idle_timer、telegraph_timer）；DEFEATED 无任何退出条件。此规则优先于所有其他进行中的状态转换。
- **如果同一帧同时收到 `stagger_ended` 和 `boss_defeated`**: `boss_defeated` 优先，直接进入 DEFEATED；`stagger_ended` 被忽略。
- **如果 `attack_sequence` 为空（N=0）**: 状态机在数据资产加载阶段断言 N ≥ 1，拒绝加载并打印 error。不在运行时处理空序列——这是 Boss 设计错误，须在开发阶段暴露。
- **如果 `idle_duration_after_attack ≤ 0`**: 数据资产加载时断言 > 0（最小推荐值 0.1s）；值不合法时 clamp 至 0.1s 并记 warning。防止零停顿导致视觉上攻击无间断连发。
- **如果 `telegraph_duration_override` 被设置为极小值（< 0.016s，即 < 1 帧 @60fps）**: 公式 2 的输出在进入 TELEGRAPHING 时 assert > 0；若值非法则 clamp 至 0.1s 并记 warning。窗口时机计算不可依赖亚帧精度。
- **如果 `phase_transition_anim` 字符串对应的动画资产不存在**: 状态机跳过动画播放，直接完成 PHASE_TRANSITION 逻辑（更新 PhaseData，sequence_index=0，进入 IDLE）；打印 warning。战斗可继续，不崩溃。
- **如果 `to_phase` 在 BossData.phases 中不存在**: 数据资产加载时验证所有 PhaseData 的 `phase_index` 连续且 ≥ 0；非法引用在加载时 error，运行时不处理此场景。

## Dependencies

| 系统 | 方向 | 依赖性质 | 接口 |
|------|------|----------|------|
| 格挡/预警系统 | 本系统 → 格挡系统（触发） | 硬依赖——本系统通过此接口将 Boss 攻击意图传递给格挡系统；无此信号格挡机制无法激活 | `attack_telegraphed(type: AttackType, damage: float)` 信号 |
| 格挡/预警系统 | 格挡系统 → 本系统（控制） | 硬依赖——`parry_succeeded` 驱动 STAGGERED 进入；`stagger_ended` 驱动退出。缺少任一信号，格挡反馈循环断裂 | `parry_succeeded(attack_type)` → STAGGERED；`stagger_ended` → IDLE |
| 格挡/预警系统 | 格挡系统 → 本系统（通知） | 软依赖——`parry_failed` 仅触发可选命中反应层动画，不影响状态机核心逻辑 | `parry_failed(attack_type)` → 可选动画叠加 |
| 伤害/生命系统 | 伤害/生命系统 → 本系统（控制） | 硬依赖——HP 阈值越过时伤害系统发出 `boss_phase_changed`，驱动 Boss 行为演化。缺少此信号 Boss 永远停留在第一阶段 | `boss_phase_changed(from_phase: int, to_phase: int)` → PHASE_TRANSITION |
| 伤害/生命系统 | 伤害/生命系统 → 本系统（控制） | 硬依赖——Boss 死亡后立即停止所有行为；DEFEATED 是 TERMINAL 状态 | `boss_defeated` → DEFEATED（立即，任何状态） |
| Boss 数据资产（BossData Resource） | 本系统 → 数据资产（读取） | 硬依赖——攻击序列、阶段定义、idle 时长全部来自数据资产；无数据资产状态机无法初始化 | 加载时读取 BossData → PhaseData[] → AttackData[] |
| 叙事解锁系统 | 无直接依赖 | 无——叙事系统直接订阅伤害/生命系统的 `boss_defeated`，无需本系统中转 | — |
| HUD 系统 | 无直接依赖 | 无——HUD 订阅伤害/生命系统的 `boss_phase_changed`；格挡窗口数据来自格挡/预警系统的 `telegraph_updated` | — |

**双向一致性备注**：
- 格挡/预警系统 GDD 已在 Dependencies 章节将本系统列为 `attack_telegraphed` 的来源方 ✅
- 格挡/预警系统 GDD 已将 `stagger_ended` 和 `parry_failed` 的目标方标注为 Boss 状态机 ✅
- 伤害/生命系统 GDD 已在 Interactions 章节将本系统列为 `boss_phase_changed` / `boss_defeated` 的订阅方 ✅

## Tuning Knobs

| 参数 | 归属 | 基准值 | 安全范围 | 增大效果 | 减小效果 |
|------|------|--------|----------|----------|----------|
| `idle_duration_after_attack` | PhaseData（每阶段独立） | 0.5s | 0.1–2.0s | 节奏放慢，玩家有更多喘息时间；Boss 感觉"庄重" | 节奏加速，攻击更连贯；低于 0.1s 触发加载断言 |
| `attack_sequence` 长度（N） | PhaseData（每阶段独立） | 3–5 个攻击 | 2–8 | 循环周期更长，玩家需要更多轮才能熟悉攻击模式 | 循环更快，玩家可能两次死亡内即掌握节奏；N=1 合法但无节奏多样性 |
| `telegraph_duration_override` | AttackData（每攻击独立） | 0.0（使用全局默认） | 0.3–3.0s（若非 0） | 该攻击比全局基准更慢，给玩家更多准备时间 | 该攻击比全局基准更快，强迫提前反应；< 0.1s 触发 clamp |
| Boss 阶段数量 | BossData | 2 | 1–4 | 战斗更有层次，学习曲线延长 | 1 阶段缺少戏剧性转折；超过 4 阶段节奏密度过高 |
| 阶段 HP 阈值（phase_threshold_pct） | BossData（伤害/生命系统管理） | Phase 2: 50% HP | 10%–80% | 第二阶段出现更早，初见玩家有更多挫败感 | 第二阶段出现更晚；< 10% 几乎无战略意义 |

**旋钮交互警告：**
- `idle_duration_after_attack` 与 `telegraph_duration` 共同决定 `T_cycle`（公式 3）——同时减小两者会导致攻击序列极度密集，玩家无法建立读取节奏。
- 序列长度（N）与 `T_cycle` 正相关——高 N 配合短 `idle_duration` 仍可实现快节奏，低 N 配合长 `idle_duration` 创造慢节奏 Boss。
- Boss 阶段数量超过 3 时，建议每阶段至少引入 1 个新 AttackType 或覆盖值，否则多阶段丧失区分意义。

## Visual/Audio Requirements

> *lean 模式：基于现有艺术圣经和格挡/预警 GDD 视觉规范起草；art-director 未咨询，生产前应补充审查。*

### 每状态视觉需求

| 状态 | 进入时 | 持续中 | 备注 |
|------|--------|--------|------|
| **IDLE** | 播放待机动画（无特效）| Boss 循环待机姿态；无预警发光 | 视觉上明确"Boss 还没准备好攻击" |
| **TELEGRAPHING** | 攻击部位开始发光（暗红，随 `telegraph_progress` 增亮）| 发光颜色/亮度跟随预警进度；WINDOW_OPEN 时转橙白脉冲 | 完整颜色规范见格挡/预警系统 GDD Visual/Audio 章节 |
| **ATTACKING** | 发光骤变（蓄力姿态到出击姿态）| 播放出击动画；可叠加命中反应层（`parry_failed` 触发）| 攻击动画时长由动画资产决定，状态机不硬编码 |
| **STAGGERED** | 发光骤灭；Boss 后退/抖动（hitpause 60ms）| Boss 硬直动画持续；发光变冷灰/白（区别于攻击时橙红）| 视觉需清晰表达"现在可以反击"；规范见格挡/预警 GDD |
| **PHASE_TRANSITION** | 播放 `PhaseData.phase_transition_anim`（每 Boss 专属）| 全屏或局部过渡特效（Boss 专属设计，由艺术圣经定义风格）| 过渡动画期间不发新 `attack_telegraphed` |
| **DEFEATED** | 播放击败动画（Boss 专属）| TERMINAL 状态持续至关卡结束 | 触发叙事解锁 UI（由叙事解锁系统驱动） |

### 音频事件

| 事件 | 音频效果 | 优先级 |
|------|---------|--------|
| **TELEGRAPHING 开始** | Boss 专属蓄力音效（低沉，随预警进度升调）| 必须 |
| **STAGGERED 进入** | 短暂静默（30ms）→ Boss 受击喘息声（区别于普通受击）| 必须（与格挡/预警 GDD 规范一致） |
| **PHASE_TRANSITION** | Boss 专属阶段转换配乐变化（音乐层切换）| 必须 |
| **DEFEATED** | Boss 击败主题曲（每 Boss 独立）| 必须 |

> **📌 Asset Spec** — 视觉/音频需求已定义。艺术圣经批准后，运行 `/asset-spec system:boss-state-machine` 生成各状态动画、过渡特效的资产规格。

## UI Requirements

| 信息 | 显示位置 | 更新来源 | 触发条件 |
|------|----------|---------|---------|
| Boss 血条分阶段标记 | Boss 血条上（待 UX spec 定义位置）| 伤害/生命系统的 `boss_phase_changed` 信号 | 战斗开始时渲染，HP 阈值处显示阶段标记线 |
| 当前阶段视觉标识（可选）| Boss 名称旁（待 UX spec 定义）| `boss_phase_changed` 信号 | 阶段转换时更新 |

> Boss 状态机本身不直接驱动 HUD——HUD 订阅伤害/生命系统的信号。本节仅列出因本系统存在而需要的 UI 呈现需求。

> **📌 UX Flag — Boss 状态机系统**：本系统有 UI 需求（Boss 血条阶段标记）。Pre-Production 阶段运行 `/ux-design` 创建 Boss 血条 UX 规格，在编写 HUD 系统相关 Stories 之前完成。

## Acceptance Criteria

> **故事类型**: Logic（状态机 + 公式 + 信号路由）。全部 AC 须有 `tests/unit/boss_state_machine/` 下通过的自动化单元测试，这是 Done 的硬性门槛。  
> *注: AC-04/AC-16 中"攻击动画结束"的具体触发机制（AnimationPlayer 信号 vs 内部计时器）需在 `/create-architecture` ADR 中确认后才能写稳定测试——当前 AC 描述行为意图。*

**状态转换 — 主干路径**

- [ ] **AC-01** GIVEN 系统处于 IDLE 状态且 BossData 已正确注入（PhaseData[0].attack_sequence 非空），WHEN idle_timer 耗尽，THEN 发出 `attack_telegraphed(sequence[0].attack_type, sequence[0].damage)` 信号，系统进入 TELEGRAPHING 状态。
- [ ] **AC-02** GIVEN 系统 TELEGRAPHING，WHEN 收到 `parry_succeeded(attack_type)`，THEN 进入 STAGGERED；之后 N 秒内不再发出 `attack_telegraphed`（timer 已取消的间接验证）。
- [ ] **AC-03** GIVEN 系统 TELEGRAPHING 且无格挡输入，WHEN telegraph_timer 耗尽，THEN 进入 ATTACKING 状态。
- [ ] **AC-04** GIVEN 系统 ATTACKING，WHEN 攻击动画播放完成（具体触发机制待 ADR 确认），THEN `sequence_index = (current_index + 1) mod N`；系统进入 IDLE 状态。
- [ ] **AC-05** GIVEN 系统 STAGGERED，WHEN 收到 `stagger_ended`，THEN `sequence_index = (current_index + 1) mod N`；系统进入 IDLE 状态。
- [ ] **AC-06** GIVEN 系统任意状态，WHEN 收到 `boss_defeated`，THEN 立即进入 DEFEATED；之后 3 秒内不发出 `attack_telegraphed`（间接验证所有计时器已停）。

**序列索引公式（公式 1）**

- [ ] **AC-07** GIVEN 序列长度 N=3，sequence_index=2（末尾），WHEN ATTACKING 动画结束，THEN sequence_index 推进后 = 0（循环回头）；下次 idle_timer 耗尽时取 sequence[0]。
- [ ] **AC-08** GIVEN 序列长度 N=3，sequence_index=2（末尾），WHEN 收到 `stagger_ended`，THEN sequence_index 推进后 = 0（STAGGERED 退出也触发循环）。
- [ ] **AC-09** GIVEN 系统初始化，WHEN 进入 IDLE 状态，THEN sequence_index = 0（初始状态显式验证）。

**有效预警时长公式（公式 2）**

- [ ] **AC-10** GIVEN AttackData.telegraph_duration_override = 0.6（attack_type=LIGHT），WHEN 该攻击被选中进入 TELEGRAPHING，THEN telegraph_timer 初始值 = 0.6s（非 LIGHT 默认 0.8s）。
- [ ] **AC-11** GIVEN AttackData.telegraph_duration_override = 0，attack_type=HEAVY，WHEN 该攻击被选中，THEN telegraph_timer 初始值 = 1.2s（T_default[HEAVY]）。

**信号接口 — 发出顺序与内容**

- [ ] **AC-12** GIVEN 系统 IDLE，idle_timer 耗尽，WHEN 攻击被选中，THEN 先发出 `attack_telegraphed` 信号，然后 telegraph_timer 启动（信号发出早于计时器启动，防止格挡系统错过信号）。
- [ ] **AC-13** GIVEN 系统 ATTACKING，WHEN 收到 `parry_failed(attack_type)`，THEN 状态保持 ATTACKING；不发出任何状态转换信号（parry_failed 仅触发可选动画叠加，不影响状态机）。

**阶段转换 — 四条触发路径**

- [ ] **AC-14** GIVEN 系统 IDLE，WHEN 收到 `boss_phase_changed(1, 2)`，THEN 立即进入 PHASE_TRANSITION；PHASE_TRANSITION 完成后 PhaseData 更新为 phase[2]、sequence_index=0、进入 IDLE。
- [ ] **AC-15** GIVEN 系统 TELEGRAPHING，WHEN 收到 `boss_phase_changed(1, 2)`，telegraph 继续计时，THEN telegraph 耗尽后（或被格挡后完成 STAGGERED），立即进入 PHASE_TRANSITION（跳过 idle 计时）；PHASE_TRANSITION 完成后 PhaseData=phase[2]、sequence_index=0。
- [ ] **AC-16** GIVEN 系统 ATTACKING（动画播放中），WHEN 收到 `boss_phase_changed(1, 2)`，THEN 等待攻击动画完成（sequence_index++ 正常执行）后立即进入 PHASE_TRANSITION（跳过 idle 计时）；PHASE_TRANSITION 完成后 PhaseData=phase[2]、sequence_index=0。
- [ ] **AC-17** GIVEN 系统 STAGGERED，WHEN 收到 `boss_phase_changed(1, 2)`，THEN 等待 `stagger_ended`（stagger 正常结束，sequence_index++ 执行）后立即进入 PHASE_TRANSITION（跳过 idle 计时）；PHASE_TRANSITION 完成后 PhaseData=phase[2]、sequence_index=0。
- [ ] **AC-18** GIVEN 系统 PHASE_TRANSITION（动画播放中），WHEN 再次收到 `boss_phase_changed(2, 3)`，THEN 第二个信号被丢弃并输出 warning；当前过渡动画继续完整播放后，进入 phase[3]（最新 to_phase），sequence_index=0。

**降级与数据校验**

- [ ] **AC-19** GIVEN `phase_transition_anim` 指向不存在的动画资产，WHEN 进入 PHASE_TRANSITION，THEN 跳过动画播放，直接完成 PHASE_TRANSITION 逻辑（PhaseData 更新、sequence_index=0、进入 IDLE）；输出 warning；战斗继续不崩溃。
- [ ] **AC-20** GIVEN PhaseData.attack_sequence 为空（N=0），WHEN BossData 资产加载，THEN 输出 error；系统不进入 IDLE（拒绝初始化）；boss 无法开始战斗。
- [ ] **AC-21** GIVEN PhaseData.idle_duration_after_attack = 0.0，WHEN BossData 资产加载，THEN 值被 clamp 至 0.1s；输出 warning。
- [ ] **AC-22** GIVEN AttackData.telegraph_duration_override = 0.005（亚帧），WHEN 攻击被选中进入 TELEGRAPHING，THEN telegraph_timer 初始值 = 0.1s（clamp 后）；输出 warning。

**同帧优先级**

- [ ] **AC-23** GIVEN 系统 STAGGERED，WHEN 同帧收到 `stagger_ended` 和 `boss_defeated`，THEN 系统进入 DEFEATED（boss_defeated 优先）；不进入 IDLE；sequence_index 不推进。
- [ ] **AC-24** GIVEN 系统 DEFEATED，WHEN 接收 `stagger_ended`、`parry_succeeded`、`boss_phase_changed`、`parry_failed` 任意信号，THEN 所有信号被忽略；状态保持 DEFEATED；不发出 `attack_telegraphed`。

> **代码审查 AC（Code Review Gate，非 GUT 测试）**: Boss 状态机核心逻辑 .gd 文件中不应出现 `0.8`、`1.2`、`1.5` 等 AttackType 默认时长字面量；所有时长值通过 BossData Resource 注入。在 `/code-review` 阶段由 lead-programmer 验证。

## Open Questions

| 问题 | 负责人 | 解决时机 | 状态 |
|------|--------|----------|------|
| "攻击动画结束"的触发机制：AnimationPlayer.animation_finished 信号 vs 内部计时器？AC-04/AC-16 的测试稳定性依赖此决定 | 架构 ADR | /create-architecture | 待定 |
| 信号路由架构：EventBus 全局单例 vs 节点直连引用？影响 Boss 状态机与格挡/预警系统的解耦方式 | 架构 ADR | /create-architecture | 待定 |
| BossData Resource 实现为 Godot Resource 子类 vs JSON 文件？Resource 子类提供类型安全；JSON 更易外部工具编辑 | 架构 ADR | /create-architecture | 待定 |
| Boss 工厂模式：单一状态机实例动态加载 BossData，还是每个 Boss 一个独立场景？影响多 Boss 的内存管理 | 架构 ADR | /create-architecture | 待定 |
| `boss_phase_changed` 的 HP 阈值定义：在 BossData 中定义（本系统引用），还是在伤害/生命 GDD 中统一管理？当前两个 GDD 对此各有隐含但未协调 | 设计协调 | /consistency-check 后 | 待定 |
