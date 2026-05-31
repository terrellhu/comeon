# 玩家角色控制系统 (Player Character Controller)

> **Status**: Designed (Pending Review)
> **Author**: game-designer + systems-designer
> **Last Updated**: 2026-05-31
> **Implements Pillar**: Pillar 1「读懂才能赢」/ Pillar 4「失败是学习」

## Summary

玩家角色控制系统将来自键盘/鼠标或手柄的原始输入，转换为玩家角色在横向卷轴 Boss 战场中的物理运动和动作触发。它维护玩家的完整状态机（站立、跑动、跳跃、格挡、闪避、受击、死亡），并向下游系统（格挡/预警、闪避）广播状态变化信号。没有它，玩家无法在世界中存在——所有战斗系统都从此系统出发。

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `设置/无障碍系统（临时）`

## Overview

玩家角色控制系统是所有玩家动作的起点。它使用 Godot 4.6 的 CharacterBody2D + move_and_slide() 处理横向卷轴重力物理，将输入动作（移动、跳跃、格挡、闪避）映射到角色运动和状态转换。系统不决定格挡是否成功——它只发出"格挡输入已发生"的信号，格挡/预警系统负责时机判断。同理，它只触发闪避系统，不自行计算无敌帧。控制器的核心职责是：**在正确的时机响应正确的输入**，并将角色保持在内部一致的状态中。

## Player Fantasy

控制器消失，剩下的只有你的意图。

最好的玩家控制感发生在玩家停止思考"我要按什么键"，开始思考"我要往哪里闪"的那一刻。这是输入系统成功的标志——它不应该是需要学习的东西，而是在第一次尝试后就"感觉自然"的东西。

对于刃响，玩家控制的幻想是**精准感**：移动到位、跳到准确高度、格挡按下去感觉"啪"一声卡位——不是飘的，不是滑的，而是有重量的确认感。每次输入都应该有一个清晰的"这个按键产生了这个结果"的感知，即使这个结果是"没有格挡成功"，玩家也应该清楚地知道"我按了，但我的时机错了"。

这种精准感服务于 Pillar 1「读懂才能赢」——玩家必须能信任控制器，才能把所有注意力投入到读取 Boss 的预警上。如果控制器本身有歧义，玩家会把失败归因于控制问题而不是自己的时机判断，破坏整个学习循环。

## Detailed Design

### Core Rules

**基础物理**

1. 玩家角色使用 `CharacterBody2D`，每物理帧通过 `move_and_slide()` 处理重力和碰撞。
2. 重力持续累积：`velocity.y += gravity × delta`，直到 `is_on_floor()` 为 true。在地面上时 `velocity.y = 0`（防止重力无限堆积）。
3. 水平移动：`velocity.x = move_input_direction × move_speed`。无移动输入时：`velocity.x` 立即归零（无滑行）。

**输入动作（Godot InputMap 动作名）**

4. 已注册的输入动作：`move_left`、`move_right`、`jump`、`parry`、`dodge`、`attack`。物理键位/手柄按钮由设置系统配置，本系统只使用动作名。
5. **格挡优先规则**：在 IDLE、RUNNING、AIRBORNE 任一状态下检测到 `parry` 输入时，立即进入 PARRYING 状态，`velocity.x` 归零，忽略同帧的移动输入。
6. **跳跃妥幺时间（Coyote Time）**：玩家走出平台后的 `coyote_time_duration` 秒内（未主动跳跃离开），仍可执行跳跃。主动跳跃离开平台后不触发妥幺时间。
7. **跳跃缓冲（Jump Buffer）**：`jump` 输入按下后的 `jump_buffer_duration` 秒内落地，着陆瞬间立即执行跳跃。
8. **闪避方向锁定**：`dodge` 输入时，闪避方向为当前水平移动方向。静止时：闪避向角色面朝方向。控制器将方向和触发事件通知给闪避系统，然后进入 DODGING 状态。
9. **面朝方向**：角色始终面向最后一次水平移动输入的方向。PARRYING 和 DODGING 期间不改变面朝方向。
10. **DEAD 状态**：收到伤害/生命系统的 `player_died` 信号时，立即进入 DEAD 状态，`velocity = Vector2.ZERO`，禁用所有输入处理。只有即时重试系统的外部重置信号才能退出 DEAD 状态。
11. **攻击输入转发**：`attack` 输入在 IDLE、RUNNING、AIRBORNE 任一状态下被检测到时，立即同帧发出 `attack_input_pressed` 信号。**控制器不进入新状态，不锁定移动**——反击连段系统门控该信号的实际响应（仅在 COUNTER_WINDOW_OPEN + 无冷却时执行连击；其他状态下忽略）。在 PARRYING / DODGING / HIT_STUN / DEAD 状态下，`attack` 输入被忽略，不发出信号。设计简化分工：控制器只负责"按键发生"事件，连击逻辑（动画冷却、击数推进、伤害分配）完全归反击连段系统。

