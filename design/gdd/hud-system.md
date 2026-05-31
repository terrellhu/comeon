# HUD 系统 (HUD System)

> **Status**: Designed (Pending Review)
> **Author**: game-designer + ux-designer + art-director
> **Last Updated**: 2026-05-31
> **Implements Pillar**: Pillar 1「读懂才能赢」/ Pillar 2「每个神明都是一首歌」/ Pillar 4「失败是学习」

## Overview

HUD 系统是「读懂才能赢」的视觉基础设施——它将游戏内所有关键实时数据订阅为信号，转化为玩家可以不经思考直接感知的视觉指示器。系统由六个独立 HUD 元素组成：**玩家 HP 段数条**（订阅 `player_hp_changed`，显示 5 段式血量）、**Boss HP 连续血条**（订阅 `boss_hp_changed`，含阶段分隔标记）、**预警进度指示器**（订阅 `telegraph_updated` 每帧，颜色随预警阶段变化）、**反击窗口计时条**（订阅 `counter_window_updated`，显示反击剩余时间和连击计数 hit n/3）、以及**死亡计数器**（订阅 `retry_death_count_changed`）。HUD 是纯输出型系统——它只读取来自其他系统的信号，不向任何系统发出信号，不影响游戏逻辑。HUD 元素必须满足「剪影优先」原则（Art Bible Principle 3）：任何 HUD 元素不得与 Boss 的攻击预警视觉竞争——当 Boss 的橙光开始发亮，那一帧 Boss 是主角，HUD 是背景。

## Player Fantasy

最好的 HUD 是你感觉不到"在读 HUD"——你只是在看战斗。

Boss 的橙光渐亮，你的眼角扫到那道细长的进度条也在跟着变化，但你没有"看进度条"——你在用视觉余光感受节奏。那一格橙色高亮变成白色的瞬间，你的手指已经按下去了，不是看完进度条后做的决定，是格挡成功后验证的结果。

理想状态下，玩家三次以上死亡后才会有意识地"发现"各个 HUD 元素在哪里——第一次感知到 HUD 的时候，恰好是它们帮你做出了一个正确决策：那条快要空掉的反击窗口条让你打出了第三击，那道 Boss 血条上的刻度线让你意识到「再一刀就到第二阶段了」。

HUD 的幻想不是"我的界面很漂亮"，是"这个游戏告诉我一切我需要知道的，以我能吸收的方式"。

## Detailed Design

### Core Rules

**HUD 结构概述**

HUD 系统通过 CanvasLayer（始终渲染在游戏世界之上）托管四组独立 HUD 元素，每组订阅对应系统的信号，相互不依赖，互不影响。

**元素 1：玩家 HP 段数条（Player HP Bar）**
- 位置：屏幕左下区域
- 订阅：`player_hp_changed(current: float, max: float)`
- 显示：5 个独立段（与 `player_hp_segments = 5` 对应）；每段代表 20 HP
- 更新规则：收到信号后立即调用段数计算公式，更新亮段/暗段数量；HP = 0 时所有段熄灭
- HP 临界状态（最后 1 段剩余）：轻微慢速闪烁（0.5 Hz），不干扰战斗读取

**元素 2：Boss HP 连续血条 + 阶段分隔线（Boss HP Bar）**
- 位置：屏幕顶部居中
- 订阅：`boss_hp_changed(current: float, max: float, phase: int)`
- 显示：连续填充血条（宽度比例 = `current / max`）；血条内垂直分隔线标记阶段阈值位置（由 Boss 数据资产提供百分比，战斗开始时静态渲染，不随战斗更新位置）
- 阶段转换时：分隔线对应位置血条颜色轻微变化（深色区分已过阶段），持续 0.5s 过渡动画

**元素 3：预警进度指示器（Telegraph Progress Indicator）**
- 位置：Boss HP 血条正下方
- 订阅：`telegraph_updated(progress: float, window_open: bool, attack_type: AttackType)` — 每物理帧
- 显示：细长进度条（宽度与 Boss HP 血条对齐），进度随 `progress`（0.0→1.0）填充
  - PRE_WINDOW（`window_open = false`）：暗橙色 / 深红色
  - WINDOW_OPEN（`window_open = true`）：亮橙色 / 白色发光（Art Bible Principle 2：视觉高潮）
  - POST_WINDOW：深红/暗灰（明确区别于 WINDOW_OPEN，表达「攻击已在释放」）
