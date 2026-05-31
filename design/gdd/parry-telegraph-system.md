# 格挡/预警系统 (Parry & Telegraph System)

> **Status**: Designed (Pending Review)
> **Author**: game-designer + systems-designer
> **Last Updated**: 2026-05-31
> **Implements Pillar**: Pillar 1「读懂才能赢」/ Pillar 2「每个神明都是一首歌」

## Overview

格挡/预警系统是刃响战斗循环的核心仲裁者，承担两个不可分割的职责。**基础设施层**：它定义"预警事件词汇表"（Telegraph Event Vocabulary）——一套标准化信号契约（`attack_telegraphed(type, duration)`），使 Boss 状态机能够广播即将发动的攻击，同时让格挡判断逻辑对 Boss 的具体实现保持完全不透明；无论 Boss 有多少攻击种类或阶段，都必须通过该词汇表才能触发格挡机制，这使本系统成为格挡手感调优的单一控制点。**玩家层**：本系统消费控制器传来的 `parry_input_pressed` 信号，检测按键时机是否落在预警进度的有效窗口内，并据此触发两条路径——格挡成功时发出 `parry_succeeded` 信号开启反击连段窗口，同时通知控制器退出 PARRYING 状态；格挡失败时调用 `apply_damage(PLAYER, amount)` 将穿透伤害传递至伤害/生命系统。系统不决定 Boss 打什么，只判断"攻击即将到来"与"玩家是否及时响应"之间的关系。信号路由的具体架构（EventBus 全局总线 vs. 节点直连引用）将在 `/create-architecture` 阶段定义为 ADR。

## Player Fantasy

格挡的幻想分两个阶段，共同构成刃响的情感弧线。

**阶段一：读懂（第一次成功格挡）**

Boss 在你死了七次之后，终于出现了某种规律。橙光的形状、光晕扩散的速度、那道亮起来之前身体的微小抖动——它在说话，只是你之前没有听懂。第八次，你听懂了一句。

这一刻不是反应速度的胜利——是理解的到来。满足感不来自手指，来自大脑里某个"对了"的闪念：*这道光意味着这个。我知道了。*

**阶段二：主导（连续完美格挡）**

当读懂变成预期，游戏的感知发生了质变。Boss 的下一个动作在发生之前，答案已经存在。你不再跟着 Boss 的节奏——你开始压着它的节奏走。每次格挡不是响应，是一句宣言：*我知道你要干什么。*

这是 Pillar 1「读懂才能赢」的字面化——格挡成功的唯一条件是理解，不是手速。这是 Pillar 2「每个神明都是一首歌」的具体化——每个 Boss 的预警节奏是一首乐曲，完美格挡是在演奏它，而不仅仅是躲避它。

> **设计保护原则**：原型验证显示，"第一次成功格挡"→"找到节奏连续格挡"→"看到 Boss 硬直"是三个独立的满足节拍。设计不得将其折叠或合并——每个节拍须有对应的视觉/音频反馈强化。

## Detailed Design

### Core Rules

**预警事件词汇表 (Telegraph Event Vocabulary)**

1. Boss 状态机通过发出 `attack_telegraphed(type: AttackType, damage: float)` 信号广播即将发动的攻击。`type` 决定预警时长、格挡窗口和硬直时长；`damage` 是该攻击穿透格挡后对玩家造成的伤害值（由 Boss 数据资产定义，5–40 范围，见伤害/生命 GDD 公式 1）。

2. 三种标准攻击类型（`AttackType` 枚举）及其基准参数：

| 类型 | 枚举值 | 预警时长 | 格挡窗口宽度 | Boss 硬直 | 反击窗口 |
|------|--------|---------|------------|---------|---------|
| 轻攻击 | `LIGHT` | 0.8s | 0.30s | 1.0s | 1.0s |
| 重攻击 | `HEAVY` | 1.2s | 0.35s | 1.5s | 1.5s |
| 横扫 | `SWEEP` | 1.5s | 0.45s | 2.0s | 2.0s |

3. 格挡窗口在预警完成进度的 50% 时开启，持续各自的窗口宽度后关闭（具体公式见 Formulas 章节）。

4. Boss 必须通过 `attack_telegraphed` 信号触发格挡机会。**不可格挡的攻击**（如阶段转换伤害）不发此信号，直接调用 `apply_damage(PLAYER, amount)`——本系统对此类攻击无感知。

**格挡输入判断规则**

5. 本系统消费来自玩家角色控制器的 `parry_input_pressed` 信号，根据当前预警状态分三条路径处理：
   - **路径 A — 窗口内按键**（当前为 TELEGRAPHING 且 WINDOW_OPEN）→ 格挡成功
   - **路径 B — 窗口外按键**（当前为 TELEGRAPHING 但窗口未开或已关）→ 失败格挡动画，窗口机会保留
   - **路径 C — 无预警时按键**（当前为 IDLE）→ 空格挡动画