---

### States and Transitions

| 状态 | 进入条件 | 退出条件 | 行为 |
|------|----------|----------|------|
| **IDLE** | 初始状态；落地后无移动输入；PARRYING/DODGING/HIT_STUN 结束 | 移动输入 → RUNNING；`jump` → AIRBORNE；`parry` → PARRYING；`dodge` → DODGING；`player_died` → DEAD | 静止，保持面朝方向 |
| **RUNNING** | 检测到移动输入（IDLE/RUNNING 时） | 移动输入释放 → IDLE；`jump` → AIRBORNE；`parry` → PARRYING；`dodge` → DODGING；`player_died` → DEAD | velocity.x = ±move_speed |
| **AIRBORNE** | 跳跃执行；走出平台无 is_on_floor | is_on_floor() 为 true → IDLE 或 RUNNING；`parry` → PARRYING | velocity.y += gravity × delta；允许空中格挡 |
| **PARRYING** | `parry` 输入（IDLE/RUNNING/AIRBORNE） | 格挡动画播放结束（由格挡/预警系统决定）→ 返回上一个地面/空中状态 | velocity.x = 0；发出 `parry_input_pressed` 信号 |
| **DODGING** | `dodge` 输入（IDLE/RUNNING） | 闪避系统发出 `dodge_ended` 信号 → IDLE/RUNNING | 位置由闪避系统控制；控制器暂停自身物理 |
| **HIT_STUN** | 收到 `player_hp_changed` 且 HP 减少 | `hit_stun_duration` 计时器结束 → 上一个正常状态 | 短暂水平击退（`knockback_velocity`）；输入忽略 |
| **DEAD** | 收到 `player_died` 信号 | 即时重试系统发出外部重置信号 | velocity = 0；所有输入禁用 |

---

### Interactions with Other Systems

| 系统 | 方向 | 接口 |
|------|------|------|
| 格挡/预警系统 | ← → | 控制器进入 PARRYING 时发出 `parry_input_pressed`；格挡系统发回动画结束信号让控制器退出 PARRYING |
| 闪避系统 | ← → | 控制器进入 DODGING 时发出 `dodge_input_pressed(direction)`；闪避系统控制移动并发出 `dodge_ended` |
| 反击连段系统 | → 触发 | 控制器在 IDLE/RUNNING/AIRBORNE 状态检测到 `attack` 输入时发出 `attack_input_pressed`；反击连段系统接收后门控（仅 COUNTER_WINDOW_OPEN 期间执行连击） |
| 伤害/生命系统 | ← 订阅 | 订阅 `player_hp_changed`（HP 减少 → HIT_STUN）和 `player_died`（→ DEAD） |
| 治疗系统 | ← 触发（Alpha） | 治疗输入动作由控制器转发（`heal_input_pressed`） |
| 设置/无障碍系统 | ← 依赖（临时） | InputMap 动作名（`move_left`、`move_right`、`jump`、`parry`、`dodge`、`attack`）的物理键位由设置系统配置 |

## Formulas

### F-01：水平移动速度