- 非预警期间（无活跃 `attack_telegraphed`）：进度条隐藏（透明度 = 0）

**元素 4：反击窗口计时条 + 连击计数器（Counter Window HUD）**
- 位置：玩家角色身旁（跟随玩家位置，以世界坐标偏移量渲染在玩家头顶或脚下）
- 订阅：`counter_window_updated(hit_count: int, time_remaining: float, state: enum)` — 每物理帧
- 订阅：`counter_full_combo_completed(attack_type)` — 触发全连击完成特效
- 仅在 COUNTER_WINDOW_OPEN 和 BONUS_STAGGER 期间可见：
  - 反击窗口剩余时间条（填充比例 = `time_remaining / base_counter_window[attack_type]`）
  - 连击计数文本：「hit {hit_count}/3」
  - BONUS_STAGGER 期间：时间条颜色变为金色，区别于基础窗口
- 全连击完成时：「FULL COMBO」短暂文字/图标闪烁（持续 ~0.5s）
- COUNTER_WINDOW 关闭后：元素 0.2s 渐隐消失

---

### States and Transitions

| HUD 状态 | 进入条件 | 可见元素 |
|----------|----------|---------|
| `IDLE_COMBAT` | 战斗开始时 | 玩家 HP 段数条、Boss HP 血条 |
| `TELEGRAPHING` | `telegraph_updated` 信号活跃 | + 预警进度指示器（淡入） |
| `COUNTER_WINDOW` | `counter_window_updated.state = COUNTER_WINDOW_OPEN` | + 反击窗口计时条、连击计数器 |
| `BONUS_STAGGER` | `counter_window_updated.state = BONUS_STAGGER` | + 计时条变金色 |

*各状态可叠加——TELEGRAPHING 与 COUNTER_WINDOW 可同时激活*

---

### Interactions with Other Systems

| 系统 | 方向 | 接口 |
|------|------|------|
| 伤害/生命系统 | → 本系统 | 订阅 `player_hp_changed(current, max)` / `boss_hp_changed(current, max, phase)` |
| 格挡/预警系统 | → 本系统（流数据） | 订阅 `telegraph_updated(progress, window_open, attack_type)` 每物理帧 |
| 反击连段系统 | → 本系统（流数据） | 订阅 `counter_window_updated(hit_count, time_remaining, state)` 每物理帧；`counter_full_combo_completed` |
| 即时重试系统 | → 本系统（预留） | `retry_death_count_changed` — MVP 不显示，信号接口预留 |
| Boss 状态机 | → 本系统（配置） | Boss 数据资产的 `phase_threshold_pct[]`，战斗开始时读取一次渲染阶段分隔线 |

## Formulas

### 公式 1：HP 段数渲染映射（HP Segment Render Mapping）

离散查表映射，非连续比例。

```
segment_lit[i] = (i <= displayed_segments)
```

*`displayed_segments` 由伤害/生命系统 GDD 公式定义（`max(0, ceil(current_hp / hp_per_segment))`），HUD 引用，不重复定义。*

**变量：**
| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 当前显示段数 | `displayed_segments` | int | 0–5 | 由 `player_hp_changed(current, max)` 触发重新计算 |
| 段序号 | `i` | int | 1–5 | 当前评估段的编号（从 1 开始） |
| 段点亮状态 | `segment_lit[i]` | bool | true/false | true = 亮；false = 暗 |

**输出范围：** 每段独立 bool，无需 clamp。HP = 0 时所有段全暗；HP = 100 时所有段全亮。
**HP 临界特判：** `displayed_segments = 1` 时段 1 的 `segment_lit[1] = true` 不变，但视觉层叠加 0.5 Hz 闪烁修饰器。

**示例：** `current_hp = 55`, `hp_per_segment = 20` → `displayed_segments = 3` → 段 1/2/3 亮，段 4/5 暗。

---

### 公式 2：Boss HP 血条填充比例（Boss HP Fill Ratio）

```
boss_fill_ratio = clamp(boss_current_hp / boss_max_hp, 0.0, 1.0)
```

**变量：**
| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| Boss 当前 HP | `boss_current_hp` | float | 0.0–`boss_max_hp` | 来自 `boss_hp_changed.current` |
| Boss 最大 HP | `boss_max_hp` | float | > 0 | 来自 `boss_hp_changed.max`；每个 Boss 独立值，不使用注册表硬编码 |
| 血条填充比例 | `boss_fill_ratio` | float | 0.0–1.0 | 映射到血条控件宽度 |