6. 窗口机会不会被"消耗"。过早按键（路径 B 中窗口未开）触发失败动画，但不锁定本次预警的窗口机会——玩家可等动画结束后（0.4s）再次按键，若此时窗口已开，则成功。（这允许玩家通过"试探性早按"学习节奏。）

7. 每次收到 `parry_input_pressed`，无论路径如何，系统立即向控制器发出 `exit_parry_state(duration: parry_animation_duration)` 信号——控制器在 0.4s 后退出 PARRYING。

**路径 A：格挡成功**

8. 格挡成功时，依序执行：
   - a. 取消当前预警计时（攻击不落地，不调用 `apply_damage`）
   - b. 发出 `parry_succeeded(attack_type)` 信号 → 反击连段系统接收，开启反击窗口并全权管理 Boss 硬直生命周期（stagger_timer 和 stagger_ended 由反击连段系统负责）
   - c. 系统返回 IDLE 状态（本系统不进入 STAGGERING，不维护 stagger_timer）
   - d. 向控制器发出 `exit_parry_state(parry_animation_duration)` 信号
   - e. 触发成功格挡视觉/音频反馈（见 Visual/Audio 章节）

**路径 B：失败格挡**

9. 窗口外按键时：
   - a. 向控制器发出 `exit_parry_state(parry_animation_duration)` 信号（播放失败格挡动画）
   - b. 继续维护当前预警计时
   - c. 预警时长耗尽且无成功格挡 → 攻击落地：调用 `apply_damage(PLAYER, damage)` 并发出 `parry_failed(attack_type)` 信号

**路径 C：空格挡**

10. 无预警时按键：向控制器发出 `exit_parry_state(parry_animation_duration)`，无其他效果。

**Boss 硬直期间**

11. 格挡成功后（路径 A），本系统返回 IDLE 并不再参与硬直管理：
    - Boss 状态机收到 `parry_succeeded` 后进入 STAGGERED（Boss 状态机 GDD 负责实现具体动画）
    - **stagger_timer 和 stagger_ended 的所有权已转移至反击连段系统**——反击连段系统在基础反击窗口（= stagger_duration[attack_type]）和可能的全连击奖励时长到期后发出 `stagger_ended`
    - 本系统不维护 stagger_timer，不发出 stagger_ended

    > *架构变更说明（反击连段系统 GDD v1.0）：stagger_ended 的发出职责已从本系统转移至反击连段系统，以支持"全连击奖励延长硬直"设计。*

---

### States and Transitions

| 状态 | 进入条件 | 退出条件 | 行为 |
|------|----------|----------|------|
| **IDLE** | 初始状态 / 攻击落地处理完成 / 格挡成功（路径 A）后立即返回 | 接收 `attack_telegraphed` → TELEGRAPHING | 等待 Boss 预警；接受空格挡输入（路径 C）；Boss 处于 STAGGERED 期间不会发送 `attack_telegraphed`，故本系统在此期间保持 IDLE |
| **TELEGRAPHING** | 接收 `attack_telegraphed` | 窗口内 `parry_input_pressed` → IDLE（格挡成功）；telegraph 耗尽且无成功格挡 → IDLE（攻击落地后） | 计时 `telegraph_timer`；跟踪 PRE_WINDOW / WINDOW_OPEN / POST_WINDOW 阶段；向 HUD 广播进度 |

> *STAGGERING 状态已移除（反击连段系统 GDD 架构变更）：格挡成功后本系统直接返回 IDLE，stagger 生命周期由反击连段系统全权管理。*

**预警内部阶段（TELEGRAPHING 子状态，不作为独立状态）：**

| 阶段 | 条件 | 格挡输入响应 |
|------|------|------------|
| PRE_WINDOW | `telegraph_timer < window_open_time` | 路径 B（失败动画，窗口保留） |
| WINDOW_OPEN | `window_open_time ≤ telegraph_timer ≤ window_close_time` | 路径 A（格挡成功） |
| POST_WINDOW | `telegraph_timer > window_close_time` | 路径 B（失败动画，已无法成功） |

---

### Interactions with Other Systems

