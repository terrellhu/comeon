# Interaction Pattern Library — 刃响 (Blade Echo)

> **Status**: In Design
> **Author**: user + ux-designer
> **Last Updated**: 2026-06-01
> **Template**: Interaction Pattern Library
> **Accessibility Tier**: Standard (per `design/accessibility-requirements.md`)

---

## Overview

本库定义刃响 HUD 和战斗反馈中复用的交互/显示模式。每个模式是一份契约：定义视觉形式、输入映射、反馈方式和无障碍要求。Stories 引用模式名（如 `[Pattern: State-Colored Indicator]`）而非重新发明，确保跨系统视觉一致性。

刃响是一款纯输出型 HUD 的 Boss Rush 动作游戏——HUD 元素不接受玩家直接输入（无可点击 UI 控件），它们是**显示与反馈**模式，而非**导航与输入**模式。所有玩家输入通过 InputMap 动作（战斗）处理，菜单导航在后续菜单 UX spec 中定义。

所有颜色引用 Art Bible 主色板。所有模式满足 Standard 段无障碍要求：色非依存（色 + 形状/位置/动作三重信号）、WCAG-AA 对比度、灰度可辨。

---

## Pattern Catalog

| # | 模式名 | 类别 | 使用系统 | 核心特征 |
|---|--------|------|----------|----------|
| 1 | Segmented Status Bar | Data Display | 玩家 HP | 离散段，整段熄灭 |
| 2 | Continuous Bar + Phase Ticks | Data Display | Boss HP | 连续填充 + 静态阶段标记线 |
| 3 | Contextual Timer Bar | Feedback | 格挡窗口、反击窗口 | 状况依存显示，倒计时填充 |
| 4 | State-Colored Indicator | Feedback | 预警进度 | 多态颜色 + 形状 + 尺寸三重信号 |
| 5 | Hit Counter Badge | Data Display | 连击计数 | "n/max" 文本计数 |
| 6 | Transient Confirmation Flash | Feedback | 全连击完成 | 短暂出现后自动消失 |
| 7 | Minimal Death Screen | Overlay | 即时重试 | 零 UI 元素，纯视觉序列 |
| 8 | World-Space HUD Element | Data Display | 反击条跟随玩家 | CanvasLayer 跟踪世界坐标 |

---

## Patterns

### 1. Segmented Status Bar

**Category**: Data Display
**Used In**: 玩家 HP 段数条（hud-system.md 元素 1）

**Description**: 将连续数值显示为离散的独立段。每段代表固定数量的资源（如 20 HP）。整段亮/暗，段内无渐变填充——玩家以「还剩几格」做战略决策，离散性比精度更有助于快速读取。

**Specification**:
- 段数由数据驱动（`player_hp_segments`，基准 5）
- 显示段数 = `ceil(current / per_segment)`，HP=0 时特判全暗（公式来自 health-damage-system.md）
- 段亮：枯骨白变体 `#C8BFA8`；段暗：虚空墨 `#0D0B1A`（亮度差 64%，灰度可辨）
- 段边框：枯骨白降调 `#6B6358`，1px 内框
- 临界状态（最后 1 段）：色 + 0.5 Hz 闪烁（无音效，避免战斗信息过载）
- 几何：直线 + 45° 倒角，无圆角（Art Bible Section 3）

**Accessibility (Standard)**:
- 色非依存：段亮/暗用亮度差（64%，> 40% 要求）+ 位置（从左填充）双重区分
- 临界状态：色 + 闪烁双重信号
- 灰度模式可辨（R-HUD-CHK-04）

**When to Use**: 离散资源池，玩家以「档位」做决策（HP、能量段、护盾层）
**When NOT to Use**: 需要精确数值读取的资源（用 Continuous Bar）；连续平滑变化更重要的场合

**Reference**: hud-system.md 公式 1；ASCII：`[▮▮▮▯▯]`（3/5 段）

---

### 2. Continuous Bar + Phase Ticks

**Category**: Data Display
**Used In**: Boss HP 连续血条（hud-system.md 元素 2）

**Description**: 连续填充血条，宽度比例 = `current / max`。血条内叠加静态垂直分隔线（phase ticks），标记 Boss 阶段阈值位置。分隔线战斗开始时一次性渲染，不随 HP 移动——它们是「里程碑」，让玩家预见「再一刀就到下一阶段」。

