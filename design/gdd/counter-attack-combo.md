# 反击连段系统 (Counter Attack Combo System)

> **Status**: Designed (Pending Review)
> **Author**: game-designer + systems-designer
> **Last Updated**: 2026-05-31
> **Implements Pillar**: Pillar 1「读懂才能赢」/ Pillar 2「每个神明都是一首歌」

## Overview

反击连段系统是刃响战斗循环的"奖励输出层"。**基础设施层**：系统订阅格挡/预警系统的 `parry_succeeded(attack_type)` 信号，开启一个时限反击窗口（`base_counter_window`，由攻击类型决定）；玩家在窗口内每次按下攻击键激活一次连击，每次连击调用 `apply_damage(BOSS, amount)` 向伤害/生命系统传递伤害；玩家完成所有预设连击次数（full combo）后，系统发出 `counter_full_combo_completed` 信号，自动追加奖励硬直时间；基础窗口或奖励时长全部耗尽后，系统发出 `stagger_ended`，通知 Boss 状态机恢复行动。**架构说明**：本系统接管格挡/预警系统原有的 `stagger_ended` 发出职责，格挡/预警系统只发出 `parry_succeeded`，由本系统全权管理 Boss 硬直的生命周期（基础时长 + 连段奖励延长）。**玩家层**：玩家感受到的是"成功格挡后的反击机会"——Boss 静止、每次攻击输入都有重量感。格挡重攻击获得更长的窗口，格挡横扫获得最长时间；完整打满连段后 Boss 额外延长硬直，给予"精准完成"的感知奖励。系统不决定 Boss 何时进入硬直或格挡是否成功——它只管"格挡成功后玩家如何反击"。

## Player Fantasy

格挡成功的那一瞬间不是终点——是一扇门打开了。

Boss 静止了。橙色的发光骤灭，它僵在那里，第一次不是主动的。这是你的时刻。不是游戏给你的礼物，是你用正确判断赢来的。

反击的每一击都是宣告。第一击打进去的声音，第二击稍重，如果你打完了整个连段——第三、第四击——Boss 会额外延长硬直，好像在承认：*你打得足够好，我没法站起来了。*

这不是单纯的"输出伤害"的快感。这是一种**节奏上的主导感**：你在一个精确的时间窗口里，完全控制战斗的节拍。Boss 的"歌"在这段时间里是沉默的，而你在填充它。

格挡不同的攻击类型获得不同的窗口长度——格挡横扫获得 2 秒，格挡轻攻击只有 1 秒。玩家学会的不只是"格挡"，还有"识别攻击类型，选择合适的连段节奏"。这让反击不只是反应，还是理解的延伸。

> **设计保护原则**：反击连段的快感来自"我控制了这一刻"，而非"数字快速跳动"。每击应有清晰的打击反馈（音效+Boss 受击动画），节奏不能太快——玩家需要感受到每一击的重量，而不是看着一串数字弹出。

## Detailed Design

### Core Rules

**反击窗口管理**

1. 本系统订阅格挡/预警系统的 `parry_succeeded(attack_type)` 信号，收到后立即进入 COUNTER_WINDOW_OPEN 状态。
2. 进入 COUNTER_WINDOW_OPEN 时，初始化以下状态：
   - `current_hit_count = 0`
   - `max_hits = 3`（固定，不随攻击类型变化）
   - `window_timer = base_counter_window[attack_type]`（与 stagger_duration 基准值等同：LIGHT=1.0s / HEAVY=1.5s / SWEEP=2.0s）
   - `hit_cooldown_active = false`
3. 本系统在 COUNTER_WINDOW_OPEN 或 BONUS_STAGGER 状态结束时发出 `stagger_ended` 信号，通知 Boss 状态机退出 STAGGERED 状态。**本系统是 `stagger_ended` 的唯一发出方**——格挡/预警系统不再维护 stagger_timer。
4. 同一时刻只能有一个 COUNTER_WINDOW_OPEN 状态。若在 COUNTER_WINDOW_OPEN 期间意外收到第二个 `parry_succeeded`，丢弃第二个信号并记录 warning。

**连击输入处理**