| 系统 | 方向 | 接口 |
|------|------|------|
| Boss 状态机 | → 本系统（触发） | `attack_telegraphed(type: AttackType, damage: float)` — 广播即将到来的攻击 |
| 玩家角色控制器 | → 本系统（触发） | `parry_input_pressed` — 玩家按下格挡键 |
| 玩家角色控制器 | ← 本系统（控制） | `exit_parry_state(duration: float)` — 通知控制器在 duration 后退出 PARRYING 状态 |
| 反击连段系统 | ← 本系统（触发） | `parry_succeeded(attack_type: AttackType)` — 格挡成功；反击连段系统接收后管理 stagger 生命周期并最终发出 stagger_ended |
| 伤害/生命系统 | ← 本系统（调用） | `apply_damage(PLAYER, damage: float)` — 格挡失败时转发攻击伤害 |
| Boss 状态机 | ← 本系统（通知） | `parry_failed(attack_type)` — 格挡失败（Boss 可播放命中反应动画） |
| HUD 系统 | ← 本系统（流数据） | `telegraph_updated(progress: float, window_open: bool, attack_type: AttackType)` — 每物理帧广播预警进度供 HUD 可视化 |

## Formulas

### 公式 1：格挡窗口时机 (Telegraph Window Timing)

```
window_open_time  = telegraph_duration × window_open_fraction
window_close_time = window_open_time + window_width
```

**变量表：**

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 预警时长 | `telegraph_duration` | float | 0.8–5.0s | 攻击类型的完整预警时长（LIGHT=0.8s, HEAVY=1.2s, SWEEP=1.5s；Boss 数据资产可覆盖） |
| 窗口开启分数 | `window_open_fraction` | float | 0.0–1.0 | 窗口开启位置占预警时长的比例；基准值 **0.50**（原型验证）；Boss 数据资产可覆盖 |
| 格挡窗口宽度 | `window_width` | float | 0.1–(telegraph_duration×(1.0−window_open_fraction)) | 有效格挡窗口绝对时长；必须满足 window_close_time ≤ telegraph_duration |
| 窗口开启时刻 | `window_open_time` | float | 0.0–telegraph_duration | 窗口相对于预警起点的开启时刻（秒） |
| 窗口关闭时刻 | `window_close_time` | float | window_open_time–telegraph_duration | 窗口关闭时刻（秒） |

**完整参数表（三类型基准值）：**

| 类型 | `telegraph_duration` | `window_open_fraction` | `window_width` | `window_open_time` | `window_close_time` | 后置死区 |
|------|---------------------|----------------------|--------------|-------------------|---------------------|--------|
| LIGHT | 0.8s | 0.50 | 0.30s | 0.40s | 0.70s | 0.10s |
| HEAVY | 1.2s | 0.50 | 0.35s | 0.60s | 0.95s | 0.25s |
| SWEEP | 1.5s | 0.50 | 0.45s | 0.75s | 1.20s | 0.30s |

**Output Range**: `window_open_time` 和 `window_close_time` 均在 [0.0, telegraph_duration] 内。若 Boss 数据资产覆盖导致 `window_close_time > telegraph_duration`，系统应在加载时 assert 并 clamp，不得静默接受无效配置。

**示例（HEAVY）：** `window_open_time = 1.2 × 0.50 = 0.60s`；`window_close_time = 0.60 + 0.35 = 0.95s`

---

### 公式 2：预警进度与窗口阶段 (Telegraph Progress & Window Phase)

```
telegraph_progress = telegraph_timer / telegraph_duration

window_phase =
    PRE_WINDOW   if telegraph_timer < window_open_time
    WINDOW_OPEN  if window_open_time ≤ telegraph_timer ≤ window_close_time
    POST_WINDOW  if telegraph_timer > window_close_time
```

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 已过预警时间 | `telegraph_timer` | float | 0.0–telegraph_duration | 预警开始后每帧累加 delta 的计时器 |
| 预警时长 | `telegraph_duration` | float | 0.8–5.0s | 同公式 1 |
| 预警完成进度 | `telegraph_progress` | float | 0.0–1.0 | HUD 进度条使用；0=预警开始，1.0=攻击落地 |
| 窗口阶段 | `window_phase` | enum | {PRE_WINDOW, WINDOW_OPEN, POST_WINDOW} | 驱动 HUD 颜色切换和输入路径路由 |

**Output Range**: `telegraph_progress` 严格在 [0.0, 1.0]；`telegraph_timer` 达到 `telegraph_duration` 时系统转为攻击落地处理，计时器不再累加。

**示例（HEAVY, t=0.72s）:** `progress = 0.72/1.2 = 0.60`；`window_phase = WINDOW_OPEN`（0.60≥0.60s 且 0.72≤0.95s）

---

### 公式 3：格挡成功判定 (Parry Success Validation)