```
velocity_x = move_input_direction × move_speed
```

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 水平输入方向 | `move_input_direction` | int | {−1, 0, 1} | 来自 InputMap 的归一化离散值 |
| 移动速度 | `move_speed` | float | 280–420 px/s | 每秒水平位移量（调校旋钮） |
| 水平速度 | `velocity_x` | float | [−420, 420] px/s | 输出至 CharacterBody2D.velocity.x |

**Output Range**: [−move_speed, +move_speed]，无需 clamp（由输入离散性保证）

**设计意图**: 无加速曲线，无 lerp——输入松开时 velocity_x 同帧归零。响应速度优先于手感"自然"。

**基准值**: `move_speed = 340 px/s`（约 3 秒穿越 1000px 战场）

**Example**: 右移输入 → `1 × 340 = 340 px/s`；格挡中 → `0 × 340 = 0 px/s`

---

### F-02：重力累积

```
velocity_y_next = velocity_y + gravity × delta
velocity_y_clamped = min(velocity_y_next, terminal_velocity)
```

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 当前垂直速度 | `velocity_y` | float | [0, terminal_velocity] | 正值 = 向下（Godot 屏幕空间） |
| 重力加速度 | `gravity` | float | 900–1600 px/s² | 每秒叠加量（调校旋钮） |
| 物理帧时长 | `delta` | float | ~0.01667 s | Godot 60fps 物理帧，固定 |
| 垂直速度上限 | `terminal_velocity` | float | 1000–1400 px/s | 防穿透软性 clamp（调校旋钮） |

**基准值**: `gravity = 1400 px/s²`，`terminal_velocity = 1200 px/s`

**Example（60fps，delta≈0.01667s）**: 第 1 帧：`0 + 1400 × 0.01667 ≈ 23.3 px/s`；第 51 帧（≈0.85s）：达到 1200 px/s 上限

---

### F-03：跳跃起始冲量

```
velocity_y_on_jump = −jump_impulse
jump_height ≈ jump_impulse² / (2 × gravity)    [近似，忽略 delta 离散误差]
```

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 跳跃冲量 | `jump_impulse` | float | 480–800 px/s | 起跳瞬间赋予的向上速度（调校旋钮） |
| 跳跃后垂直速度 | `velocity_y_on_jump` | float | [−800, −480] px/s | 负值 = 向上 |
| 跳跃弧线高度（理论） | `jump_height` | float | 100–270 px | 从地面到顶点的垂直距离 |

**选定方案 A**: `jump_impulse = 600 px/s`（配合 gravity=1400）

**Example（方案 A）**: 
- 顶点时间：`600 ÷ 1400 ≈ 0.43s`
- 理论顶点高度：`600² ÷ (2 × 1400) ≈ 129 px`（实际含 delta 误差约 150–160 px）
- 总空中时间：约 0.86s

---

### F-04：妥幺时间 / 跳跃缓冲（计时器规则）

**妥幺时间（Coyote Time）**

玩家离开地面后的 `coyote_time_duration` 秒内，仍可执行地面跳跃。

| 参数 | 推荐值 | 安全范围 | 说明 |
|------|--------|----------|------|
| `coyote_time_duration` | **0.10 s**（6 帧） | 0.05–0.15 s | 超过 0.15s 会让玩家察觉到"悬空帮助" |

**跳跃缓冲（Jump Buffer）**

空中按下 `jump` 后的 `jump_buffer_duration` 秒内落地，着陆时自动执行跳跃。

| 参数 | 推荐值 | 安全范围 | 说明 |
|------|--------|----------|------|
| `jump_buffer_duration` | **0.12 s**（7 帧） | 0.08–0.20 s | Boss Rush 中落地即连跳需求高，缓冲略宽于妥幺时间 |

---

### F-05：受击硬直击退

```
velocity_x_on_hit = −facing_direction × knockback_speed
```

击退持续 `hit_stun_duration` 秒；期间 velocity_x 锁定为此值，玩家输入无效。