5. COUNTER_WINDOW_OPEN 状态下，玩家按下攻击键（`attack_input_pressed`）：
   - a. 若 `current_hit_count >= max_hits`：忽略输入（全连击已完成）
   - b. 若 `hit_cooldown_active = true`：忽略输入（前一击动画未结束）
   - c. 否则：执行一次连击：
      - `current_hit_count++`
      - 调用 `apply_damage(BOSS, hit_damage[current_hit_count])`
      - 播放第 `current_hit_count` 击攻击动画
      - 设置 `hit_cooldown_active = true`，计时 `hit_animation_duration`
      - `hit_animation_duration` 结束后 `hit_cooldown_active = false`
6. `hit_damage[current_hit_count]` 是按击数查表的离散值（见 Formulas 章节），设计上递增。

**全连击完成**

7. 当 `current_hit_count` 达到 `max_hits`（即 3）时，触发全连击完成：
   - a. 发出 `counter_full_combo_completed(attack_type)` 信号（HUD 等订阅方接收）
   - b. 将 `window_timer` 重设为 `bonus_stagger_duration[attack_type]`（奖励延长时间）
   - c. 系统进入 BONUS_STAGGER 状态（不再接受连击输入，等奖励时长耗尽后发出 stagger_ended）

**窗口到期**

8. 若 `window_timer` 在未完成全连击的情况下耗尽（COUNTER_WINDOW_OPEN 到期）：立即发出 `stagger_ended`；系统回到 IDLE。
9. 若 `window_timer` 在 BONUS_STAGGER 状态耗尽（奖励时长到期）：立即发出 `stagger_ended`；系统回到 IDLE。

---

### States and Transitions

| 状态 | 进入条件 | 退出条件 | 行为 |
|------|----------|----------|------|
| **IDLE** | 初始状态 / `stagger_ended` 发出后 | 收到 `parry_succeeded` → COUNTER_WINDOW_OPEN | 不接受连击输入 |
| **COUNTER_WINDOW_OPEN** | 收到 `parry_succeeded` | window_timer 耗尽 → IDLE（发出 stagger_ended）；current_hit_count=3 → BONUS_STAGGER | window_timer 倒计时；接受攻击输入；每击调用 apply_damage |
| **BONUS_STAGGER** | current_hit_count=3（全连击完成）| window_timer（bonus时长）耗尽 → IDLE（发出 stagger_ended） | 不接受连击输入；播放全连击完成特效；倒计时奖励时长 |

---

### Interactions with Other Systems

| 系统 | 方向 | 接口 |
|------|------|------|
| 格挡/预警系统 | → 本系统（触发） | `parry_succeeded(attack_type)` — 开启反击窗口 |
| 伤害/生命系统 | ← 本系统（调用） | `apply_damage(BOSS, amount)` — 每次连击传递伤害 |
| Boss 状态机 | ← 本系统（控制） | `stagger_ended` — 本系统发出，Boss 退出 STAGGERED |
| HUD 系统 | ← 本系统（流数据） | `counter_window_updated(hit_count, time_remaining, state)` — 每帧广播反击窗口状态供 HUD 可视化 |
| 玩家角色控制器 | → 本系统（触发） | `attack_input_pressed` — 玩家按下攻击键触发连击 |

## Formulas

### 公式 1：单击伤害（Hit Damage）

```
hit_damage(n) = counter_base_damage × multiplier[n]

multiplier 查表：
  hit_number=1 → multiplier=0.8
  hit_number=2 → multiplier=1.1
  hit_number=3 → multiplier=1.6
```

**变量表：**

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 击数 | `n` | int | {1, 2, 3} | 当前连击的击数 |
| 反击基础伤害 | `counter_base_damage` | float | 20 hp（注册表常量） | 伤害基础参照值，由伤害/生命系统 GDD 定义 |
| 击数乘数 | `multiplier[n]` | float | {0.8, 1.1, 1.6} | 每击的伤害倍率；显式配置，随 counter_base_damage 自动缩放 |
| 单击伤害 | `hit_damage(n)` | float | [16, 32] hp | 第 n 击对 Boss 造成的伤害 |