```
parry_success = (system_state == TELEGRAPHING)
             AND (telegraph_timer >= window_open_time)
             AND (telegraph_timer <= window_close_time)
```

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 系统主状态 | `system_state` | enum | {IDLE, TELEGRAPHING} | 格挡系统当前状态（STAGGERING 已移除——硬直生命周期由反击连段系统管理） |
| 已过预警时间 | `telegraph_timer` | float | 0.0–telegraph_duration | 同公式 2 |
| 窗口开启时刻 | `window_open_time` | float | 0.0–telegraph_duration | 由公式 1 计算 |
| 窗口关闭时刻 | `window_close_time` | float | window_open_time–telegraph_duration | 由公式 1 计算 |
| 格挡成功 | `parry_success` | bool | {true, false} | true → 路径 A（成功）；false → 路径 B 或 C |

**Output Range**: 布尔值。边界：`>=` 和 `<=` 均为闭区间——恰好在 `window_open_time` 或 `window_close_time` 时刻按键均算成功。

**示例（HEAVY, t=0.60s 边界按键）:** system_state=TELEGRAPHING ✓；0.60≥0.60 ✓；0.60≤0.95 ✓ → `parry_success = true`

---

### 公式 4：硬直时长查表 (Stagger Duration Lookup)

步进函数——每种攻击类型的硬直是独立设计的"奖励单元"，不存在连续公式。

```
stagger_duration = stagger_table[attack_type]

stagger_table（基准值，Boss 数据资产可按攻击类型覆盖）:
    LIGHT  → 1.0s
    HEAVY  → 1.5s
    SWEEP  → 2.0s
```

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 攻击类型 | `attack_type` | enum | {LIGHT, HEAVY, SWEEP} | 触发成功格挡的攻击类型 |
| 硬直时长 | `stagger_duration` | float | 0.5–5.0s（超出建议范围需人工审批） | Boss 硬直持续时长，同步作为反击连段系统的反击窗口时长 |

**Output Range**: 离散三个基准值（1.0 / 1.5 / 2.0s）。Boss 数据资产可按类型覆盖；加载时应对覆盖值进行范围检查（0.5–5.0s），超出范围 clamp 并记录 warning。

**反击时长与硬直同步设计意图**：格挡重攻击比格挡轻攻击获得更长的反击窗口——"承担更高风险、获得更大回报"的设计奖励机制，鼓励玩家学习识别攻击类型。

**示例（SWEEP 格挡成功）:** `stagger_duration = 2.0s`；反击连段系统同步收到 2.0s 反击窗口。

## Edge Cases

- **如果 Boss 在预警进行中发出第二个 `attack_telegraphed` 信号（重叠攻击）**：第二个信号被拒绝并记录 warning；当前预警继续完整计时。Boss 状态机设计时必须保证在本系统处于 TELEGRAPHING 期间或 Boss 处于 STAGGERED 期间（由反击连段系统管理）不发出新的预警信号（Boss 状态机 GDD 的职责）。
- **如果玩家在 Boss STAGGERED 期间（反击窗口内）按下 parry**：触发路径 C（空格挡），向控制器发出 `exit_parry_state(parry_animation_duration)`，无其他效果——Boss STAGGERED 期间不存在格挡机会，不打断反击连段计时。
- **如果 `attack_telegraphed` 信号携带 `damage = 0`（无伤害攻击）**：格挡失败时调用 `apply_damage(PLAYER, 0)`——伤害/生命 GDD 规定 0 伤害调用被完全忽略（不消耗无敌帧，不触发信号）。此类攻击仍可被格挡触发 Boss 硬直，保留格挡学习价值。
- **如果窗口几乎延伸至攻击落地（`window_close_time ≈ telegraph_duration`）**：系统在同一帧检测到 `telegraph_timer >= telegraph_duration` 时，应先完成当帧 `parry_input_pressed` 判断，再处理攻击落地——优先允许最后时刻的格挡，避免"边界帧"判定对玩家不利。
- **如果玩家在 PARRYING 状态（0.4s 格挡动画进行中）再次按下 parry**：控制器在 PARRYING 期间不重新处理 parry 输入，不重新发出 `parry_input_pressed`——本系统不会收到重复信号（边界在控制器，不在本系统）。
- **如果玩家死亡（`player_died` 信号）在预警计时进行中**：本系统立即重置至 IDLE 状态，清除当前预警计时器——不调用 `apply_damage`（即时重试系统接管）。
- **如果 Boss 被击败（`boss_defeated` 信号）在预警计时进行中**：本系统立即重置至 IDLE，取消进行中的预警。Boss 已死，不落地伤害。
- **如果 `telegraph_timer` 因帧率波动在同帧越过 `window_open_time` 和 `window_close_time`**：单帧内 `window_phase` 仍计算为 WINDOW_OPEN（闭区间条件满足）。窗口宽度下限 0.10s（6 帧 @60fps）的调校旋钮约束防止窗口缩短到单帧以下。

## Dependencies

