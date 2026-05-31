# Cross-GDD Review Report v2 — 刃响 (Blade Echo)

**Date**: 2026-06-01 (same-day follow-up to v1)
**Reviewer**: /review-all-gdds (post-fix re-verification)
**GDDs Reviewed**: 7 系统 GDD + game-concept + systems-index
**Supersedes**: `design/gdd/gdd-cross-review-2026-06-01.md` (v1) — kept as audit trail
**Trigger**: 用户在 v1 报告后同会话修复了全部 3 阻塞项 + 4 warnings，请求重新验证

---

## Resolution Verification

v1 报告标记 3 个 BLOCKING + 4 个 WARNING。本次重 review 确认全部修复：

| ID | 项目 | v1 状态 | v2 验证 |
|---|---|---|---|
| B-01 | health-damage / counter-attack 伤害公式冲突 | 🔴 BLOCKING | ✅ health-damage 公式 2 重构为引用 counter-attack-combo（注明所有权），AC 改为 [16, 22, 32] / 70 HP |
| B-02 | combo multiplier Tuning Knob 所有权冲突 | 🔴 BLOCKING | ✅ health-damage Tuning Knobs 中的 `combo_position_multipliers` 行已删除 |
| B-03 | player-controller 缺失 `attack_input_pressed` 信号 | 🔴 BLOCKING | ✅ InputMap 新增 `attack`；Core Rules 第 11 条；Interactions 表 + Dependencies 表 + Cross-References + 3 个新 AC |
| W-01 | parry-telegraph Formula 3 枚举含已移除 STAGGERING | ⚠️ WARNING | ✅ 枚举已改为 {IDLE, TELEGRAPHING} |
| W-02 | boss-state-machine 双向一致性备注过时 | ⚠️ WARNING | ✅ ❗ → ✅，文字已更新 |
| W-03 | boss-state-machine 命名 `phase_hp_threshold` 不一致 | ⚠️ WARNING | ✅ 改为 `phase_threshold_pct` |
| W-04 | parry-telegraph Visual/Audio 表用「STAGGERING」陈旧 | ⚠️ WARNING | ✅ 改为「Boss STAGGERED 期间（反击连段系统管理）」 |

**v1 遗漏 → v2 新发现的额外陈旧引用**（同时修复）：

| ID | 项目 | 修复 |
|---|---|---|
| W-05 | health-damage Open Questions 仍引用 `combo_position_multipliers` 旧命名 | ✅ 改为 `multiplier[n]`（counter-attack-combo 权威命名） |
| W-06 | parry-telegraph 4 处遗漏 STAGGERING 引用（edge cases + UI Requirements + AC-15） | ✅ 全部改为「Boss STAGGERED 期间（反击连段系统状态/管理）」；AC-15 重写为测试 `parry_succeeded` payload 的 `attack_type` 传递正确性 |
| W-07 | counter-attack-combo 两处「❗ 待定」注释指 parry-telegraph 未修订 | ✅ 改为「✅ 已完成（2026-06-01）」 |

---

## Phase 2: Cross-GDD Consistency (re-check)

**2a 双向依赖**：B-03 修复后，player-controller ↔ counter-attack-combo 双向一致。Interactions 和 Dependencies 表互相引用。✅

**2b 规则矛盾**：B-01/B-02 修复后伤害公式单一权威源（counter-attack-combo），health-damage 改为引用。无新矛盾发现。✅

**2c 陈旧引用**：W-01/W-04/W-05/W-06/W-07 修复后，grep 验证所有 GDD 文件无残留陈旧引用（只在 v1 审计报告中存在，正确保留）。✅

**2d 所有权冲突**：B-02 修复后无双重所有权。✅

**2e 公式兼容性**：counter combo 70 HP / 14-15 反击次数 / Boss 1000 HP — 全部一致。Player 5-40 伤害范围 vs 100 HP — 一致。✅