**Output Range**: 离散三值 {16, 22, 32} hp（基于 counter_base_damage=20）；三击总计 70 hp ≈ boss_max_hp_baseline 的 7%（玩家需约 14–15 次完整格挡才能击败 Boss，符合 Boss Rush 节奏）。若 counter_base_damage 全局调整，所有击数伤害自动缩放。

**示例（全连击）**: n=1: 20×0.8=16 hp；n=2: 20×1.1=22 hp；n=3: 20×1.6=32 hp；合计 70 hp。

---

### 公式 2：奖励硬直时长（Bonus Stagger Duration）

```
bonus_stagger_duration[attack_type] = base_counter_window[attack_type] × bonus_ratio
```

| attack_type | base_counter_window | bonus_ratio | bonus_stagger_duration | 全程总硬直（含基础） |
|-------------|---------------------|-------------|------------------------|----------------------|
| LIGHT | 1.0s | 0.5 | **0.5s** | 1.5s |
| HEAVY | 1.5s | 0.5 | **0.75s** | 2.25s |
| SWEEP | 2.0s | 0.5 | **1.0s** | 3.0s |

**变量表：**

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 攻击类型 | `attack_type` | AttackType | {LIGHT, HEAVY, SWEEP} | 被格挡的攻击类型 |
| 基础反击窗口 | `base_counter_window[attack_type]` | float | {1.0, 1.5, 2.0}s | 等同于注册表 stagger_duration 基准值 |
| 奖励比例 | `bonus_ratio` | float | [0.4, 0.8]（安全范围） | 奖励时长占基础窗口的比例；全局单一调参旋钮 |
| 奖励硬直时长 | `bonus_stagger_duration` | float | [0.4, 1.6]s | 全连击后追加的额外 Boss 硬直时长 |

**Output Range**: 总硬直 = base_counter_window × (1 + bonus_ratio)；`bonus_ratio` 上限 0.8（SWEEP 总硬直 3.6s，超出则破坏战斗节奏）。

**示例**: 玩家格挡 SWEEP 并完成 3 击 → 基础窗口 2.0s + 奖励 1.0s = Boss 总计静止 **3.0s**。

---

### 公式 3：每击动画冷却（Hit Animation Duration）

> **可行性约束验证工具**。`hit_animation_duration` 是全局单一配置值，不随攻击类型变化。

**可行性约束**（LIGHT 窗口，最严格场景）：
```
3 × hit_animation_duration + input_response_time ≤ base_counter_window[LIGHT]
3 × 0.25 + 0.08 = 0.83s ≤ 1.0s  ✓  （余量 0.17s ≈ 10 帧 @60fps）
```

**变量表：**

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 每击动画冷却 | `hit_animation_duration` | float | (0, 0.307]s | 每击后屏蔽下次输入的冷却时长；上界由 LIGHT 窗口可行性推导 |
| 输入响应余量 | `input_response_time` | float | 0.08s（保守估算） | 输入检测延迟余量，不可调 |

**推荐值**: `hit_animation_duration = 0.25s`（LIGHT 窗口留 10 帧余量；如动画需要更长打击感，上限 0.30s 仍可行但余量仅 5 帧，需实机验证）。

**三种窗口可行性验证**:

| attack_type | 窗口 | 3×anim + input | 余量 | 状态 |
|-------------|------|----------------|------|------|
| LIGHT | 1.0s | 0.83s | **0.17s** | ✓ 偏紧，需实机调校 |
| HEAVY | 1.5s | 0.83s | **0.67s** | ✓ 充裕 |
| SWEEP | 2.0s | 0.83s | **1.17s** | ✓ 非常充裕 |

## Edge Cases