| 系统 | 方向 | 依赖性质 | 接口 |
|------|------|----------|------|
| 玩家角色控制系统 | 本系统依赖 | 硬依赖——本系统消费 `parry_input_pressed` 信号，控制器依赖本系统的 `exit_parry_state` 信号退出 PARRYING 状态 | `parry_input_pressed` ← 控制器；`exit_parry_state(duration)` → 控制器 |
| 伤害/生命系统 | 本系统依赖 | 硬依赖——格挡失败时调用 `apply_damage(PLAYER, damage)` | 函数调用（单向） |
| Boss 状态机系统 | Boss 状态机依赖本系统 | 硬依赖——Boss 状态机通过本 GDD 定义的词汇表发出 `attack_telegraphed`；订阅本系统的 `parry_failed` 信号。注：`stagger_ended` 已改由反击连段系统发出 | `attack_telegraphed` ← Boss 状态机；`parry_failed` → Boss 状态机 |
| 反击连段系统 | 反击连段系统依赖本系统 | 硬依赖——格挡成功后发出 `parry_succeeded(attack_type)` 开启反击窗口 | `parry_succeeded(attack_type)` → 反击连段系统 |
| HUD 系统 | HUD 系统依赖本系统 | 软依赖——HUD 订阅 `telegraph_updated` 流数据做可视化；无 HUD 系统格挡判断仍正常运行 | `telegraph_updated(progress, window_open, attack_type)` → HUD |
| 音频系统 | 音频系统依赖本系统 | 软依赖——音频系统订阅格挡成功/失败事件；无音频系统核心逻辑不受影响 | 音频事件名（待音频系统 GDD 定义后更新） |

**双向一致性备注**：
- 玩家角色控制系统 GDD 已列本系统为依赖项（`parry_input_pressed` 信号消费者）✅
- 伤害/生命系统 GDD 已将格挡/预警系统列为调用 `apply_damage` 的来源方 ✅
- Boss 状态机系统 GDD 已创建（✅），Dependencies 章节已引用本 GDD 预警事件词汇表 ✅
- 反击连段系统 GDD 已创建（✅），已将 `stagger_ended` 发出职责接管，本系统的相关说明已更新 ✅

## Tuning Knobs

| 参数 | 基准值 | 安全范围 | 增大效果 | 减小效果 |
|------|--------|----------|----------|----------|
| `telegraph_duration_light` | 0.8s | 0.5–1.5s | 玩家观察时间更长，更容易读取预警 | 更快，接近即时，需要提前反应 |
| `telegraph_duration_heavy` | 1.2s | 0.8–2.0s | 更长的紧张期；重攻击感觉更"庄重" | 减少读取时间 |
| `telegraph_duration_sweep` | 1.5s | 1.0–2.5s | 横扫攻击更具威慑感；动作更"史诗" | 减少读取时间，横扫难度提升 |
| `window_open_fraction` | 0.50 | 0.30–0.70 | 窗口更早开启，玩家可提前格挡 | 窗口更晚开启，必须等待视觉高峰 |
| `window_width_light` | 0.30s | 0.10–0.50s | 更宽容（新手友好） | 更严苛；低于 0.10s 接近手速测试，破坏设计意图 |
| `window_width_heavy` | 0.35s | 0.15–0.55s | 同上 | 同上 |
| `window_width_sweep` | 0.45s | 0.20–0.60s | 同上 | 同上 |
| `parry_animation_duration` | 0.4s | 0.2–0.6s | 失败格挡惩罚更长（更难在同一预警中补救） | 惩罚更短，玩家可快速重试 |
| `stagger_duration_light` | 1.0s | 0.5–2.0s | 更长的反击窗口，更多输出机会 | 更短，仅够 1 击 |
| `stagger_duration_heavy` | 1.5s | 0.8–3.0s | 同上 | 同上 |
| `stagger_duration_sweep` | 2.0s | 1.0–4.0s | 最高奖励，满连段可达 | 减少 SWEEP 格挡的战略价值 |

**旋钮交互警告：**
- `window_width` 与 `parry_animation_duration` 强关联：若 `window_width < parry_animation_duration`，玩家过早按键后动画还没播完窗口就已关闭，无法补救。设计上建议 `window_width ≥ parry_animation_duration × 0.75`。
- 三个攻击类型的 `stagger_duration` 须保持 LIGHT < HEAVY < SWEEP 的顺序；违反顺序会破坏"格挡重攻击奖励更大"的动机设计。
- 不要跨 Boss 将所有攻击类型都设为同一 `window_width`——这会消除难度层次，使三种类型无法区分。

## Visual/Audio Requirements

> *参见艺术圣经 Section 7（视觉预警设计原则）："攻击预警即艺术——发光、光晕、身体语言既是机制，也是美学。如果预警效果不好看，就重新设计，直到它既清晰又美。"*

