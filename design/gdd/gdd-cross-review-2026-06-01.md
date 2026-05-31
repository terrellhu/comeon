# Cross-GDD Review Report — 刃响 (Blade Echo)

**Date**: 2026-06-01
**Reviewer**: /review-all-gdds
**GDDs Reviewed**: 7 系统 GDD + game-concept + systems-index
**Systems Covered**: health-damage, player-controller, parry-telegraph, boss-state-machine, counter-attack-combo, instant-retry, hud
**Entity Registry**: design/registry/entities.yaml (32 constants loaded)

---

## Consistency Issues

### 🔴 Blocking

#### B-01 — Counter Combo 伤害公式存在矛盾（多 GDD + AC 数值不一致）

- `design/gdd/health-damage-system.md` 公式 2：`combo_position_multipliers = [1.0, 1.25, 1.5]` → 第 1 击 20、第 2 击 25、第 3 击 30，合计 **75 HP**
- `design/gdd/counter-attack-combo.md` 公式 1：`multiplier[n] = [0.8, 1.1, 1.6]` → 第 1 击 16、第 2 击 22、第 3 击 32，合计 **70 HP**

两个 GDD 的 Acceptance Criteria 都明确写死了不同的预期值：

- `health-damage-system.md` AC：「GIVEN counter_base_damage=20，完成 3 连击反击序列... THEN 第 1 击减 20.0，第 2 击减 25.0，第 3 击减 30.0，合计 75.0 HP」
- `counter-attack-combo.md` AC-02/02b/03：「apply_damage(BOSS, 16.0)... 22.0... 32.0」

**后果**：实施时单元测试必然有一个会失败。两者必须协调到同一数值。

**建议**：反击连段系统是该乘数的权威所有者（系统名义上拥有此机制）。health-damage 应改为引用（公式形式 + 引用 counter-attack 的乘数表），而非直接定义。

#### B-02 — Tuning Knob 所有权冲突（B-01 的根因）

- `health-damage-system.md` Tuning Knobs：`combo_position_multipliers | [1.0, 1.25, 1.5]`
- `counter-attack-combo.md` Tuning Knobs：`counter_damage_multiplier_1/2/3 | 0.8 / 1.1 / 1.6`

两个 GDD 都把"反击连段每击伤害倍率"列为自己的可调旋钮，且值不同。解决 B-01 同时解决 B-02。

**建议**：保留 counter-attack-combo 的所有权（命名更精细、专门系统），删除 health-damage 的 Tuning Knob 行并改为「引用反击连段系统」。

#### B-03 — `attack_input_pressed` 信号未在玩家控制器定义

- `counter-attack-combo.md` Dependencies：「玩家角色控制器 → 本系统（触发）硬依赖——玩家攻击输入是连击激活的来源 `attack_input_pressed` 信号」
- `counter-attack-combo.md` AC-02 实际依赖此信号触发反击
- `player-controller-system.md` 列出的 InputMap 动作（第 38-40 行）仅为：`move_left`、`move_right`、`jump`、`parry`、`dodge`
- player-controller 的 Interactions、States and Transitions、Acceptance Criteria 都没有提到 `attack` 动作或 `attack_input_pressed` 信号

**后果**：反击连段系统在实施时找不到输入触发源，整个连击循环无法启动。

**建议**：在 `player-controller-system.md` 补充：
1. InputMap 动作列表新增 `attack`
2. 新增信号 `attack_input_pressed`
3. Interactions 表新增「反击连段系统」行（控制器 → 本系统触发）
4. States and Transitions 表为相应状态补充 `attack` 输入路由（IDLE/RUNNING/AIRBORNE 接受 attack？是否进入新状态？是否仅在 COUNTER_WINDOW 期间响应？这些是设计决策需澄清）
5. Acceptance Criteria 新增对应 AC

### ⚠️ Warnings

#### W-01 — parry-telegraph Formula 3 的 system_state 枚举包含已移除的 STAGGERING

- `parry-telegraph-system.md` 第 190 行（Formula 3 变量表）：`system_state | enum | {IDLE, TELEGRAPHING, STAGGERING}`
- 同文档 States and Transitions 表只有 IDLE 和 TELEGRAPHING，明确注释「STAGGERING 状态已移除（反击连段系统 GDD 架构变更）」