**输出范围：** 强制 clamp [0.0, 1.0]，防止异常值（负 HP 或超出 max）导致视觉异常。
**阶段分隔线：** 位置 = `bar_total_width × phase_threshold_pct[n]`（战斗开始时一次性计算，非每帧公式）。

**示例：** `boss_current_hp = 750`, `boss_max_hp = 1000` → `boss_fill_ratio = 0.75`（血条 75%）。

---

### 公式 3：预警进度条宽度映射（Telegraph Progress Bar Fill）

直通映射，不做额外变换——线性进度对玩家格挡判断最直觉。

```
telegraph_bar_fill = clamp(progress, 0.0, 1.0)
```

**变量：**
| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 预警完成进度 | `progress` | float | 0.0–1.0 | 来自 `telegraph_updated.progress`；格挡系统定义为 `telegraph_timer / telegraph_duration` |
| 窗口开启状态 | `window_open` | bool | true/false | 控制进度条颜色（非宽度） |
| 进度条填充比例 | `telegraph_bar_fill` | float | 0.0–1.0 | 映射到进度条控件宽度 |

**颜色状态映射（渲染层逻辑，附注）：**
| `window_open` | 时段 | 颜色 |
|---|---|---|
| false | progress < 0.5（PRE_WINDOW） | 暗橙色 |
| true | 窗口区间（WINDOW_OPEN） | 亮橙/白色发光 |
| false | 窗口已过（POST_WINDOW） | 深红/暗灰 |

**示例：** LIGHT 攻击，`telegraph_timer = 0.4`, `telegraph_duration = 0.8` → `progress = 0.5` → 进度条 50% 填充，颜色切换为 WINDOW_OPEN 白光。

---

### 公式 4：反击窗口时间条填充比例（Counter Window Time Bar Fill）

```
counter_fill = clamp(time_remaining / base_counter_window[attack_type], 0.0, 1.0)
```

**变量：**
| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 反击窗口剩余时间 | `time_remaining` | float | 0.0–`base_counter_window[attack_type]` | 来自 `counter_window_updated.time_remaining` |
| 攻击类型 | `attack_type` | enum | {LIGHT, HEAVY, SWEEP} | 来自同一信号；决定分母；窗口生命周期内不变 |
| 基础反击窗口 | `base_counter_window[attack_type]` | float (const) | LIGHT=1.0s, HEAVY=1.5s, SWEEP=2.0s | 与注册表 `stagger_duration_*` 等值 |
| 时间条填充比例 | `counter_fill` | float | 0.0–1.0 | 满 = 窗口刚开启，空 = 窗口即将关闭 |

**BONUS_STAGGER 期间：** 分母仍使用 `base_counter_window[attack_type]`（不切换为 bonus_stagger_duration），时间条颜色变金色区分状态。切换分母会造成时间条视觉"跳回满格"的误读。

**示例：** LIGHT 攻击，`time_remaining = 0.7`, `base_counter_window[LIGHT] = 1.0` → `counter_fill = 0.7`（70% 填充）。BONUS_STAGGER 进入时 `time_remaining = 0.5` → `counter_fill = 0.5`（金色，从 50% 开始倒数）。

## Edge Cases

- **如果 `boss_hp_changed` 的 `max = 0`（数据错误）**：除零保护——HUD 检测 `max ≤ 0` 时显示空血条并输出错误日志，不计算 `fill_ratio`

- **如果 `telegraph_updated` 信号在旧预警未正常结束时收到新预警**：HUD 重置进度条状态并以新信号数据继续渲染，不保留旧状态残影

- **如果 `counter_window_updated` 和 `telegraph_updated` 同帧同时有效（叠加状态）**：两组元素独立渲染——Boss HP 条下方预警条与玩家角色旁反击条位置物理隔离，不产生视觉冲突

- **如果 `player_hp_changed` 的 `current > max`（边界异常）**：HUD 对 `displayed_segments` 执行 `clamp(0, player_hp_segments)` 后渲染，输出最大段数，不崩溃

- **如果 `boss_defeated` 信号发出后仍收到流数据信号**：战斗结束后 HUD 取消订阅 `telegraph_updated` 和 `counter_window_updated`，避免胜利动画期间旧数据继续刷新界面