### 视觉反馈

| 事件 / 阶段 | 视觉效果 | 优先级 | 备注 |
|------------|---------|--------|------|
| **TELEGRAPHING - PRE_WINDOW** | Boss 攻击部位开始暗红色发光，亮度随 `telegraph_progress` 线性增强；整体色调：深暗红 → 橙红 | 必须 | 原型验证：颜色渐变足以传达预警信息 |
| **TELEGRAPHING - WINDOW_OPEN** | Boss 发光达到高亮橙白色，有规律脉冲（每秒 2 次）；如可能，Boss 动作到达"蓄力顶点"姿态 | 必须 | 橙白色是"现在格挡"的视觉语言——与非窗口期的暗红形成高对比度 |
| **TELEGRAPHING - POST_WINDOW** | 发光转为暗红但维持高亮（视觉上"攻击正在释放"），不得与 WINDOW_OPEN 视觉相同 | 必须 | POST_WINDOW 不能格挡——视觉上需与 WINDOW_OPEN 区分，避免玩家误判 |
| **格挡成功（路径 A）** | 玩家格挡特效（武器/盾牌接触光爆）+ 短暂 hitpause（60ms）+ Boss 硬直视觉（发光骤灭，Boss 身体后退或抖动） | 必须 | hitpause 是"接触感"的核心反馈，不可省略 |
| **Boss STAGGERED 期间（反击连段系统管理）** | Boss 发光变为冷灰/白色（区别于攻击时的橙红）；受击动画持续；玩家可视化反击窗口计时（HUD，见 UI Requirements） | 必须 | 硬直视觉需清晰表达"现在可以反击"，而非"下一次攻击要来了" |
| **格挡失败（路径 B，攻击落地）** | 玩家受击动画（由玩家角色控制系统提供）+ 画面边缘红光（由伤害/生命系统提供）；格挡系统无额外视觉 | 不适用 | 视觉由其他系统提供，本系统不重复触发 |
| **空格挡（路径 C）** | 玩家格挡姿势动画（0.4s），无特效——区别于成功格挡的光爆效果 | 推荐 | 视觉上区分"格挡但无目标"和"格挡成功" |

### 音频反馈

| 事件 | 音频效果 | 优先级 | 备注 |
|------|---------|--------|------|
| **WINDOW_OPEN 开始** | 短促高频提示音（可选）——若过于明显可能成为"听觉替代视觉"的捷径，影响"读懂才能赢"体验 | 设计决策待定 | 建议微弱或不加；垂直切片玩测决定 |
| **格挡成功** | 清脆金属碰撞声（高频主音）+ 低沉共鸣（余韵，100ms）——"啪"感 | 必须 | 这是三个满足节拍中"第一次成功"的音频锚点 |
| **Boss 硬直** | 硬直进入瞬间：短暂静默（30ms）→ Boss 受击喘息声；区别于普通受击音效 | 必须 | 静默短暂停顿增强"我控制了这一刻"的感知 |
| **格挡失败** | 无特殊音效——受击音效由伤害/生命系统提供 | 不适用 | 避免格挡失败有专属音效导致玩家只靠声音判断 |
| **空格挡** | 轻微"空挥"音效（武器滑过空气），区别于成功格挡的金属声 | 推荐 | — |

> **📌 Asset Spec** — Visual/Audio 需求已定义。艺术圣经批准后，运行 `/asset-spec system:parry-telegraph-system` 生成预警发光特效、格挡光爆特效的视觉描述和资产规格。

## UI Requirements

| 信息 | 显示位置 | 更新来源 | 触发条件 |
|------|----------|---------|---------|
| 预警进度指示 | Boss 周围环境光或独立进度条（位置待 UX spec 定义） | `telegraph_updated(progress, window_open, attack_type)` 每帧 | 任何 TELEGRAPHING 状态 |
| 格挡窗口开启状态 | 与预警进度指示联动（颜色变化：暗红 → 橙色） | `telegraph_updated.window_open = true` | PRE_WINDOW → WINDOW_OPEN 切换 |
| Boss 硬直剩余时间（反击窗口） | Boss 血条区域或 Boss 周围光环（待 UX spec 定义） | 反击连段系统 `counter_window_updated` 信号（见反击连段 GDD） | Boss STAGGERED 期间（反击连段系统状态） |
| 攻击类型标识（可选） | 与预警指示联动——HEAVY/SWEEP 可用图标或颜色区分 | `telegraph_updated.attack_type` | TELEGRAPHING 状态 |

> **📌 UX Flag — 格挡/预警系统**：此系统有 UI 需求。在 Pre-Production 阶段运行 `/ux-design` 创建格挡窗口 HUD 的 UX 规格，在编写 HUD 系统相关 Stories 之前完成。注意：格挡窗口可视化是"读懂才能赢"体验的关键辅助——UX spec 须明确是否提供 timing progress bar（原型使用了，帮助学习但可能降低挑战性）。