- **如果玩家在 COUNTER_WINDOW_OPEN 期间不按任何攻击键**: window_timer 自然耗尽，系统发出 `stagger_ended`；Boss 正常恢复行动；零连击是合法结果，系统无需特别处理。
- **如果玩家按键速度快于 `hit_animation_duration`（连按）**: 冷却期内的输入被忽略（`hit_cooldown_active=true`）。玩家最多在 3 × hit_animation_duration + 余量内完成 3 击，不可超速完成。
- **如果玩家仅完成 1 击或 2 击而窗口到期**: window_timer 耗尽，系统发出 `stagger_ended`；部分连击伤害已正常对 Boss 生效；无全连击奖励时长；不触发 `counter_full_combo_completed`。
- **如果在 BONUS_STAGGER 期间玩家尝试继续攻击**: 输入被忽略（`current_hit_count >= max_hits`）。BONUS_STAGGER 不接受连击输入，是视觉呈现全连击特效的时间，不是额外伤害机会。
- **如果 window_timer 在第 3 击的 `hit_cooldown_active` 期间耗尽**: 第 3 击伤害和 `counter_full_combo_completed` 信号已在命中帧发出；系统已进入 BONUS_STAGGER；timer 切换到奖励时长，不受 hit_cooldown 影响。全连击奖励时长从第 3 击命中那一帧开始，不等 cooldown 结束。
- **如果 `boss_defeated` 在 COUNTER_WINDOW_OPEN 或 BONUS_STAGGER 期间发生**: 立即取消所有计时器；状态回到 IDLE；不发出 `stagger_ended`（Boss 已死，无需通知退出 STAGGERED）。
- **如果 `player_died` 在 COUNTER_WINDOW_OPEN 期间发生**: 立即取消所有计时器；状态回到 IDLE；不发出 `stagger_ended`——即时重试系统接管，Boss 状态由重试系统重置。
- **如果 `hit_animation_duration` 调参超过 0.307s（LIGHT 窗口可行性上限）**: 加载时验证 `3 × hit_animation_duration < base_counter_window[LIGHT]`；违反时 clamp 至 0.30s 并记 warning。
- **如果 `bonus_ratio` 调参超过 0.8**: 加载时 clamp 至 0.8 并记 warning（防止 SWEEP 全连击总硬直超过 3.6s 破坏战斗节奏）。

## Dependencies

| 系统 | 方向 | 依赖性质 | 接口 |
|------|------|----------|------|
| 格挡/预警系统 | 格挡系统 → 本系统（触发） | 硬依赖——`parry_succeeded` 是本系统的唯一进入触发点；无此信号永远无法开启反击窗口 | `parry_succeeded(attack_type: AttackType)` |
| 伤害/生命系统 | 本系统 → 伤害/生命（调用） | 硬依赖——每击通过此接口对 Boss 造成伤害 | `apply_damage(BOSS, hit_damage: float)` |
| Boss 状态机 | 本系统 → Boss 状态机（控制） | 硬依赖——本系统发出 `stagger_ended` 控制 Boss 退出 STAGGERED；本系统接管格挡/预警系统原有的 stagger_ended 发出职责 | `stagger_ended` 信号 |
| 玩家角色控制器 | 控制器 → 本系统（触发） | 硬依赖——玩家攻击输入是连击激活的来源 | `attack_input_pressed` 信号 |
| HUD 系统 | HUD → 本系统（订阅） | 软依赖——HUD 订阅本系统的流数据；无 HUD 核心连击逻辑不受影响 | `counter_window_updated(hit_count, time_remaining, state)` 每帧；`counter_full_combo_completed(attack_type)` |

**架构更新说明（对已有 GDD 的影响）**：
- ✅ 格挡/预警系统 GDD 已更新：STAGGERING 状态已移除，stagger_timer 维护和 stagger_ended 发出逻辑全部转移至本系统；该 GDD 现仅发出 `parry_succeeded` 信号（2026-06-01 完成）
- Boss 状态机 GDD 的 `stagger_ended` 信号来源从格挡/预警系统更新为本系统——Boss 状态机仍订阅 `stagger_ended`，依赖方向不变，仅发出方变更 ❗

## Tuning Knobs