- **如果 `counter_window_updated.attack_type` 在同一窗口内发生变化（信号时序异常）**：以最新收到的 `attack_type` 为准更新公式 4 分母，不存储历史值对比

- **如果游戏窗口分辨率低于设计分辨率**：HUD 通过 CanvasLayer 缩放适配，MVP 不单独优化极小分辨率

## Dependencies

### 上游依赖（本系统需要它们）

| 系统 | 依赖类型 | 具体接口 | 状态 |
|------|----------|----------|------|
| **伤害/生命系统** | 硬依赖 | `player_hp_changed(current, max)` / `boss_hp_changed(current, max, phase)` | ✅ 已设计 |
| **格挡/预警系统** | 硬依赖 | `telegraph_updated(progress, window_open, attack_type)` 每物理帧 | ✅ 已设计 |
| **反击连段系统** | 硬依赖 | `counter_window_updated(hit_count, time_remaining, state)` 每物理帧；`counter_full_combo_completed` | ✅ 已设计 |
| **Boss 状态机系统** | 软依赖 | Boss 数据资产 `phase_threshold_pct[]`，战斗开始时读取一次 | ✅ 已设计 |
| **即时重试系统** | 软依赖（MVP 预留） | `retry_death_count_changed(count)` — MVP 不显示，接口预留 | ✅ 已设计 |

### 下游

无——HUD 是纯输出系统，不向任何系统发出信号。

### 双向一致性

- `伤害/生命系统` GDD 已列出 HUD 系统为 `boss_hp_changed` / `player_hp_changed` 的订阅方 ✅
- `格挡/预警系统` GDD 已列出 HUD 系统为 `telegraph_updated` 的订阅方 ✅
- `反击连段系统` GDD 已列出 HUD 系统为 `counter_window_updated` / `counter_full_combo_completed` 的订阅方 ✅
- `即时重试系统` GDD 已列出 HUD 系统为 `retry_death_count_changed` 的订阅方 ✅

## Tuning Knobs

| 旋钮名 | 基准值 | 安全范围 | 过高的影响 | 过低的影响 |
|--------|--------|---------|------------|------------|
| `hp_bar_flash_frequency` | 0.5 Hz | 0.3–1.0 Hz | 闪烁过快干扰战斗视线 | 闪烁太慢，临界感知不够紧迫 |
| `telegraph_bar_fade_in_duration` | 0.05s | 0.0–0.1s | 进度条出现太慢，前几帧进度信息丢失 | 0 = 瞬间出现，可能突兀 |
| `counter_bar_fade_out_duration` | 0.2s | 0.1–0.3s | 窗口结束后残像太长 | 消失太快，玩家感知到「突然消失」 |
| `boss_phase_transition_duration` | 0.5s | 0.2–0.8s | 阶段颜色过渡太慢，与战斗脱节 | 过渡太快，玩家来不及感知阶段转换 |
| `full_combo_feedback_duration` | 0.5s | 0.3–0.8s | 「FULL COMBO」文字停留太长，干扰下一段预警读取 | 停留太短，高成就感反馈被浪费 |

**Knob 约束：** `telegraph_bar_fade_in_duration` < `window_open_fraction × telegraph_duration_light = 0.4s`——确保进度条完全可见时格挡窗口仍然开放。

## Visual/Audio Requirements

### 1. 整体 HUD 视觉风格：铸刻碑文（Incised Inscription）

HUD 元素是「刻入屏幕边框的建筑铭文」，不是「浮于屏幕上的 UI 玻璃层」。三条执行规则：

- **R-HUD-V1（几何语法）**：所有 HUD 元素使用直线 + 45° 倒角，无圆角，无有机曲线（Art Bible Section 3 绝对规则）。边框线宽 1px 精细轮廓，不使用渐变描边。
- **R-HUD-V2（腐化美学）**：腐化在细节层（血条段间 0.5px 刻缝、分隔线细微锯齿上沿）；辉煌在功能层（进度条进入 WINDOW_OPEN 即变成当帧最美元素）。HUD 本身不腐化——它代表「神明的清晰意志」。
- **R-HUD-V3（整体透明度）**：战斗进行中基础不透明度 85%。战斗开始后前 1 秒从 0% 线性升至 85%——Boss 出场是电影感时刻，HUD 不参与。

---

### 2. 颜色规范

**玩家 HP 段颜色：**