该 GDD 内部自相矛盾。30 秒级编辑：把 STAGGERING 从枚举中删除。

#### W-02 — boss-state-machine 双向一致性备注已过时

- `boss-state-machine.md` 第 238 行：「伤害/生命系统 GDD **应**在其 Dependencies 中将本系统列为 `boss_phase_changed` / `boss_defeated` 的订阅方（**需在伤害/生命 GDD 补充**）❗」
- 实际 `health-damage-system.md` Interactions 表第 78-79 行**已列**：「Boss 状态机 ← 订阅信号 订阅 boss_phase_changed」「即时重试系统 ← 订阅信号 订阅 player_died」

30 秒级编辑：把第 238 行的「❗」改为「✅」并更新文字为"已确认"。

#### W-03 — boss-state-machine Tuning Knob 命名与 health-damage 不一致

- `boss-state-machine.md` Tuning Knobs（第 248 行）：`阶段 HP 阈值（phase_hp_threshold）`
- `health-damage-system.md` 公式 3 / Tuning Knobs：`phase_threshold_pct`

两者指同一字段。**建议**：统一为 `phase_threshold_pct`（health-damage 是 HP 系统所有者）。30 秒级编辑。

#### W-04 — parry-telegraph Visual/Audio 表述使用了陈旧状态名

- `parry-telegraph-system.md` 第 287 行 Visual/Audio Requirements 表：「**Boss 硬直中（STAGGERING）**」
- STAGGERING 已被移除；该状态如今由反击连段系统的 COUNTER_WINDOW_OPEN / BONUS_STAGGER 管理

语义可懂但用词陈旧。**建议**改为「Boss STAGGERED 期间（反击连段系统管理）」。30 秒级编辑。

---

## Game Design Issues

### Blocking

**无。** 所有 MVP 系统都明确服务设计支柱，无反支柱违规，无支配性策略，玩家关注预算合理（战斗中 3 个主动系统：读预警、按格挡、执行连击）。

### Warnings

#### W-D1 — Pillar 3「画面即叙事」在 MVP 没有承载系统

- 4 个支柱中只有 3 个被 MVP 系统 GDD 明确实现（Pillar 1、2、4）。Pillar 3 由 Art Bible 和 Boss 美术承载，但 MVP 没有 GDD 直接为其负责。
- 这是**有意识的设计决策**（叙事解锁系统在 VS 层级），但需要记录为感知风险——确保 MVP 玩测时仍能感受到「画面即叙事」（完全依赖 Art Bible 的视觉执行 + Boss 占位美术的质量）。

**不阻塞架构推进。** 仅作为可见性提示给 art-director 和后续 vertical-slice 阶段。

---

## Cross-System Scenario Issues

**Scenarios walked: 5**
- A: 完美格挡 → 全连击 → Boss 硬直恢复
- B: 连击过程中跨越 Boss 阶段阈值（HP 60% 触发 phase 2）
- C: 连击致命一击（boss_defeated 在 hit 2/3 触发）
- D: 多阶段阈值单次伤害级联（理论 VS 阶段场景）
- E: 致命攻击落地，parry_failed 与 player_died 同帧

### 🔴 Blockers

#### S-01 — Scenario A 全程被 B-03 阻塞

完整循环：`parry_succeeded → COUNTER_WINDOW_OPEN → 玩家按攻击键 → 连击执行 → ... → stagger_ended`

由于 `attack_input_pressed` 信号无定义（B-03），第 4 步在 MVP 设计阶段就是断的。整个反击连段系统无输入触发源，无法实施。

**与 B-03 同一根因，修复方案相同。**

### ⚠️ Warnings

#### S-02 — Scenario E 中 parry_failed 与 player_died 同帧事件顺序未定义

当攻击落地导致 player_died：
1. `parry-telegraph` 在同一帧调用 `apply_damage(PLAYER, x)` 并发出 `parry_failed(type)`（顺序未规定）
2. `health-damage` 处理 apply_damage 时 HP ≤ 0 → 立即发出 `player_died`
3. 同帧 `parry_failed`（Boss SM 可选命中反应）和 `player_died`（控制器→DEAD、instant-retry→死亡屏幕、parry-telegraph→reset to IDLE）的处理顺序未规定。