| 变量 | 符号 | 类型 | 范围 | 说明 |
|------|------|------|------|------|
| 面朝方向 | `facing_direction` | int | {−1, 1} | 受击时角色面朝方向 |
| 击退速度 | `knockback_speed` | float | 150–350 px/s | 全局基准 200 px/s，可被 Boss 攻击数据覆盖 |
| 硬直时长 | `hit_stun_duration` | float | 0.2–0.5 s | 必须 ≤ `player_hit_invuln_duration`（0.5s，已注册） |

**约束**: `hit_stun_duration ≤ player_hit_invuln_duration = 0.5s`（健康系统已注册值）

**基准值**: `knockback_speed = 200 px/s`，`hit_stun_duration = 0.30 s`

**注意**: 击退无垂直分量（不修改 velocity_y）——防止玩家被弹出战场边界。

**Example**: 面朝右（facing=1），受击 knockback_speed=200：`velocity_x = −200 px/s`，持续 0.3s

---

### 参数完整性验证

以方案 A 基准值验证全链路一致性：

| 检查项 | 结果 |
|--------|------|
| hit_stun_duration (0.30s) ≤ player_hit_invuln_duration (0.50s) | ✅ |
| jump_height (≈150px) < 典型 Boss 腿部高度（预估 200px） | ⚠️ 待垂直切片验证 |
| 战场穿越时间 (1000px ÷ 340 = 2.94s) > 单次格挡序列时长 (≈1.5s) | ✅ 足够机动 |

## Edge Cases

| 场景 | 预期行为 | 理由 |
|------|----------|------|
| **PARRYING 状态期间收到 `jump` 输入** | 忽略，不执行跳跃，不进入跳跃缓冲 | 格挡期间不允许跳跃取消 |
| **同帧同时检测到 `parry` 和 `dodge` 输入** | `parry` 优先，`dodge` 忽略 | 格挡优先规则明确；防止状态机歧义 |
| **DODGING 状态期间收到 `parry` 输入** | 忽略，闪避结束后才能格挡 | 闪避系统控制移动期间不接受其他动作输入 |
| **AIRBORNE 状态多次按 `jump`（无二段跳）** | 仅第一次执行跳跃；后续输入进入缓冲，落地时再次跳跃 | 无二段跳；但落地前的输入不丢弃 |
| **`player_died` 在 DODGING 期间到达** | 立即进入 DEAD 状态，强制收回闪避系统的位置控制权 | 死亡状态优先级最高 |
| **`player_died` 在 PARRYING 期间到达** | 立即进入 DEAD 状态，格挡动画中止 | 同上 |
| **HIT_STUN 期间再次受击** | 击退计时器重置；新 `knockback_velocity` 覆盖旧值；HP 由无敌帧保护（伤害/生命系统职责） | 无敌帧防 HP 损失，但物理击退可叠加重置 |
| **走到战场边界（碰侧墙）** | `move_and_slide()` 正常阻挡，velocity_x 被碰撞归零 | CharacterBody2D 内置，无需额外逻辑 |
| **妥幺时间内反复走出/走回平台边缘** | 妥幺计时器不重置——只有初次离开地面才启动 | 防止快速边缘进出无限刷新妥幺时间 |

## Dependencies

| 系统 | 方向 | 依赖性质 |
|------|------|----------|
| 设置/无障碍系统 | 本系统依赖（临时） | InputMap 动作名的物理键位由设置系统配置；当前临时假定使用 Godot 默认 InputMap |
| 格挡/预警系统 | 格挡系统依赖本系统 | 订阅 `parry_input_pressed` 信号 |
| 闪避系统 | 闪避系统依赖本系统 | 订阅 `dodge_input_pressed(direction)` 信号；闪避结束发出 `dodge_ended` 让控制器恢复 |
| 反击连段系统 | 反击连段系统依赖本系统 | 订阅 `attack_input_pressed` 信号；控制器无条件转发玩家攻击输入，连击门控由反击连段系统负责 |
| 伤害/生命系统 | 本系统依赖 | 订阅 `player_hp_changed`（触发 HIT_STUN）和 `player_died`（触发 DEAD） |
| 治疗系统 | 治疗系统依赖本系统（Alpha） | 订阅 `heal_input_pressed` 信号 |
| 即时重试系统 | 本系统依赖 | 订阅重试系统的重置信号，退出 DEAD 状态并重置速度和位置 |