**Specification**:
- 填充比例 = `clamp(current / max, 0.0, 1.0)`（除零保护：max ≤ 0 时显示空条 + 错误日志）
- 当前血量填充：Boss 主色降饱和 15%（每 Boss 色板，如破钟 `#D9571A`）
- 已过阶段空区：虚空墨 + Boss 主色 5% 叠加（非纯黑）
- 阶段分隔线（正常）：枯骨白 `#E8DFC8`，1.5px
- 阶段分隔线（已压过）：哑光锈金 `#8B6914`（永久不可逆视觉标记）
- 压过瞬间高光：枯骨白高光 `#F5F0E8` 持续 0.3s（非霜白——霜白专属格挡成功）
- 阶段转换颜色过渡：0.5s 动画

**Accessibility (Standard)**:
- 阶段分隔线用位置（固定 X 坐标）+ 颜色（正常/已过用不同色）+ 厚度（1.5px）多重区分
- 已过阶段用「锈金」与正常「枯骨白」对比，灰度下亮度可辨

**When to Use**: 大型连续资源池需要精确读取 + 进度里程碑（Boss HP、长进度条）
**When NOT to Use**: 离散档位资源（用 Segmented Status Bar）

**Reference**: hud-system.md 公式 2；ASCII：`[████████┊███┊██     ]`（┊ = 阶段线）

---

### 3. Contextual Timer Bar

**Category**: Feedback
**Used In**: 反击窗口计时条（counter-attack-combo.md）；潜在格挡窗口可视化

**Description**: 仅在特定游戏状态期间可见的倒计时填充条。窗口打开时淡入，窗口关闭后 0.2s 渐隐。填充比例随剩余时间递减——玩家感知「还有多久」而非「过了多久」。状况依存可见性是核心：它不占用永久 HUD 空间。

**Specification**:
- 填充 = `clamp(time_remaining / window_max, 0.0, 1.0)`，满 = 窗口刚开，空 = 即将关闭
- 分母固定为基础窗口时长（即使进入 BONUS_STAGGER 也不切换分母，避免「跳回满格」误读）
- 正常态颜色：淡冷青白 `#8AB8C8`；边框：`#4A7888`
- BONUS_STAGGER 态：衰减锈金 `#C8A020`（颜色变化标示状态升级，非进度变化）
- 淡入：≤ 0.05s；淡出：0.2s 线性
- 可见条件：仅 COUNTER_WINDOW_OPEN / BONUS_STAGGER 期间

**Accessibility (Standard)**:
- 色非依存：填充比例（宽度）是主信号，颜色是辅助状态标识
- 反击条冷青（H197）与预警条暖橙（H35）色相差 160°，任何 Boss 色环境下不混淆
- BONUS_STAGGER 用颜色 + 状态文本（"FULL COMBO" flash）双重提示

**When to Use**: 时限机会窗口，玩家需感知剩余时间（反击窗口、格挡窗口、QTE）
**When NOT to Use**: 持久资源（用 Status Bar）；不需要时间压力感的显示

**Reference**: counter-attack-combo.md 公式 4；hud-system.md 元素 4

---

### 4. State-Colored Indicator

**Category**: Feedback
**Used In**: 预警进度指示器（parry-telegraph-system.md / hud-system.md 元素 3）

**Description**: 通过离散颜色态 + 形状信号 + 尺寸变化传达系统状态阶段。刃响最关键的反馈模式——「读懂才能赢」的核心 UI。三态（PRE_WINDOW / WINDOW_OPEN / POST_WINDOW）必须明确区分，玩家凭余光即可判断「现在格挡」。

**Specification**:
- 三态颜色（禁用血迹赤 `#7A1C2E`，红色仅用于已发生伤害）：
  - PRE_WINDOW：暗琥珀橙 `#8C5A1A`（L33）
  - WINDOW_OPEN 主色：高亮琥珀金 `#E8941A`（L51）+ 冷金白发光叠层 `#F5E8C0` alpha 0.65
  - POST_WINDOW：深暗红棕 `#4A1A0E`（L18）
- **三重信号叠加**（Standard 段强制要求）：
  1. 颜色变化（PRE L33 → WINDOW L51）
  2. 高度在 2 帧内从 h 膨胀至 h×1.4（「开锁」形态隐喻）
  3. 8×8px 菱形几何标记出现（WINDOW_OPEN 专属，非 8 点星——8 点星专属格挡成功确认）
- 与 Boss 橙光色相差 15–20°，发光偏「黄金」而非「火焰橙」，视觉隔离