| 参数 | 基准值 | 安全范围 | 增大效果 | 减小效果 |
|------|--------|----------|----------|----------|
| `max_hits` | 3 | 2–4 | 连段更长；N=4 时须验证 LIGHT 窗口可行性（约需 1.08s，超过限制） | 连段更短；N=2 时较难体现连段成就感 |
| `hit_animation_duration` | 0.25s | 0.15–0.30s | 每击节奏更慢、更重；过长则 LIGHT 窗口无法完成 3 击 | 每击更轻快；过短则失去打击重量感 |
| `bonus_ratio` | 0.5 | 0.4–0.8 | 奖励时长更长，完整连段激励更强；超过 0.8 SWEEP 总硬直过长 | 奖励减少；低于 0.4 时奖励感知不明显 |
| `counter_damage_multiplier_1` | 0.8 | 0.5–1.0 | 第 1 击伤害更高，连段起手即有回报 | 第 1 击更弱，突显后续击数的价值 |
| `counter_damage_multiplier_2` | 1.1 | 0.8–1.3 | 第 2 击中段奖励增加 | 减少中段激励 |
| `counter_damage_multiplier_3` | 1.6 | 1.2–2.5 | 完整连段末击有爆发感（慎用，超过 2.0 后总伤害可能过高）| 完整连段终点奖励减少 |

**旋钮交互警告：**
- `max_hits` 与 `hit_animation_duration` 强关联：`max_hits × hit_animation_duration < base_counter_window[LIGHT]` 必须成立（见公式 3）。调整任意一个须验证另一个。
- 三个 `counter_damage_multiplier` 须保持严格递增顺序（multiplier[1] < multiplier[2] < multiplier[3]）；打破顺序消除连段递进奖励的设计意图。
- `bonus_ratio` 安全上限 0.8：确保 SWEEP 全连击总硬直（`2.0×(1+bonus_ratio)`）不超过 4.0s。

## Visual/Audio Requirements

> *lean 模式：art-director 未咨询，基于格挡/预警 GDD 视觉规范和艺术圣经风格一致性起草；生产前应补充审查。*

### 每状态视觉需求

| 状态 / 事件 | 视觉效果 | 优先级 | 备注 |
|------------|---------|--------|------|
| **COUNTER_WINDOW_OPEN 进入** | 窗口开启特效（冷蓝/白色边框高亮，区别于格挡成功的白色光爆）；HUD 反击窗口条激活 | 必须 | 与格挡成功光爆视觉分层 |
| **每次连击落地（hit n）** | 玩家攻击动画第 n 击；Boss 受击动画（受击抖动，动画强度随 n 增大）；打击数字弹出 | 必须 | 三击视觉须有明显递进感：第 3 击明显重于第 1 击（动画幅度、Boss 受击反应） |
| **全连击完成（BONUS_STAGGER）** | 全连击爆发特效（高亮粒子 / Boss 发出**枯骨白高亮 `#F5F0E8`** 光晕，区别于单击受击）；HUD 闪烁"全连击"反馈。**注意：禁止使用霜白 `#EDF3FF`——霜白专属格挡/受击结晶瞬间（Art Bible 色彩保护规则）** | 必须 | 本系统最重要的视觉奖励节点，须明显区别于"未完成全连击时窗口到期" |
| **窗口倒计时（进行中）** | HUD 反击条随时间减少（见 UI Requirements）| 必须 | 玩家需感知窗口剩余时间 |
| **窗口到期未完成全连击** | 无专属特效（Boss 从 STAGGERED 恢复，视觉由 Boss 状态机驱动）| 不适用 | 避免"失败"有专属特效加重挫败感 |

### 音频事件

| 事件 | 音频效果 | 优先级 |
|------|---------|--------|
| **第 1 击** | 干净利落的中频打击音（"扎实"感）| 必须 |
| **第 2 击** | 同音色加重（低频共鸣更强，约 +15% 音量）| 必须 |
| **第 3 击** | 明显爆发感（高频尖锐 + 低频冲击，与前两击同族但更猛烈）| 必须 |
| **全连击完成** | 短暂 hitpause（30ms）+ 特殊共鸣余音（区别于第 3 击普通结束音）| 必须 |
| **窗口到期（未全连击）** | 无专属音效——Boss 恢复音效由 Boss 状态机提供 | 不适用 |

> **📌 Asset Spec** — Visual/Audio 需求已定义。艺术圣经批准后，运行 `/asset-spec system:counter-attack-combo` 生成连击动画、打击特效、全连击爆发特效的资产规格。

## UI Requirements