## Tuning Knobs

| 参数 | 基准值 | 安全范围 | 增大效果 | 减小效果 |
|------|--------|----------|----------|----------|
| `move_speed` | 340 px/s | 280–420 | 机动性更强，重定位更快 | 移动更慢，感觉笨重 |
| `gravity` | 1400 px/s² | 900–1600 | 下落更快，跳跃弧线更短促 | 下落慢，弧线飘 |
| `terminal_velocity` | 1200 px/s | 1000–1400 | 允许更高速坠落（注意穿透风险） | 坠落更慢 |
| `jump_impulse` | 600 px/s | 480–800 | 跳跃更高，空中格挡窗口更大 | 跳跃更低，接近地面格挡风格 |
| `coyote_time_duration` | 0.10 s | 0.05–0.15 | 更宽容（离边缘更久可跳） | 更严苛 |
| `jump_buffer_duration` | 0.12 s | 0.08–0.20 | 更提前按也能触发连跳 | 必须在落地瞬间精确按 |
| `knockback_speed` | 200 px/s | 150–350 | 受击后被推更远 | 受击基本原地，格挡站位不被打乱 |
| `hit_stun_duration` | 0.30 s | 0.2–0.5（≤0.5s 无敌帧） | 硬直更长，控制恢复更慢 | 硬直更短，快速恢复 |

## Visual/Audio Requirements

| 事件 | 视觉反馈 | 音频反馈 | 优先级 |
|------|----------|----------|--------|
| 跑动（RUNNING） | 跑动循环动画（手绘帧动画） | 脚步音效（两步一循环，与移动速度同步） | 必须 |
| 跳跃起始 | 起跳动画帧（蓄力→腾空） | 轻微起跳音效（风切声或衣物声） | 推荐 |
| 落地 | 落地动画帧 + 轻微相机震动（50ms） | 落地冲击音效 | 必须 |
| 进入 PARRYING | 格挡姿势动画（手持武器迎击） | 无（格挡/预警系统负责格挡音效） | 必须 |
| 进入 DODGING | 闪避动画（方向性移动流光） | 无（闪避系统负责闪避音效） | 必须 |
| 受击（HIT_STUN） | 受击动画帧（身体后仰）+ 画面边缘红光（伤害/生命系统提供） | 冲击音效（伤害/生命系统定义） | 必须 |
| DEAD 状态 | 死亡倒下动画 | 无（静默，见伤害/生命系统 GDD） | 必须 |

> **📌 Asset Spec** — Visual/Audio 需求已定义。艺术圣经批准后，运行 `/asset-spec system:player-controller-system` 生成玩家角色动画帧规格。

## Game Feel

**Feel Reference**：Sekiro 的地面移动——有重量，有承诺，但精确。按下方向键立即响应，松开立即停止。不是物理模拟，是数字版人体。

**反参考**：不要飘（Shovel Knight 式滑动感），不要轻盈弹跳感。这是成人神话题材游戏，玩家的身体感知应该带有重量。

### Impact Moments

| Impact 类型 | 持续时间 | 效果描述 | 可调 |
|------------|---------|----------|------|
| 落地相机震动 | 50ms | 低振幅，垂直方向，快速衰减 | 是 |
| 受击相机震动 | 100ms | 中振幅，击打方向，快速衰减 | 是 |
| 起跳手柄轻震 | 30ms | 轻微触感确认 | 是 |
| 落地手柄震动 | 80ms | 中等强度，表达重量 | 是 |

### Feel Acceptance Criteria

- [ ] 测试者描述移动为"响应"或"精准"；不使用"滑"或"飘"
- [ ] 从移动到完全停止（松开方向键）在 1 帧内完成——测试者不描述"减速感"
- [ ] 格挡按键后立即进入格挡姿势（≤2 帧 / 33ms）——测试者不描述"延迟感"
- [ ] 跳跃落地的手柄震动被测试者描述为"有分量"而非"假"

## UI Requirements