**Accessibility (Standard)**:
- PRE→WINDOW 明度差仅 18%，**不足以独立识别**——必须叠加形状（菱形）+ 尺寸（1.4×）信号
- 色覚異常シミュレーター（Coblis）下 WINDOW 状态须可识别（R-HUD-CHK-05）
- 这是 Standard 段「色非依存」要求的标杆案例

**When to Use**: 离散状态阶段需要瞬时识别，色彩是主要但不充分的载体（预警、警报、状态机可视化）
**When NOT to Use**: 连续进度（用 Bar 模式）；色彩足以独立区分的低风险场合

**Reference**: parry-telegraph-system.md R-TEL-V1/V3；hud-system.md 公式 3 + Section 3

---

### 5. Hit Counter Badge

**Category**: Data Display
**Used In**: 连击计数器 "hit n/3"（counter-attack-combo.md / hud-system.md 元素 4）

**Description**: 文本计数徽章，显示「当前/上限」格式（如 "hit 2/3"）。与 Contextual Timer Bar 联动显示。让玩家感知连段进度，强化「打满连段」动机。

**Specification**:
- 格式："hit {current}/{max}"，max 来自数据（`max_combo_hits`=3）
- 字体：12px Serif，居中对齐
- 位置：反击窗口条上方 Y 偏移 -12px
- 可见条件：同 Contextual Timer Bar（COUNTER_WINDOW_OPEN / BONUS_STAGGER）
- 每击更新（`counter_window_updated.hit_count`）

**Accessibility (Standard)**:
- 数字文本本身色非依存（形状即信息）
- 文本对比度 WCAG-AA：枯骨白 on 深色背景 ≥ 4.5:1
- 与时间条位置物理分离，不依赖颜色区分

**When to Use**: 离散计数进度需要精确数值（连击数、波次、收集进度）
**When NOT to Use**: 连续数值（用 Bar）；不需要精确计数的氛围信息

**Reference**: hud-system.md 元素 4；counter-attack-combo.md AC-15

---

### 6. Transient Confirmation Flash

**Category**: Feedback
**Used In**: "FULL COMBO" 全连击反馈（counter-attack-combo.md / hud-system.md）

**Description**: 短暂出现后自动消失的确认反馈（文字/图标闪烁）。标记一次性成就时刻，不占用持久空间。出现即消失的瞬态性本身传达「特殊时刻」。

**Specification**:
- 持续时长：~0.5s（`full_combo_feedback_duration`，安全范围 0.3–0.8s）
- "FULL COMBO" 文字：锈金 `#C8A020`，Serif Bold 24px，无背景板
- 位置：玩家角色头顶 Y 偏移 -64px
- 音效：高频金属共振音（铸钟泛音）+ 0.1s 谐波尾音，UI 层低于打击音 4dB
- 触发：`counter_full_combo_completed` 信号

**Accessibility (Standard)**:
- 色 + 文本形状 + 音效三重信号
- 文本对比度 WCAG-AA
- **Reduce Motion** ON 时：保留文本显示但移除闪烁动画，改为静态淡入淡出

**When to Use**: 一次性成就/确认时刻，需庆祝感但不持久（连击完成、完美格挡、里程碑达成）
**When NOT to Use**: 持续状态（用 Indicator）；需要玩家确认/响应的提示（用模态——本游戏 MVP 无）

**Reference**: hud-system.md 元素 4 + 音效设计；counter-attack-combo.md AC-18 等价（HUD 侧）

---

### 7. Minimal Death Screen

**Category**: Overlay
**Used In**: 即时重试死亡屏幕（instant-retry-system.md，Art Bible Section 7.5）

**Description**: **零 UI 元素**的全屏过渡序列。绝对禁止任何按钮、文字、进度条、计数。它是「一页翻过去的书页」，不是「惩罚仪式」。玩家面对的是 Boss 相位符号，而非 UI。这是反模式的模式——刻意排除所有传统死亡屏幕 UI。

**Specification**:
- 4 段固定序列，总时长 1.5s（Art Bible 锁定）：
  - 0–200ms RED_FLASH：全屏 40% 红 `#CC2200` 瞬闪
  - 200–600ms FADE_TO_GREY：线性褪色至深灰 `#0A0A0C`（非纯黑）
  - 600–1200ms PHASE_SYMBOL：Boss 相位符号居中静止（霜白邻近色）
  - 1200–1500ms SYMBOL_FADE_OUT：符号线性淡出
- **绝对禁止项**：Retry 按钮 / 加载条 / 死亡计数 / 成就提示 / 任何提示文字 / "你死了"
- 任意帧任意键 → 立即跳至 1500ms 重开（无「已跳过」反馈）
- 自动恢复（无需输入）