| 状态 | 颜色名 | Hex | 备注 |
|------|--------|-----|------|
| 段亮（有血量） | 枯骨白变体 | `#C8BFA8` | 降饱和 15% 的枯骨白 |
| 段暗（空血量） | 虚空墨 | `#0D0B1A` | 与亮段亮度差约 64%（灰度可辨）|
| 段边框 | 枯骨白降调 | `#6B6358` | 1px 内边框，亮/暗段共用 |
| HP 临界闪烁外框 | 锈金变体 | `#8B6914` | 仅用于段 1 外框 0.5 Hz 脉冲 |

**Boss HP 血条颜色：**

| 状态 | 颜色 | 备注 |
|------|------|------|
| 当前血量填充 | Boss 主色降饱和 15%（依各 Boss 色板） | 破钟示例：`#D9571A` |
| 已过阶段空区 | 虚空墨 + Boss 主色 5% 叠加 | 非纯黑 |
| 血条外框/底层 | Boss 主色降饱和 30%，亮度 -20% | 1px 轮廓 + 内凹阴影线 |
| 阶段分隔线（正常） | 枯骨白 `#E8DFC8`，宽 1.5px | — |
| 阶段分隔线（已压过） | 哑光锈金 `#8B6914`（永久不可逆） | 「这个阶段已征服」的视觉标记 |
| 分隔线压过瞬间高光 | 枯骨白高光 `#F5F0E8`，持续 0.3s | 非霜白（霜白保留给格挡成功）|

**预警进度条三态颜色：**

禁止使用「血迹赤 #7A1C2E」——红色仅用于已发生的伤害，绝不用于攻击预警。

| 状态 | 颜色名 | Hex | 灰度明度 |
|------|--------|-----|---------|
| PRE_WINDOW | 暗琥珀橙 | `#8C5A1A` | L33 |
| WINDOW_OPEN 主色 | 高亮琥珀金 | `#E8941A` | L51 |
| WINDOW_OPEN 发光叠层 | 冷金白 | `#F5E8C0` (alpha 0.65) | L86 合成后 L75 |
| POST_WINDOW | 深暗红棕 | `#4A1A0E` | L18 |

**色盲安全验证：** PRE_WINDOW→WINDOW_OPEN 明度差 18%，不足以独立识别——需叠加形状信号（见下方）。

**反击窗口计时条颜色：**

| 状态 | 颜色名 | Hex |
|------|--------|-----|
| COUNTER_WINDOW_OPEN（正常） | 淡冷青白 | `#8AB8C8` |
| COUNTER_WINDOW_OPEN 边框 | 同色降调 | `#4A7888` |
| BONUS_STAGGER | 衰减锈金 | `#C8A020` |
| BONUS_STAGGER 边框 | 深锈金 | `#8B6914` |
| 「FULL COMBO」文字 | `#C8A020` Serif Bold 24px | 无背景板 |

反击条（冷青 H197）与预警条（暖橙 H35）色相差约 160°，任何 Boss 颜色环境下不产生混淆。

---

### 3. 预警进度条 WINDOW_OPEN 视觉设计

**颜色对冲策略：** Boss 橙光（H15–20 红橙）与进度条琥珀金（H35）色相差 15–20°，配合发光叠层使进度条偏「黄金」而非「火焰橙」，实现视觉隔离。

**三重信号叠加（色盲安全）：**
1. 颜色变化（PRE_WINDOW L33 → WINDOW_OPEN L51）
2. 进度条高度在 2 帧内从 h 膨胀至 `h × 1.4`（格挡窗口「开锁」的形态隐喻）
3. 外框出现 2px 外发光（颜色 `#F5E8C0`，仅 WINDOW_OPEN 状态）

**R-TEL-V1（菱形标记）：** WINDOW_OPEN 激活时，进度条左侧出现 8×8px 菱形几何标记（非 8 点星形——8 点星专属格挡成功确认），颜色 `#E8941A` / 边框 `#F5E8C0` 1px，静止无动画。

**R-TEL-V3（职责分工）：**
- 预警进度条（屏幕顶部）：「时钟」——告知格挡窗口在时间轴上的位置
- 格挡指示器（附着玩家角色）：「呼叫」——告知「现在按键」
- 禁止在预警条上使用聚合/爆发动画——那是格挡指示器专属词汇

**静帧美学测试（Art Bible Principle 2 执行）：** 冻结 WINDOW_OPEN 状态任意帧——进度条区域 + 菱形 + 发光叠层，必须在屏幕顶部与 Boss HP 条形成「神庙门廊」双线结构，具备独立的构图美感。