**2f AC 一致性**：health-damage AC-counter 与 counter-attack-combo AC-02/02b/03 现在数值一致（16/22/32 / 70 HP）。✅

---

## Phase 3: Game Design Holism (re-check)

- **3a 进阶循环竞争**：MVP 单循环，无变化 ✅
- **3b 关注预算**：3 个主动系统（读预警、按格挡、执行连击）；B-03 修复后 attack 输入纳入主动系统计数 ✅
- **3c 支配性策略**：MVP 仅 parry+counter，无 dodge ✅
- **3d 经济循环**：MVP 无经济 ✅
- **3e 难度曲线**：单 Boss MVP ✅
- **3f 支柱对齐**：所有 7 系统对齐 Pillar 1/2/4；Pillar 3「画面即叙事」由 Art Bible 承载（v1 已识别为非阻塞 W-D1）✅
- **3g 玩家幻想一致性**：「精准读懂模式 + 低摩擦学习」单一身份贯穿所有系统 ✅

---

## Phase 4: Cross-System Scenario Walkthrough (re-check)

**关键变化**：Scenario A 在 v1 是阻塞场景（B-03 导致 attack_input_pressed 无定义）。v2 验证 B-03 修复后链路打通：

**Scenario A (re-verified)**: 完美格挡 → 全连击 → Boss 硬直恢复
1. Boss SM idle_timer → attack_telegraphed(HEAVY, 25)
2. parry-telegraph → TELEGRAPHING；HUD 渲染进度条
3. 玩家按 parry → controller emit parry_input_pressed → controller → PARRYING
4. parry-telegraph WINDOW_OPEN → path A → parry_succeeded(HEAVY)
5. counter-attack 进 COUNTER_WINDOW_OPEN (1.5s)；Boss SM 进 STAGGERED
6. **玩家按 attack 键 → controller 检测到 attack（rule 11）→ emit attack_input_pressed** ✅
7. counter-attack 收信号 → 不在冷却 → 执行 hit 1：apply_damage(BOSS, 16)，cooldown 0.25s
8. 玩家按 attack 2 次（间隔 ≥ 0.25s）→ hit 2 (22) → hit 3 (32) → counter_full_combo_completed → BONUS_STAGGER (0.75s)
9. BONUS_STAGGER timer 耗尽 → counter-attack emit stagger_ended → Boss SM 进 IDLE，sequence_index++
10. Boss SM idle_timer 启动，新一轮循环

完整循环可执行。✅

**Scenarios B/C/D/E**：未受新修复影响，v1 验证结论保留。

---

## Outstanding Items

**W-D1（v1 已识别，仍为非阻塞）**：Pillar 3「画面即叙事」在 MVP 系统层无承载，由 Art Bible 承载。MVP 玩测时需验证视觉执行能传达此支柱。**不阻塞架构推进。**

**S-02（v1 已识别，仍为非阻塞）**：parry_failed 与 player_died 同帧顺序未定义。建议在 ADR（信号路由）阶段决定。**不阻塞架构推进**，已记录在 instant-retry GDD Open Questions 中相邻。

---

## Verdict: ✅ PASS

- 0 blocking issues
- 0 warnings outstanding（仅剩 2 项已识别且明确非阻塞的设计观察）
- 所有 v1 flagged GDDs 修订完成并经 grep 验证

**进入 Technical Setup 阶段无 cross-GDD 一致性障碍。**

下一步建议路径：
1. `/gate-check systems-design` 重新跑（应该返回干净 PASS）
2. 进入 Technical Setup → `/create-architecture` 生成架构蓝图

---

## 审查范围说明

- ✅ 全部 7 MVP 系统 GDD 已修订并 grep 验证（无残留陈旧引用）
- ✅ Entity registry 未变更
- ✅ Phase 2/3/4 全部检查项执行（重点验证修复点）
- ✅ 新发现的 3 项额外陈旧引用（v1 遗漏）已一并修复