**Accessibility (Standard)**:
- 跳过支持键盘任意键 / 手柄任意键 / 鼠标点击
- **Reduce Motion** ON 时：RED_FLASH (0.2s) 替换为黑画面（削减闪光，防光敏性癫痫风险）
- 相位符号缺失时安全降级（纯灰屏 0.9s），不崩溃

**When to Use**: 沉浸式失败过渡，设计哲学拒绝惩罚性 UI（「死亡是教师」类游戏）
**When NOT to Use**: 需要玩家做选择的死亡屏幕（重试/退出/读档——本游戏 MVP 不需要）；需展示统计的场合

**Reference**: instant-retry-system.md Visual/Audio Requirements；Art Bible Section 7.5

---

### 8. World-Space HUD Element

**Category**: Data Display
**Used In**: 反击窗口计时条跟随玩家（hud-system.md 元素 4 定位）

**Description**: 渲染在 CanvasLayer（屏幕空间）但位置跟踪游戏世界中某个实体（玩家角色）的 HUD 元素。结合了「始终清晰渲染（不受世界摄像机缩放影响）」和「空间关联（信息附着在它所描述的对象上）」两个优点。

**Specification**:
- 渲染层：CanvasLayer（屏幕坐标，不受摄像机变换影响）
- 位置：每帧 = 世界坐标 → 屏幕坐标转换 + 偏移量（如玩家头顶 Y -48px）
- 实现方案待 ADR（CanvasLayer 坐标转换 vs Node2D 游戏世界层）——见 hud-system.md Open Question 1
- 性能：每帧坐标转换须 O(1)，无每帧分配

**Accessibility (Standard)**:
- 位置跟随玩家，视线自然聚焦区域，减少眼动负担
- 不依赖颜色——位置本身是信息（「这是你的反击窗口」）

**When to Use**: HUD 信息需空间关联到世界实体，但又要保持清晰渲染（角色头顶状态、敌人血条、交互提示）
**When NOT to Use**: 全局信息（用固定屏幕区域）；纯世界空间特效（用 Node2D 不转屏幕坐标）

**Reference**: hud-system.md 元素 4 + UI Requirements；架构 QQ-04

---

## Gaps & Patterns Needed

MVP 阶段当前 8 个模式覆盖全部已设计系统的 UI 需求。以下为**未来阶段**预期需要但尚未定义的模式：

| 预期模式 | 触发阶段 | 备注 |
|----------|----------|------|
| Menu Navigation Pattern | 垂直切片（主菜单 / 暂停菜单） | 键盘 Tab + 手柄 D-Pad 焦点导航；需独立 menu UX spec |
| Modal Dialog Pattern | 垂直切片（设置 / 确认对话框） | 本 MVP 无模态；设置系统设计时定义 |
| Narrative Reveal Pattern | 垂直切片（叙事解锁） | Boss 击败后 HD 插画 + 文字呈现 |
| Tooltip / Hint Pattern | Alpha（能力解锁提示） | 进阶系统需要 |

---

## Open Questions

1. **World-Space HUD 实现方案**（owner: 引擎/UI）：CanvasLayer 坐标转换 vs Node2D 游戏世界层——待架构 ADR（QQ-04）。影响 Pattern 8 的实现规格。

2. **格挡窗口是否提供 timing progress bar**（owner: 设计）：parry-telegraph-system.md 标注为开放设计决策（有教学价值但可能降低挑战性）。若提供，复用 Pattern 3 (Contextual Timer Bar) + Pattern 4 (State-Colored Indicator)。垂直切片玩测决定。

3. **玩家旅程地图未创建**：模板见 `.claude/docs/templates/player-journey.md`。当前模式库基于 GDD UI 需求推导，未结合玩家情绪旅程上下文。建议垂直切片前补充。

---

## Related Documents

- [HUD System GDD](../gdd/hud-system.md) — 模式的主要需求来源
- [Parry/Telegraph System GDD](../gdd/parry-telegraph-system.md) — State-Colored Indicator 三重信号要求
- [Counter Attack Combo GDD](../gdd/counter-attack-combo.md) — Timer Bar / Hit Counter / Confirmation Flash
- [Instant Retry System GDD](../gdd/instant-retry-system.md) — Minimal Death Screen
- [Accessibility Requirements](../accessibility-requirements.md) — Standard 段无障碍规格（每个模式遵循）
- [Art Bible](../art/art-bible.md) — 颜色规格 + Section 3 几何规则 + Section 7.5 死亡屏幕