Boss SM 此时收到 parry_failed 仅触发可选动画叠加（不改状态），所以实际影响有限。但若 instant-retry 暂停游戏逻辑时间发生在 Boss SM 的 parry_failed 反应动画启动之前，可能产生半帧的视觉残留。

**建议**：在 `parry-telegraph-system.md` Edge Cases 中新增一条："如果 apply_damage 同帧触发 player_died，事件顺序为 ① apply_damage → ② parry_failed → ③（异步）player_died handler。" 提示 ADR 阶段确定信号路由的同步性。

### ℹ️ Info

#### S-03 — Scenario C 中 HUD 可能短暂显示「hit 2/3」冻结于死亡动画期间

当第 2 击致命（HP 30 → 8 → -22 钳制至 0），counter-attack 收 boss_defeated → 立即设状态为 IDLE，但 HUD AC-23 规定它停止响应 counter_window_updated。HUD 元素的最后一帧状态可能停留在「hit 2/3」直到 0.2s 渐隐。

极低优先级 cosmetic。**无需改动 GDD**；这是 HUD 设计的预期行为（counter_bar_fade_out_duration = 0.2s）。

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `counter-attack-combo.md` | 与 health-damage 的伤害公式数值冲突（权威源） | Consistency | Blocking |
| `health-damage-system.md` | 与 counter-attack 的伤害公式数值冲突 + Tuning Knob 所有权冲突 | Consistency | Blocking |
| `player-controller-system.md` | 缺失 `attack` InputMap 动作 + `attack_input_pressed` 信号定义 | Consistency | Blocking |
| `parry-telegraph-system.md` | Formula 3 枚举包含已移除 STAGGERING；Visual/Audio 表述陈旧 | Consistency | Warning |
| `boss-state-machine.md` | 双向一致性备注过时；Tuning Knob 命名 `phase_hp_threshold` 与 health-damage 不一致 | Consistency | Warning |

---

## Verdict: 🔴 FAIL

### 3 个阻塞项必须在进入架构阶段前解决

1. **B-01 + B-02 统一修复**（影响 health-damage 和 counter-attack-combo）：
   - 删除 `health-damage-system.md` Tuning Knobs 中的 `combo_position_multipliers` 行
   - 修改 `health-damage-system.md` 公式 2，去除内嵌的乘数表，改为「乘数表见 `counter-attack-combo.md` 公式 1」引用
   - 修改 `health-damage-system.md` AC（合计 75 HP 那条），改为引用 counter-attack 定义的实际值（合计 70 HP）
   - 反击连段系统的 [0.8, 1.1, 1.6] 数值不动
2. **B-03 修复**（影响 player-controller）：
   - InputMap 动作列表新增 `attack`
   - 新增信号 `attack_input_pressed`
   - Interactions 表新增「反击连段系统」行
   - States and Transitions 表澄清 attack 输入路由（设计决策：IDLE/RUNNING/AIRBORNE 是否响应？还是仅在 COUNTER_WINDOW 期间响应？counter-attack-combo 当前的设计假定控制器无条件转发，由 counter-attack 系统门控；建议保持该简单分工）
   - 补充对应 AC
3. **S-01 自动解决**（B-03 修复后链路打通）

### 修复后建议路径

1. 修复完后运行 `/design-review design/gdd/counter-attack-combo.md` 和 `/design-review design/gdd/player-controller-system.md` 验证修订
2. 运行 `/gate-check systems-design` 重新验证门关（预期 PASS 或 CONCERNS）
3. 进入 Technical Setup 阶段：开始写 ADRs

### 4 项 Warning 可作为低优先批量修复

W-01、W-02、W-03、W-04 都是 30 秒级编辑。可在同一会话内一并修复，也可推迟到下一次任何修订时顺手处理。

---

## 审查范围说明

- ✅ 全文读取 7 MVP 系统 GDD + game-concept + systems-index
- ✅ Entity registry 加载（32 constants，无 entities/items/formulas 条目）
- ✅ Phase 2（一致性）2a–2f 全部检查项执行
- ✅ Phase 3（设计理论）3a–3g 全部检查项执行
- ✅ Phase 4 跨系统场景走查 5 个场景
- ⚠️ Pillar 3「画面即叙事」的承载评估依赖 Art Bible（design/art/art-bible.md），本审查仅检查系统 GDD 层面