本系统无直接 HUD 需求。玩家当前状态（HP、死亡）由伤害/生命系统和 HUD 系统处理。

潜在 UI 需求（Alpha 阶段）：
- 控制器当前状态可视化调试工具（开发专用，非玩家可见）

## Cross-References

| 本文档引用 | 目标 GDD | 引用的具体元素 | 性质 |
|-----------|----------|---------------|------|
| `player_hit_invuln_duration = 0.5s` | `design/gdd/health-damage-system.md` | 无敌帧持续时间（hit_stun_duration 不得超过此值） | Rule dependency |
| `player_died` 信号 | `design/gdd/health-damage-system.md` | 死亡信号触发 DEAD 状态 | State trigger |
| `player_hp_changed` 信号 | `design/gdd/health-damage-system.md` | HP 减少触发 HIT_STUN | State trigger |
| `parry_input_pressed` 信号 | `design/gdd/parry-telegraph-system.md`（待创建） | 格挡/预警系统的消费信号 | State trigger |
| `dodge_input_pressed(direction)` 信号 | `design/gdd/dodge-system.md`（待创建） | 闪避系统的触发信号 | State trigger |
| `dodge_ended` 信号 | `design/gdd/dodge-system.md`（待创建） | 闪避结束通知控制器恢复 | State trigger |
| `attack_input_pressed` 信号 | `design/gdd/counter-attack-combo.md` | 反击连段系统的消费信号（门控连击执行） | State trigger |

## Acceptance Criteria