---

### 4. 音效设计方向

| 事件 | 是否配音效 | 音色方向 | 时长 | 备注 |
|------|-----------|---------|------|------|
| HP 临界（最后 1 段）闪烁 | **否** | — | — | 视觉闪烁已足够；音效会打断战斗节奏感知 |
| 「FULL COMBO」 | **是** | 高频金属共振音（铸钟短促泛音），无鼓击/电子音 | 0.3–0.5s + 0.1s 谐波尾音 | 「神庙铭文被完整读出」的共鸣感；UI 层，低于打击音 4dB |
| 反击窗口开启 | **是** | 低频金属滑音（向上短促滑进）——「门缝打开」 | ≤ 0.15s | — |
| 反击窗口关闭 | **是** | 极短促哑音收束（金属闷击，低中频），无尾音 | ≤ 0.1s | 像一把刀插入刀鞘 |
| BONUS_STAGGER 激活 | **是** | 窗口开启音 + 高频泛音延展叠加，与金色视觉同步 | 0.3s 尾音 | 「超过预期的报偿」 |
| 预警 WINDOW_OPEN | **否（复用）** | 格挡系统「高频凝聚音」同帧触发，HUD 不独立发出 | — | 由格挡/预警系统音频层统一调度 |
| Boss HP 阶段被压过 | **是** | 低频重击音（持续 0.3s），非庆祝音色——「巨大事物被打断」 | 0.3s | 属于 Boss HP 条专属事件 |

---

### 5. 资产命名规范

```
ui_hpbar_player_segment_lit.png        # 玩家 HP 段亮态
ui_hpbar_player_segment_dark.png       # 玩家 HP 段暗态
ui_hpbar_player_frame.png              # HP 条外框（含倒角）
ui_hpbar_boss_fill_base.png            # Boss HP 填充底层（着色器叠色）
ui_hpbar_boss_phase_tick_normal.png    # 阶段分隔线（正常态）
ui_hpbar_boss_phase_tick_passed.png    # 阶段分隔线（已过，哑光金色）
ui_telegraph_bar_pre.png               # 预警条 PRE_WINDOW
ui_telegraph_bar_window.png            # 预警条 WINDOW_OPEN 主色
ui_telegraph_bar_window_glow.png       # 预警条 WINDOW_OPEN 发光叠层
ui_telegraph_bar_post.png              # 预警条 POST_WINDOW
ui_telegraph_diamond_marker.png        # WINDOW_OPEN 菱形标记 8×8px
ui_counter_bar_normal.png              # 反击条正常态
ui_counter_bar_bonus.png               # 反击条 BONUS_STAGGER 金色
ui_fullcombo_text_idle.png             # FULL COMBO 文字图（Serif Bold 美术字）
```

所有 UI 图标 64×64px，PNG，sRGB 8-bit，Mipmaps 禁用（Art Bible Section 8.8）。

---

### 6. 合规检查清单

| 编号 | 检查项 |
|------|--------|
| R-HUD-CHK-01 | 所有 HUD 颜色来自 Art Bible 主色板，无纯白 `#FFFFFF`、无霜白 `#EDF3FF` |
| R-HUD-CHK-02 | 所有 HUD 形状无有机曲线，全倒角直线几何 |
| R-HUD-CHK-03 | WINDOW_OPEN 进度条与 Boss 橙光并存时不产生色相混淆 |
| R-HUD-CHK-04 | 灰度模式下 HP 段亮/暗亮度差 ≥ 40% |
| R-HUD-CHK-05 | 灰度模式下预警条三态可辨（颜色 + 形状叠加验证）|
| R-HUD-CHK-06 | 战斗高潮帧中，HUD 亮度最高点不超过预警/Boss 受光面/玩家受光面 |
| R-HUD-CHK-07 | 「FULL COMBO」音色为金属共振，不使用电子合成 |
| R-HUD-CHK-08 | HP 临界（最后 1 格）无独立音效触发 |
| R-HUD-CHK-09 | WINDOW_OPEN 视觉切换与格挡系统「高频凝聚音」同帧触发，无脱帧 |
| R-HUD-CHK-10 | Boss HP 阶段压过时音效为低频重击，非庆祝音色 |

> 📌 **Asset Spec** — Visual/Audio 需求已定义。Art Bible 批准后，运行 `/asset-spec system:hud-system` 生成每个 HUD 资产的详细规格和生成 Prompt。