| 信息 | 显示位置 | 更新来源 | 触发条件 |
|------|----------|---------|---------|
| 反击窗口剩余时间条 | 玩家角色旁或屏幕下方（待 UX spec 定义）| `counter_window_updated.time_remaining` 每帧 | COUNTER_WINDOW_OPEN 和 BONUS_STAGGER 期间 |
| 当前连击计数（hit n/3）| 与时间条联动（或独立显示）| `counter_window_updated.hit_count` | 每击更新 |
| 全连击完成反馈 | 短暂文字或图标闪烁"全连击" | `counter_full_combo_completed` 信号 | 完成第 3 击后 |
| 奖励硬直剩余时间 | BONUS_STAGGER 状态下时间条颜色变化（金色/特殊色）| `counter_window_updated.state=BONUS_STAGGER` | BONUS_STAGGER 期间 |

> **📌 UX Flag — 反击连段系统**：本系统有 UI 需求（反击窗口条 + 连击计数 + 全连击反馈）。Pre-Production 阶段运行 `/ux-design` 创建反击窗口 HUD 的 UX 规格，与格挡窗口 HUD（格挡/预警系统）统一设计，避免视觉冲突。

## Acceptance Criteria

> **故事类型**: Logic（状态机 + 公式 + 信号路由）。全部 AC 须有 `tests/unit/counter_attack_combo/` 下通过的自动化单元测试，这是 Done 的硬性门槛。

**状态进入与窗口初始化**

- [ ] **AC-01** GIVEN 系统 IDLE，WHEN 收到 `parry_succeeded(HEAVY)`，THEN 进入 COUNTER_WINDOW_OPEN；window_timer=1.5s；current_hit_count=0；hit_cooldown_active=false。
- [ ] **AC-02** GIVEN COUNTER_WINDOW_OPEN，hit_count=0，hit_cooldown_active=false，WHEN `attack_input_pressed`，THEN hit_count=1；调用 `apply_damage(BOSS, 16.0)`（20×0.8）；hit_cooldown_active=true。
- [ ] **AC-02b** GIVEN COUNTER_WINDOW_OPEN，hit_count=1，hit_cooldown_active=false，WHEN `attack_input_pressed`，THEN hit_count=2；调用 `apply_damage(BOSS, 22.0)`（20×1.1）；hit_cooldown_active=true。
- [ ] **AC-03** GIVEN COUNTER_WINDOW_OPEN，hit_count=2，hit_cooldown_active=false，WHEN `attack_input_pressed`，THEN hit_count=3；调用 `apply_damage(BOSS, 32.0)`（20×1.6）；发出 `counter_full_combo_completed(attack_type)`；进入 BONUS_STAGGER。

**冷却逻辑**

- [ ] **AC-04** GIVEN COUNTER_WINDOW_OPEN，hit_cooldown_active=true，WHEN `attack_input_pressed`，THEN hit_count 不变；`apply_damage` 未调用（冷却期输入无效）。
- [ ] **AC-05** GIVEN hit_cooldown_active=true，WHEN hit_animation_duration（0.25s）时间过去，THEN hit_cooldown_active=false；下一次 `attack_input_pressed` 正常处理（hit_count++，apply_damage 调用）。

**BONUS_STAGGER 行为**

- [ ] **AC-06** GIVEN BONUS_STAGGER（attack_type=SWEEP），WHEN bonus_window_timer 耗尽（1.0s），THEN 发出 `stagger_ended`；系统回到 IDLE。
- [ ] **AC-06b** GIVEN 全连击完成（LIGHT），WHEN 进入 BONUS_STAGGER，THEN bonus_window_timer=0.5s（1.0×0.5）；耗尽后发出 `stagger_ended`。
- [ ] **AC-06c** GIVEN 全连击完成（HEAVY），WHEN 进入 BONUS_STAGGER，THEN bonus_window_timer=0.75s（1.5×0.5）；耗尽后发出 `stagger_ended`。
- [ ] **AC-07** GIVEN BONUS_STAGGER，WHEN `attack_input_pressed`，THEN 输入被忽略；hit_count 不变；`apply_damage` 未调用。

**窗口到期（未完成全连击）**