## Acceptance Criteria

> **故事类型**: Logic（状态机 + 时机公式 + 信号路由）。全部 AC 须有 `tests/unit/parry_system/` 下通过的自动化单元测试，这是 Done 的硬性门槛。

- [ ] **AC-01** GIVEN Boss 状态机准备发动 HEAVY 攻击（damage=25），WHEN 发出 `attack_telegraphed`，THEN 信号携带 `type=HEAVY, damage=25.0`；系统从 IDLE 转为 TELEGRAPHING。
- [ ] **AC-02** GIVEN 系统 IDLE，WHEN 依次接收三种类型各一次 `attack_telegraphed`（每次待落地后重置），THEN LIGHT telegraph=0.8s、HEAVY=1.2s、SWEEP=1.5s；三个值均从 Boss 数据资产读取，不是 .gd 字面量。
- [ ] **AC-03** GIVEN HEAVY 预警进行中，`telegraph_timer=0.72s`（窗口内 0.60–0.95s），WHEN `parry_input_pressed`，THEN 发出 `parry_succeeded(HEAVY)` + `exit_parry_state(parry_animation_duration)`；telegraph 停止；`apply_damage` 不被调用；状态返回 IDLE（本系统不进入 STAGGERING，stagger 生命周期由反击连段系统管理）。
- [ ] **AC-04** GIVEN HEAVY 预警，`telegraph_timer=0.30s`（窗口前），WHEN `parry_input_pressed`，THEN 发出 `exit_parry_state(parry_animation_duration)`；telegraph 继续；动画结束后窗口期内再次按键仍可成功（窗口未被消耗）。
- [ ] **AC-05** GIVEN HEAVY 预警，`telegraph_timer=1.10s`（窗口后），WHEN `parry_input_pressed`，THEN 发出 `exit_parry_state(parry_animation_duration)`；telegraph 计时到 1.2s 时调用 `apply_damage(PLAYER, <damage>)` 并发出 `parry_failed(HEAVY)`。
- [ ] **AC-06** GIVEN 系统 IDLE，WHEN `parry_input_pressed`，THEN 仅发出 `exit_parry_state(parry_animation_duration)`；不发出 `parry_succeeded`；不调用 `apply_damage`；状态保持 IDLE。
- [ ] **AC-07** GIVEN 任意系统状态，WHEN 接收到 `parry_input_pressed`，THEN 同帧发出 `exit_parry_state(duration=parry_animation_duration)`，不论路径 A、B、C。
- [ ] **AC-08** GIVEN 路径 A 格挡成功，WHEN 处理完毕，THEN 事件顺序：① `parry_succeeded(type)` ② `exit_parry_state`；`apply_damage` 调用次数 = 0（Mock/Spy 验证）。
- [ ] **AC-09** GIVEN SWEEP 格挡成功，WHEN 路径 A 处理完毕，THEN 系统状态为 IDLE（不进入 STAGGERING）；已发出 `parry_succeeded(SWEEP)` 和 `exit_parry_state`；`stagger_ended` 不由本系统发出（改由反击连段系统负责）。
- [ ] **AC-10** ~~GIVEN 系统 STAGGERING~~（STAGGERING 状态已移除）。此 AC 废弃。格挡成功后系统直接处于 IDLE；若在 Boss STAGGERED 期间收到 parry_input_pressed，走路径 C（空格挡）。
- [ ] **AC-11** GIVEN LIGHT 预警（damage=10），整个预警期间无成功格挡，WHEN `telegraph_timer` 达到 0.8s，THEN 调用 `apply_damage(PLAYER, 10.0)`；发出 `parry_failed(LIGHT)`；状态返回 IDLE。
- [ ] **AC-12** GIVEN 从数据资产加载三种类型，WHEN 各类型预警开始计算窗口，THEN LIGHT: open=0.40s, close=0.70s；HEAVY: open=0.60s, close=0.95s；SWEEP: open=0.75s, close=1.20s（允差 ±0.001s）。
- [ ] **AC-13** GIVEN 系统 TELEGRAPHING，WHEN 每物理帧 `_physics_process(delta)` 运行，THEN `telegraph_updated` 的 `progress = telegraph_timer / telegraph_duration`，严格在 [0.0, 1.0]；`telegraph_timer` 达到上限后不再累加。
- [ ] **AC-14** GIVEN HEAVY 预警，`telegraph_timer` 精确等于 `window_open_time=0.60s`，WHEN `parry_input_pressed`，THEN `parry_success=true`；发出 `parry_succeeded(HEAVY)`（闭区间边界为成功）。
- [ ] **AC-14b** GIVEN HEAVY 预警，`telegraph_timer` 精确等于 `window_close_time=0.95s`，WHEN `parry_input_pressed`，THEN `parry_success=true`；发出 `parry_succeeded(HEAVY)`（闭区间边界为成功）。
- [ ] **AC-15** ~~GIVEN 系统进入 STAGGERING~~（STAGGERING 状态已移除）。新 AC-15：GIVEN LIGHT/HEAVY/SWEEP 各触发一次成功格挡，WHEN `parry_succeeded` 信号发出，THEN 信号 payload 携带正确的 `attack_type`（LIGHT/HEAVY/SWEEP）；反击连段系统据此查表使用对应的 `base_counter_window`（1.0/1.5/2.0s），由反击连段系统单元测试覆盖 `base_counter_window` 数值，本系统仅验证 attack_type 传递正确性。
- [ ] **AC-16** GIVEN 系统 TELEGRAPHING（第一预警进行中），WHEN Boss 发出第二个 `attack_telegraphed`，THEN 第二个信号被丢弃；现有计时器不变；输出 warning 日志。
- [ ] **AC-17** GIVEN SWEEP 预警 `telegraph_timer=0.50s`，WHEN 接收 `player_died`，THEN 系统立即转 IDLE；`telegraph_timer` 清零；`apply_damage` 不被调用；不发出 `parry_failed`。
- [ ] **AC-18** GIVEN LIGHT 预警 `telegraph_timer=0.20s`，WHEN 接收 `boss_defeated`，THEN 系统立即转 IDLE；`telegraph_timer` 清零；`apply_damage` 不被调用。
- [ ] **AC-19** GIVEN damage=0 的 LIGHT 攻击无成功格挡，WHEN telegraph 耗尽，THEN 系统仍调用 `apply_damage(PLAYER, 0.0)` 一次；发出 `parry_failed(LIGHT)`；状态返回 IDLE。
- [ ] **AC-20** GIVEN 某帧 `telegraph_timer` 将超过 `telegraph_duration` 且同帧有 `parry_input_pressed` 且 timer 在窗口内，WHEN 该帧 `_physics_process` 运行，THEN 格挡判断先执行（路径 A 成功）；`apply_damage` 不被调用。
- [ ] **AC-21** ~~GIVEN 系统 STAGGERING~~（STAGGERING 状态已移除，此 AC 废弃）。Boss 处于 STAGGERED 期间不会发出 attack_telegraphed（由 Boss 状态机保证），本系统无需主动拒绝此信号。
- [ ] **AC-22** GIVEN 系统 TELEGRAPHING，60fps 运行，WHEN 接收 `parry_input_pressed`（路径 A），THEN 从信号到所有输出信号发出完成 ≤ 0.5ms（可通过 GUT 性能测试或 Godot Profiler 验证）。
- [ ] **AC-23** GIVEN 所有格挡系统 .gd 文件，WHEN grep 搜索数值字面量（0.8、1.2、1.5、0.30、0.35、0.45、0.50），THEN 核心逻辑文件中不出现这些字面量；所有值通过 Boss Resource 资产注入。
- [ ] **AC-24** GIVEN 系统从 IDLE 走完路径 A / B / C，WHEN 所有计时器耗尽，THEN 三条路径最终状态均为 IDLE；无任何路径导致系统挂死。