## UI Requirements

| HUD 元素 | 位置 | 尺寸（设计基准 1920×1080） | 可见条件 |
|----------|------|--------------------------|---------|
| 玩家 HP 段数条 | 屏幕左下，距边框 24px | 段宽 28px × 高 12px，段间距 4px；总宽 156px | 始终可见（战斗期间） |
| Boss HP 血条 | 屏幕顶部居中，距上边框 16px | 宽 640px × 高 14px；含外框 644×18px | 始终可见（战斗期间） |
| 预警进度条 | Boss HP 条正下方，垂直间距 4px | 宽 640px × 高 6px（WINDOW_OPEN 膨胀至 8.4px）| 有活跃预警时淡入，无预警时隐藏 |
| 反击窗口计时条 | 玩家角色头顶，Y 偏移 -48px | 宽 80px × 高 8px | 仅 COUNTER_WINDOW_OPEN / BONUS_STAGGER |
| 连击计数「hit n/3」| 反击窗口条上方，Y 偏移 -12px | 12px Serif，居中对齐 | 同反击窗口计时条 |
| 「FULL COMBO」文本 | 玩家角色头顶，Y 偏移 -64px | Serif Bold 24px | 全连击触发后 0.5s |

所有元素通过 CanvasLayer 渲染，不受游戏世界摄像机影响。反击窗口计时条的世界坐标跟随实现方案（CanvasLayer 屏幕坐标转换 vs Node2D 游戏世界层）待架构决策（→ ADR）。

> 📌 **UX Flag — HUD 系统**：本系统有大量 UI 需求。在 Pre-Production 阶段，运行 `/ux-design` 为 HUD 布局（`design/ux/hud.md`）和预警进度条交互设计创建 UX spec。Stories 引用 `design/ux/hud.md`，不直接引用本 GDD。

## Acceptance Criteria

### 元素1：玩家 HP 段数条

**AC-HUD-01** **GIVEN** 玩家 HP=60, max=100, **WHEN** `player_hp_changed(60, 100)` 触发, **THEN** 段 1/2/3 点亮，段 4/5 暗灭（`ceil(60/20)=3`）。

**AC-HUD-02** **GIVEN** 玩家 HP=1（临界）, **WHEN** `player_hp_changed(1, 100)` 触发, **THEN** 第 1 段以 0.5 Hz 闪烁（周期 2s），段 2-5 暗灭。

**AC-HUD-03** **GIVEN** 玩家 HP=20（整除边界）, **WHEN** `player_hp_changed(20, 100)` 触发, **THEN** 恰好 1 段点亮，不闪烁（`ceil(20/20)=1`，非临界）。

**AC-HUD-04** **GIVEN** 玩家 HP=0, **WHEN** `player_hp_changed(0, 100)` 触发, **THEN** 全部 5 段暗灭，无闪烁。

**AC-HUD-05** **GIVEN** 玩家 HP=21, **WHEN** `player_hp_changed(21, 100)` 触发, **THEN** 2 段点亮（`ceil(21/20)=2`），不触发闪烁。

### 元素2：Boss HP 连续血条

**AC-HUD-06** **GIVEN** Boss HP=300, max=1000, **WHEN** `boss_hp_changed(300, 1000, 1)` 触发, **THEN** 血条填充比例=0.3（30% 宽度）。

**AC-HUD-07** **GIVEN** `boss_max=0`（数据错误）, **WHEN** `boss_hp_changed(0, 0, 1)` 触发, **THEN** 血条显示空，不执行除法，控制台输出包含 "boss_max=0" 的警告日志，UI 不崩溃。

**AC-HUD-08** **GIVEN** `phase_threshold_pct=[0.6, 0.3]`, **WHEN** 战斗开始血条首次渲染, **THEN** 60% 和 30% 位置各出现一条静态垂直分隔线，存活期间位置不随 HP 移动。

**AC-HUD-09** **GIVEN** Boss HP 跨越 60% 阈值，phase 从 1 变 2, **WHEN** `boss_hp_changed` 触发, **THEN** 分隔线处颜色变化动画持续恰好 0.5s 后停止，保持新颜色静止。

### 元素3：预警进度条

**AC-HUD-10** **GIVEN** 无活跃预警, **WHEN** HUD 渲染每帧, **THEN** 预警进度条透明度=0，不可见。