- [ ] **GIVEN** 玩家角色已实例化，**WHEN** `_physics_process` 每帧调用，**THEN** 角色使用 `CharacterBody2D` 节点类型，通过 `move_and_slide()` 处理移动
- [ ] **GIVEN** 角色处于 AIRBORNE 状态，**WHEN** 每物理帧执行，**THEN** `velocity.y` 每帧增加 `gravity × delta`（gravity=1400 px/s²），且不超过 terminal_velocity 1200 px/s
- [ ] **GIVEN** 角色 AIRBORNE 且 velocity.y 已达 1200 px/s，**WHEN** 继续下落，**THEN** velocity.y 保持 1200 px/s，不继续增大
- [ ] **GIVEN** 角色 RUNNING 且 is_on_floor() 为 true，**WHEN** _physics_process 执行，**THEN** velocity.y 赋值为 0，不累积
- [ ] **GIVEN** 角色处于 IDLE 或 RUNNING，**WHEN** 检测到 move_right 输入，**THEN** 同帧 velocity.x = 340 px/s，无加速曲线、无 lerp
- [ ] **GIVEN** 角色 RUNNING（velocity.x=340），**WHEN** 移动输入松开，**THEN** 同帧 velocity.x 归零——不存在任何减速帧或滑行
- [ ] **GIVEN** 角色处于 IDLE、RUNNING 或 AIRBORNE，**WHEN** 检测到 `parry` 输入动作，**THEN** 同帧进入 PARRYING 状态，velocity.x=0，发出 parry_input_pressed 信号，同帧移动输入被忽略
- [ ] **GIVEN** 角色走出平台边缘后 0.10s 内，**WHEN** 按下 `jump`，**THEN** 跳跃正常执行，velocity.y=-600 px/s
- [ ] **GIVEN** 角色走出平台边缘后超过 0.10s，**WHEN** 按下 `jump`，**THEN** 跳跃不执行（coyote time 已过期）
- [ ] **GIVEN** 角色 AIRBORNE，**WHEN** 在落地前 0.12s 内按下 `jump`，**THEN** 落地同帧自动执行跳跃，velocity.y=-600 px/s
- [ ] **GIVEN** 角色 AIRBORNE，**WHEN** 在落地前超过 0.12s 按下 `jump`，**THEN** 不触发跳跃缓冲，落地后不执行跳跃
- [ ] **GIVEN** 角色执行跳跃，**WHEN** `jump` 输入触发，**THEN** velocity.y=-600 px/s（负值向上）
- [ ] **GIVEN** 角色处于 IDLE（无水平输入），**WHEN** 检测到 `dodge` 输入，**THEN** 闪避方向等于 facing_direction，发出 dodge_input_pressed(facing_direction) 信号
- [ ] **GIVEN** 角色 RUNNING（move_input_direction=-1，向左），**WHEN** 检测到 `dodge` 输入，**THEN** 向闪避系统发出 dodge_input_pressed(-1) 信号
- [ ] **GIVEN** 角色处于 PARRYING 或 DODGING，**WHEN** 检测到水平移动输入，**THEN** facing_direction 不改变
- [ ] **GIVEN** 角色处于任意状态，**WHEN** 收到 `player_died` 信号，**THEN** 同帧进入 DEAD 状态，velocity=Vector2.ZERO，所有输入停止响应
- [ ] **GIVEN** 角色处于 DODGING 或 PARRYING，**WHEN** 收到 `player_died` 信号，**THEN** 立即进入 DEAD 状态，不等待 dodge_ended 或格挡动画结束
- [ ] **GIVEN** 角色处于非 DEAD 状态，**WHEN** 收到 `player_hp_changed` 且 HP 减少，**THEN** 进入 HIT_STUN，velocity.x=-facing_direction×200 px/s，持续 0.30s，输入忽略
- [ ] **GIVEN** 角色处于 HIT_STUN（计时器剩余 0.15s），**WHEN** 再次收到 HP 减少，**THEN** 计时器重置为 0.30s，velocity.x 以新方向覆盖
- [ ] **GIVEN** 同帧同时检测到 `parry` 和 `dodge` 输入，**WHEN** 状态机处理，**THEN** `parry` 优先执行，`dodge` 忽略
- [ ] **GIVEN** 角色处于 DODGING，**WHEN** 检测到 `parry` 输入，**THEN** 忽略，不进入 PARRYING，等待 dodge_ended
- [ ] **GIVEN** 角色 AIRBORNE 多次按 `jump`（无二段跳），**WHEN** 处理多个 jump 事件，**THEN** 仅第一次起跳执行；后续在落地前 0.12s 内的最后一次有效按下进入缓冲，落地时执行一次跳跃
- [ ] **GIVEN** 控制器正常运行，**WHEN** 每物理帧 _physics_process 执行，**THEN** 控制器逻辑执行时间 < 0.5ms（Godot 性能监视器验证）
- [ ] **GIVEN** 角色处于 IDLE、RUNNING 或 AIRBORNE，**WHEN** 检测到 `attack` 输入，**THEN** 同帧发出 `attack_input_pressed` 信号；状态不变；velocity.x 不修改；不进入新状态
- [ ] **GIVEN** 角色处于 PARRYING、DODGING、HIT_STUN 或 DEAD，**WHEN** 检测到 `attack` 输入，**THEN** 输入被忽略；不发出 `attack_input_pressed` 信号
- [ ] **GIVEN** 角色处于 RUNNING（velocity.x=340），**WHEN** 检测到 `attack` 输入，**THEN** 发出 `attack_input_pressed` 信号；velocity.x 保持 340（攻击不锁定移动，分工由反击连段系统负责）
- [ ] **GIVEN** 控制器 .gd 文件已提交，**WHEN** 静态审查，**THEN** 不存在硬编码数值（340、1400、600、0.10、0.12、200、0.30 等）；所有参数以 @export 变量声明；所有输入检测仅引用 InputMap 动作名字符串（包含 `attack`），不使用硬编码键码

## Open Questions

| 问题 | 负责人 | 解决时机 | 状态 |
|------|--------|----------|------|
| 跳跃高度（约 150px）是否足以清过 Boss 腿部？需要实际 Boss 美术确认 | 垂直切片阶段 | 第一个 Boss 的美术尺寸确定后 | 待定 |
| 格挡动画结束通知机制：动画信号还是固定计时器？（影响 PARRYING 退出条件） | 格挡/预警系统 GDD | 设计格挡/预警系统时 | 待定 |
| 设置/无障碍系统定义控制重映射的时机？当前使用临时假定（Godot 默认 InputMap） | 设置/无障碍系统 GDD | Alpha 阶段 | 待定 |