## Open Questions

| 问题 | 负责人 | 解决时机 | 状态 |
|------|--------|----------|------|
| 格挡窗口是否显示 timing progress bar？原型使用了，有教学价值但降低纯视觉挑战难度 | UX spec | Pre-Production UX 设计阶段 | 待定 |
| `telegraph_updated` 信号广播是否每物理帧，还是允许跳帧（性能权衡）？ | 架构 ADR | /create-architecture | 待定 |
| `stagger_ended` 信号是否保证同帧处理？异步情况下的边界帧语义？ | 架构 ADR | /create-architecture | **已转移**：stagger_ended 发出职责已由反击连段系统接管（GDD v1.0），此问题移至反击连段系统 Open Questions |
| WINDOW_OPEN 期间是否提供轻微音频提示音？需垂直切片玩测决定 | 垂直切片玩测 | 垂直切片阶段 | 待定 |
| Boss 数据资产覆盖 `window_open_fraction` 的权限边界？所有 Boss 均可修改，还是仅高级 Boss 阶段？ | Boss 状态机 GDD | 设计 Boss 状态机系统时 | 待定 |
| 格挡动画退出信号（`exit_parry_state`）：`parry_animation_duration` 是否也从 Boss 数据资产读取？当前为全局可调参数 | 架构 ADR | /create-architecture | 待定 |