- [ ] **AC-08** GIVEN COUNTER_WINDOW_OPEN，hit_count=1（仅打了 1 击），WHEN window_timer 耗尽，THEN 发出 `stagger_ended`；系统回到 IDLE；已调用过的 `apply_damage`（16.0）保持不变（不回滚）；`counter_full_combo_completed` 未发出。

**防御性边界**

- [ ] **AC-09** GIVEN COUNTER_WINDOW_OPEN（窗口已开启），WHEN 收到第二个 `parry_succeeded(HEAVY)`，THEN 信号被丢弃；window_timer 不被重置；current_hit_count 不变；输出 warning 日志。

**生命周期中断**

- [ ] **AC-10** GIVEN COUNTER_WINDOW_OPEN，WHEN 收到 `boss_defeated`，THEN 立即回到 IDLE；不发出 `stagger_ended`；`apply_damage` 不再调用。
- [ ] **AC-11** GIVEN COUNTER_WINDOW_OPEN，WHEN 收到 `player_died`，THEN 立即回到 IDLE；不发出 `stagger_ended`。

**配置注入验证**

- [ ] **AC-12** GIVEN 通过 mock 数据资产注入 multiplier[1]=1.0、multiplier[2]=1.5、multiplier[3]=2.0（非默认值），WHEN 依次执行 3 次连击，THEN `apply_damage` 被调用 3 次，金额分别为 20.0、30.0、40.0；验证乘数从配置读取而非硬编码。

**加载时校验（clamp 行为）**

- [ ] **AC-13** GIVEN hit_animation_duration 配置为 0.35s（超过上限 0.307s），WHEN 数据资产加载，THEN 值被 clamp 至 0.30s；输出 warning；系统正常初始化。
- [ ] **AC-14** GIVEN bonus_ratio 配置为 0.9（超过上限 0.8），WHEN 数据资产加载，THEN 值被 clamp 至 0.8；输出 warning；SWEEP 全连击 bonus_stagger_duration = 2.0×0.8 = 1.6s。

**HUD 信号广播**

- [ ] **AC-15** GIVEN COUNTER_WINDOW_OPEN，WHEN 每物理帧 `_physics_process(delta)` 运行，THEN `counter_window_updated` 信号发出；`hit_count` 字段等于 current_hit_count；`state` 字段等于 COUNTER_WINDOW_OPEN；`time_remaining` 在 [0, base_counter_window] 范围内严格递减。
- [ ] **AC-16** GIVEN 进入 BONUS_STAGGER，WHEN 每物理帧运行，THEN `counter_window_updated.state = BONUS_STAGGER`；`hit_count = 3`；`time_remaining` 从 bonus_stagger_duration 开始递减。

> **代码审查 AC（Code Review Gate）**: 连击系统核心逻辑 .gd 文件不得出现 `0.8`、`1.1`、`1.6`（乘数）或 `0.5`（bonus_ratio）等字面量；所有值通过数据资产注入。在 `/code-review` 阶段由 lead-programmer 验证。

## Open Questions

| 问题 | 负责人 | 解决时机 | 状态 |
|------|--------|----------|------|
| 格挡/预警系统 GDD 需要更新：移除 STAGGERING 状态的 stagger_timer 和 stagger_ended 逻辑；该 GDD 的 AC 也需相应修订 | 设计协调 | 本 GDD 批准后立即处理 | ✅ 已完成（2026-06-01） |
| `attack_input_pressed` 信号：是专用攻击键还是复用格挡键？键位映射需在设置/无障碍系统 GDD 中确认 | 设计/UX | 设置系统 GDD 设计时 | 待定 |
| LIGHT 窗口（1.0s）下 3 击余量仅 10 帧，对部分玩家可能过紧——是否需要辅助功能选项（如无障碍模式延长 Boss 硬直时间）？ | UX / 设置系统 GDD | 垂直切片玩测 | 待定 |
| 连击总伤害（70 hp / 完整 combo）与 Boss 总 HP（1000 hp）的比例约 7%，玩家需约 14–15 次完整格挡——实际战斗时长需实机验证 | 平衡测试 | 垂直切片玩测 | 待定 |
| `counter_window_updated` 每物理帧广播的性能影响（144fps+ 设备）是否需要节流策略？ | 架构 ADR | /create-architecture | 待定 |