**AC-HUD-11** **GIVEN** progress=0.75, window_open=false, **WHEN** `telegraph_updated(0.75, false, SWEEP)` 触发, **THEN** 进度条填充=0.75，颜色为 PRE_WINDOW 暗橙色。

**AC-HUD-12** **GIVEN** window_open=true, **WHEN** `telegraph_updated(1.0, true, HEAVY)` 触发, **THEN** 进度条填充=1.0，颜色切换为 WINDOW_OPEN 亮橙/白光。

**AC-HUD-13** **GIVEN** 系统处于 POST_WINDOW 状态, **WHEN** `telegraph_updated(0.5, false, LIGHT)` 触发, **THEN** 进度条填充=0.5，颜色为 POST_WINDOW 深红色。

**AC-HUD-14** **GIVEN** progress=1.5（超出范围）, **WHEN** `telegraph_updated(1.5, true, HEAVY)` 触发, **THEN** 填充被 clamp 至 1.0，不溢出血条边界。

### 元素4：反击窗口计时条 + 连击计数

**AC-HUD-15** **GIVEN** LIGHT, time_remaining=0.6s, state=COUNTER_WINDOW_OPEN, **WHEN** `counter_window_updated(2, 0.6, COUNTER_WINDOW_OPEN)` 触发, **THEN** 计时条填充=0.6，可见，非金色，连击显示「hit 2/3」。

**AC-HUD-16** **GIVEN** HEAVY, time_remaining=1.5s（满格）, state=COUNTER_WINDOW_OPEN, **WHEN** `counter_window_updated(1, 1.5, COUNTER_WINDOW_OPEN)` 触发, **THEN** 计时条填充=1.0（满格），可见。

**AC-HUD-17** **GIVEN** state=BONUS_STAGGER, **WHEN** `counter_window_updated(3, 0.8, BONUS_STAGGER)` 触发, **THEN** 计时条可见，颜色为金色。

**AC-HUD-18** **GIVEN** 全连击完成, **WHEN** `counter_full_combo_completed` 触发, **THEN** 「FULL COMBO」文字出现并闪烁，持续恰好 0.5s 后消失。

**AC-HUD-19** **GIVEN** state 从 COUNTER_WINDOW_OPEN 切换为关闭, **WHEN** 信号触发, **THEN** 计时条在 0.2s 内线性渐隐至透明度=0，不立即消失。

**AC-HUD-20** **GIVEN** state=IDLE（非活跃）, **WHEN** `counter_window_updated(0, 0.0, IDLE)` 触发, **THEN** 计时条不可见，不渲染连击计数文字。

### 跨元素叠加状态

**AC-HUD-21** **GIVEN** 玩家 HP=1（HP 条闪烁）且预警 window_open=true 同时活跃, **WHEN** 同帧两组信号均触发, **THEN** HP 条段 1 继续 0.5 Hz 闪烁，预警条同时可见显示 WINDOW_OPEN 白光，两组元素互不干扰。

**AC-HUD-22** **GIVEN** 反击窗口计时条 COUNTER_WINDOW_OPEN 可见，预警进度条 PRE_WINDOW 可见, **WHEN** 两信号在同一物理帧均触发, **THEN** 两条进度条同时渲染，颜色/填充/位置各自正确，无渲染错误或遮挡异常。

### Boss 战斗结束边界

**AC-HUD-23** **GIVEN** 战斗进行中所有流数据信号活跃, **WHEN** `boss_defeated` 信号触发, **THEN** HUD 停止响应后续 `telegraph_updated`、`boss_hp_changed`、`counter_window_updated`，相关元素冻结或隐藏，不再更新。

## Open Questions

1. **反击窗口计时条的世界坐标跟随实现**（owner: 引擎/UI 负责人）：CanvasLayer 坐标转换 vs Node2D 游戏世界层渲染——两种方案各有 trade-off，需在架构阶段决定（→ ADR）。

2. **预警进度条是否在 MVP 阶段提供 timing progress bar**（owner: 设计负责人）：格挡/预警系统 GDD 已注明此为开放设计决策（有教学价值但可能降低挑战性）。MVP HUD 实现前需确认。

3. **HUD 分辨率缩放策略**（owner: 引擎/UI 负责人）：当前基准 1920×1080。非标准分辨率（1280×720、2560×1440、21:9 超宽屏）下的 CanvasLayer stretch mode 和锚点规则需在垂直切片前确定。
