# Session State — 刃响 (Blade Echo)

*Updated: 2026-06-02*

## Session Extract — /dev-story 2026-06-02 (health-damage story-001)
- Story: production/epics/health-damage-system/story-001-hp-initialization.md — HP Initialization and BossData Contract
- Files changed: game/scripts/core/health_damage_system.gd (new, 93 lines), game/tests/unit/health_damage/test_hp_initialization.gd (new, 11 test functions)
- Test written: game/tests/unit/health_damage/test_hp_initialization.gd (11 functions — 5×AC-1 player HP, 4×AC-2 boss HP, 2×AC-3 no literals)
- Notes: get_displayed_segments() deferred to Story 006 (out of scope); _ready() not added (production wiring left to scene setup or Story 002); AC-1 HUD segment test computes formula inline since method not yet implemented
- Blockers: None
- KEY REMINDER: new class_name scripts need class-cache regen before headless GUT sees HealthDamageSystem. Run: `C:\game\godot\Godot_v4.6.2-stable_win64_console.exe --headless --editor --quit --path C:\game\comeon\game`
- Next: /code-review game/scripts/core/health_damage_system.gd game/tests/unit/health_damage/test_hp_initialization.gd then /story-done production/epics/health-damage-system/story-001-hp-initialization.md

## Session Extract — /story-done 2026-06-02 (health-damage story-001)
- Verdict: COMPLETE
- Story: production/epics/health-damage-system/story-001-hp-initialization.md — HP Initialization and BossData Contract
- Tech debt logged: None
- Next recommended: Story 002 — Player Damage Application and Invulnerability Window

## Session Extract — /dev-story 2026-06-02 (health-damage story-002)
- Story: production/epics/health-damage-system/story-002-player-damage-and-invuln.md — Player Damage Application and Invulnerability Window
- Files changed: game/scripts/core/health_damage_system.gd (modified — _invuln_timer, _physics_process, apply_damage, get_invuln_timer), game/tests/unit/health_damage/test_player_damage_invuln.gd (new, 15 functions), game/tests/helpers/mock_event_bus.gd (modified — additive tracking fields; scope deviation, backward-compatible)
- Test written: game/tests/unit/health_damage/test_player_damage_invuln.gd (15 tests — 26/26 total suite pass)
- Blockers: None. Scope deviation on mock_event_bus.gd — additive only, Story 001 regression-free.
- Next: /code-review game/scripts/core/health_damage_system.gd game/tests/unit/health_damage/test_player_damage_invuln.gd then /story-done production/epics/health-damage-system/story-002-player-damage-and-invuln.md

## Session Extract — /story-done 2026-06-02 (health-damage story-002)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/health-damage-system/story-002-player-damage-and-invuln.md — Player Damage Application and Invulnerability Window
- Tech debt logged: None (advisory test gaps noted in completion notes only)
- Next recommended: Story 003 — Player Death Detection and HP Clamping

## Session Extract — /dev-story 2026-06-02 (health-damage story-003)
- Story: production/epics/health-damage-system/story-003-player-death.md — Player Death Detection and HP Clamping
- Files changed: game/scripts/core/health_damage_system.gd (modified — death check in apply_damage), game/tests/unit/health_damage/test_player_death.gd (new, 10 functions), game/tests/helpers/mock_event_bus.gd (modified — player_died_call_count tracking added)
- Test written: game/tests/unit/health_damage/test_player_death.gd (10 tests — 36/36 total suite pass)
- Blockers: None. mock_event_bus.gd modified again (additive, backward-compatible; same pattern as Story 002).
- Next: /code-review game/scripts/core/health_damage_system.gd game/tests/unit/health_damage/test_player_death.gd then /story-done production/epics/health-damage-system/story-003-player-death.md

## Session Extract — /story-done 2026-06-02 (health-damage story-003)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/health-damage-system/story-003-player-death.md — Player Death Detection and HP Clamping
- Tech debt logged: None (advisory edge cases noted in completion notes only — post-invuln-expiry + zero-invuln duplicate player_died)
- Next recommended: Story 004 (Healing) or Story 006 (HUD Segment Formula) — both independent; Story 005 (Boss HP) also ready

## Current Task

**Pre-Production 阶段**（2026-06-01 进入）— Technical Setup → Pre-Production 门关 CONCERNS（无阻塞）通过，已写 stage.txt。
下一步推荐序：① 协调 CONFLICT-01 → ② ✅ /create-control-manifest → ③ ✅ /vertical-slice（PROCEED）→ ④ ✅ /ux-design hud → ⑤ ✅ /ux-review hud（APPROVED）→ ⑥ 🔄 /create-epics（Foundation 完成）→ ⑦ /create-stories 各 epic → ⑧ /create-epics layer:core → ⑨ /sprint-plan
HUD spec：design/ux/hud.md（APPROVED）

## Session Extract — /dev-story 2026-06-02 (bossdata story-003)
- Story: production/epics/bossdata-resource-architecture/story-003-mvp-boss-asset.md — MVP Boss Data Asset + GUT Factory Proof
- Files changed: game/data/bosses/boss_01.tres (filled), game/tests/unit/bossdata-resource-architecture/test_boss_factory.gd (new, 6 functions)
- Verified: Godot headless load OK (phases=2, max_hp=1000, threshold=[0.6,0.3]); GUT 6/6 pass; AC-5 grep clean
- Blockers: None
- Next: /code-review game/data/bosses/boss_01.tres game/tests/unit/bossdata-resource-architecture/test_boss_factory.gd then /story-done production/epics/bossdata-resource-architecture/story-003-mvp-boss-asset.md

## Session Extract — /dev-story 2026-06-02 (health-damage story-004)
- Story: production/epics/health-damage-system/story-004-player-healing.md — Healing Application and Over-Heal Guard
- Files changed: game/scripts/core/health_damage_system.gd (modified — apply_healing method added + amount guard), game/tests/unit/health_damage/test_player_healing.gd (new, 7 test functions)
- Test written: game/tests/unit/health_damage/test_player_healing.gd (7/7 PASS; code review added 2 tests: negative guard + invuln invariant)
- Notes: /code-review found BLOCKING (_system: Node → HealthDamageSystem), 2 WARNINGs (missing guard, missing tests) — all fixed before APPROVED
- Blockers: None

## Session Extract — /story-done 2026-06-02 (health-damage story-004)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/health-damage-system/story-004-player-healing.md — Healing Application and Over-Heal Guard
- Tech debt logged: None (ADVISORY guard deviation noted in story completion notes only)
- Next recommended: Story 006 (HUD Segment Formula) or Story 007 (Retry HP Reset) — both independent

## Session Extract — /dev-story 2026-06-02 (health-damage story-006)
- Story: production/epics/health-damage-system/story-006-hud-segment-formula.md — HUD Segment Count Formula
- Files changed: game/scripts/core/health_damage_system.gd (modified — get_displayed_segments() + init_battle assert), game/tests/unit/health_damage/test_hud_segments.gd (new, 5 test functions)
- Test written: game/tests/unit/health_damage/test_hud_segments.gd (5 tests — AC-1 above boundary, AC-2 integer boundary, AC-3 zero guard, AC-4 trace HP, AC-5 full HP)
- Blockers: None

## Session Extract — /story-done 2026-06-02 (health-damage story-006)
- Verdict: COMPLETE
- Story: production/epics/health-damage-system/story-006-hud-segment-formula.md — HUD Segment Count Formula
- Tech debt logged: None (OUT OF SCOPE advisory in completion notes only)
- Next recommended: Story 007 (Retry HP Reset Contract) — Integration type, M estimate

## Session Extract — /story-done 2026-06-02 (health-damage story-005)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/health-damage-system/story-005-boss-hp-phases-defeat.md — Boss HP, Phase Detection, and Defeat
- Tech debt logged: None (advisory deviations in completion notes only)
- Next recommended: Story 004 (Player Healing) or Story 006 (HUD Segment Formula) — both independent; Story 007 (retry reset) now unlocked

## Session Extract — /dev-story 2026-06-02 (health-damage story-005)
- Story: production/epics/health-damage-system/story-005-boss-hp-phases-defeat.md — Boss HP, Phase Detection, and Defeat
- Files changed: game/scripts/core/health_damage_system.gd (modified — _is_boss_defeated, _entered_phases, BOSS branch in apply_damage, _check_phase_transitions()), game/tests/helpers/mock_event_bus.gd (modified — boss tracking fields/callbacks additive), game/tests/unit/health_damage/test_boss_hp_phases.gd (new, 18 test functions), game/tests/unit/health_damage/test_hp_initialization.gd (modified — phase starts at 1)
- Test written: game/tests/unit/health_damage/test_boss_hp_phases.gd (18/18 PASS; 126/131 total suite pass, 5 pre-existing pending)
- Notes: current_boss_phase initializes to 1 (not 0) per AC-1/AC-3 requirements; _check_phase_transitions() iterates all thresholds in single pass for multi-threshold crossing
- Blockers: None
- Next: /code-review game/scripts/core/health_damage_system.gd game/tests/unit/health_damage/test_boss_hp_phases.gd then /story-done production/epics/health-damage-system/story-005-boss-hp-phases-defeat.md

## Session Extract — /story-done 2026-06-02 (bossdata story-003)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/bossdata-resource-architecture/story-003-mvp-boss-asset.md — MVP Boss Data Asset + GUT Factory Proof
- Tech debt logged: None
- Next recommended: BossData Resource Architecture epic complete — all 3 stories Done; Core and Feature epics unlocked

## Session Extract — /story-done 2026-06-02 (bossdata story-002)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/bossdata-resource-architecture/story-002-boss-data-loader.md — BossDataLoader — Load and Validate
- Tech debt logged: None (advisory deviations documented in story completion notes only)
- Next recommended: bossdata story-003 (MVP Boss Asset — boss_01.tres)

## Session Extract — /dev-story 2026-06-02 (bossdata story-002)
- Story: production/epics/bossdata-resource-architecture/story-002-boss-data-loader.md — BossDataLoader — Load and Validate
- Files changed: game/scripts/foundation/boss_data_loader.gd (new), game/tests/unit/bossdata-resource-architecture/test_boss_data_loader.gd (new)
- Test written: game/tests/unit/bossdata-resource-architecture/test_boss_data_loader.gd (13 test functions)
- Blockers: None. Assert-crash tests (AC-2 empty attack_sequence, AC-5 non-descending threshold) marked pending() — GDScript assert() cannot be caught in GUT runner
- Next: /code-review game/scripts/foundation/boss_data_loader.gd game/tests/unit/bossdata-resource-architecture/test_boss_data_loader.gd then /story-done production/epics/bossdata-resource-architecture/story-002-boss-data-loader.md

## Session Extract — /story-done 2026-06-02 (bossdata story-001)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/bossdata-resource-architecture/story-001-bossdata-resources.md — BossData Resource Class Hierarchy
- Tech debt logged: None (class-cache CI requirement noted in story Completion Notes + memory)
- Next recommended: bossdata story-002 (BossDataLoader — Load and Validate)

## Session Extract — /dev-story 2026-06-02 (bossdata story-001)
- Story: production/epics/bossdata-resource-architecture/story-001-bossdata-resources.md — BossData Resource Class Hierarchy
- Files changed: game/scripts/data/attack_data.gd, game/scripts/data/phase_data.gd, game/scripts/data/boss_data.gd, game/tests/unit/bossdata-resource-architecture/test_bossdata_resources.gd
- Test written: game/tests/unit/bossdata-resource-architecture/test_bossdata_resources.gd (15 test functions) — 15/15 PASS
- Full suite: 4 scripts, 55 tests, all pass
- KEY LEARNING: new class_name scripts need a class-cache regen before headless GUT sees them. Run once after adding class_name files:
  `C:\game\godot\Godot_v4.6.2-stable_win64_console.exe --headless --editor --quit --path C:\game\comeon\game`
  CI MUST do this import step before running GUT. See memory feedback-gut-file-naming.
- Blockers: None
- Next: /story-done bossdata story-001

## Session Extract — /story-done 2026-06-02 (Story 003)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/signal-infrastructure/story-003-event-bus-injection-test.md — EventBus GUT Testability — Mock Injection Validation
- Tech debt logged: None
- Next recommended: signal-infrastructure epic 全部 Complete — 开始 bossdata-resource-architecture epic

## Session Extract — /dev-story 2026-06-02 (Story 003)
- Story: production/epics/signal-infrastructure/story-003-event-bus-injection-test.md — EventBus GUT Testability — Mock Injection Validation
- Files changed: game/tests/helpers/mock_event_bus.gd (created), game/tests/integration/signal-infrastructure/test_event_bus_injection.gd (created)
- Test written: game/tests/integration/signal-infrastructure/test_event_bus_injection.gd (5 test functions)
- Blockers: None
- Next: run GUT integration tests, then /story-done production/epics/signal-infrastructure/story-003-event-bus-injection-test.md

## Session Extract — /story-done 2026-06-02 (Story 002)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/signal-infrastructure/story-002-event-bus-signals.md — EventBus Autoload — Typed Signal Declarations
- Tech debt logged: None
- Next recommended: story-003-event-bus-injection-test.md (Signal Infrastructure epic)

## Session Extract — /dev-story 2026-06-02 (Story 002)
- Story: production/epics/signal-infrastructure/story-002-event-bus-signals.md — EventBus Autoload — Typed Signal Declarations
- Files changed: game/autoloads/event_bus.gd (created), game/project.godot (autoload section added), game/tests/unit/signal-infrastructure/test_event_bus.gd (created)
- Test written: game/tests/unit/signal-infrastructure/test_event_bus.gd (15 test functions)
- Blockers: None
- Next: run GUT tests, then /story-done production/epics/signal-infrastructure/story-002-event-bus-signals.md

## Session Extract — /story-done 2026-06-02
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/signal-infrastructure/story-001-game-enums.md — GameEnums — Shared Enum Definitions
- Tech debt logged: None
- Next recommended: story-002-event-bus-signals.md (Signal Infrastructure epic)

## Session Extract — /dev-story 2026-06-02
- Story: production/epics/signal-infrastructure/story-001-game-enums.md — GameEnums — Shared Enum Definitions
- Files changed: game/scripts/data/game_enums.gd (created), game/tests/unit/signal-infrastructure/game_enums_test.gd (created), game/project.godot (created)
- Test written: tests/unit/signal-infrastructure/game_enums_test.gd (22 test functions)
- Blockers: None
- Next: /code-review scripts/data/game_enums.gd tests/unit/signal-infrastructure/game_enums_test.gd then /story-done production/epics/signal-infrastructure/story-001-game-enums.md

## /create-epics layer:foundation 完成（2026-06-02）
3 个 Foundation epic 写入 production/epics/：
- signal-infrastructure（EventBus + GameEnums；ADR-0001/0002；LOW）
- bossdata-resource-architecture（BossData Resources + Loader；ADR-0002；MEDIUM；TR-PTS-011 partial 非阻塞）
- retry-context（RetryContext + HitpauseManager Autoloads；ADR-0003/0005；LOW）
索引：production/epics/index.md
下一步：/create-stories signal-infrastructure（按依赖顺序：signal → bossdata → retry）
Foundation+Core epic 完成后可 /gate-check production
HUD spec：design/ux/hud.md（Status: Complete, Pending /ux-review）
关键决策：预警进度条已移除（玩家必须读 Boss 视觉）；GAP-03 解决（CanvasLayer 坐标转换）
控制清单：docs/architecture/control-manifest.md（版本 2026-06-01）

## Vertical Slice — 进行中（2026-06-01）
**游戏名**：刃响 (Blade Echo)
**验证问题**：玩家在无引导情况下，能否在 3-5 分钟内体验「读懂→格挡→反击」掌握循环（含 2 阶段 Boss + 多攻击类型 + 死亡屏幕）？架构能否在 10 天内按控制清单质量实现？
**系统范围**：PlayerController · HealthDamageSystem · ParryTelegraphSystem · BossStateMachine · CounterAttackComboSystem · InstantRetrySystem · HUD · Foundation Autoloads
**美术质量**：几何占位（ColorRect + Label）
**目录**：prototypes/blade-echo-vertical-slice/
**当前阶段**：Phase 4 — Implement（Day 1）
**Day 3 检查点**：物理响应玩家角色必须可操作，否则停止评估范围
**成功标准**：
1. 玩家在无说明下完成一次完整格挡→反击连段
2. 死亡屏幕 1.5s 后 Boss HP 保留
3. Phase 2 触发有明显视觉变化
4. HUD 4 元素实时更新正确
5. 外部测试者在首次死亡后主动重试
门关报告：production/gate-checks/gate-check-technical-setup-to-pre-production-2026-06-01.md

---

**[历史] Systems Design 阶段** — 7/7 MVP GDDs 已完成，门关验证未通过（需 /review-all-gdds）

## Progress Checklist

- [x] /brainstorm complete → design/gdd/game-concept.md
- [x] /setup-engine complete → Godot 4.6 + GDScript
- [x] /prototype parry-counter-system — PROCEED (TELEGRAPH=1.0s, WINDOW=0.35s)
- [x] /art-bible complete → design/art/art-bible.md (9/9 sections)
- [x] /map-systems complete → design/gdd/systems-index.md (15 systems)
- [x] ① 伤害/生命系统 GDD → design/gdd/health-damage-system.md
- [x] ② 玩家角色控制系统 GDD → design/gdd/player-controller-system.md
- [x] ③ 格挡/预警系统 GDD → design/gdd/parry-telegraph-system.md
- [x] ④ Boss 状态机系统 GDD → design/gdd/boss-state-machine.md（状态：Designed, Pending Review）
- [x] ⑤ 反击连段系统 GDD → design/gdd/counter-attack-combo.md（状态：Designed, Pending Review）
- [x] ⑥ 即时重试系统 GDD → design/gdd/instant-retry-system.md（已按 Art Bible 7.5 全面修订）
- [x] ⑦ HUD 系统 GDD → design/gdd/hud-system.md
- [x] /gate-check systems-design 已运行 → VERDICT: FAIL（可修复）
- [x] 修复 6 项 FAIL/CONCERNS 项目
- [ ] **下次会话第一件事：在新会话中运行 `/review-all-gdds`**

## Gate Check 修复记录（2026-06-01）

**已修复：**
1. ✅ production/stage.txt → "Systems Design"
2. ✅ boss-state-machine.md 状态 → Designed (Pending Review)
3. ✅ counter-attack-combo.md 状态 → Designed (Pending Review)
4. ✅ HUD 在 systems-index 依赖列表补全
5. ✅ 反击连段 GDD「冷白光晕」→ 「枯骨白高亮 #F5F0E8」（禁用霜白）
6. ✅ 即时重试 GDD 全面修订符合 Art Bible 7.5（1.5s 死亡屏幕序列 + 无 UI 提示 + 自动恢复）

**剩余阻塞：**
- ❌ /review-all-gdds 跨 GDD 审查报告尚未生成（必须在**新会话**中运行）

## 关键决策（Art Bible 7.5 同步）

即时重试系统从「3s 重试预算 + 「再试一次」提示」改为「1.5s 死亡屏幕 + 自动恢复 + 任意帧跳过」：
- 时长：3.0s → 1.5s（Art Bible 锁定）
- 流程：玩家确认 → 自动恢复
- UI：极简提示 → 无 UI 元素（Art Bible 绝对禁止）
- 视觉：纯黑渐黑 → 红闪 0.2s + 渐入深灰 0.4s + Boss 相位符号 0.6s + 淡出 0.3s

## Registry Constants (cumulative)

From health-damage-system.md:
- player_max_hp=100, player_hp_segments=5, hp_per_segment=20
- player_hit_invuln_duration=0.5s, counter_base_damage=20, boss_max_hp_baseline=1000

From player-controller-system.md:
- player_move_speed=340 px/s, knockback_speed=200 px/s, hit_stun_duration=0.30s

From parry-telegraph-system.md:
- telegraph_duration_light/heavy/sweep = 0.8/1.2/1.5s
- window_width_light/heavy/sweep = 0.30/0.35/0.45s
- window_open_fraction=0.50, parry_animation_duration=0.4s
- stagger_duration_light/heavy/sweep = 1.0/1.5/2.0s

From counter-attack-combo.md:
- max_combo_hits=3, hit_animation_duration=0.25s, bonus_stagger_ratio=0.5

From instant-retry-system.md (Art Bible 7.5 同步后):
- retry_invuln_duration=2.0s（不变）
- red_flash_duration=0.2s, fade_to_grey_duration=0.4s
- phase_symbol_display_duration=0.6s, symbol_fade_out_duration=0.3s
- total_death_screen_duration=1.5s（硬约束）
- DEPRECATED: death_fade_out_duration (旧 0.8s), retry_prompt_min_duration (旧 0.3s)

## Next Session Quick-Start

1. `/review-all-gdds` — 在新会话运行，生成 design/gdd/gdd-cross-review-*.md
2. 处理审查发现的跨 GDD 不一致项（可能需要返工某些 GDD）
3. `/gate-check systems-design` — 重新验证门关（预期 PASS 或 CONCERNS 可接受）
4. 进入 Technical Setup 阶段：开始写 ADRs（建议顺序：信号路由 → RetryContext → BossData 资产结构）

## MVP 进度

7 / 7 MVP 系统已设计 ✅
7 / 7 MVP 系统已审查 ✅（2026-06-01 /review-all-gdds）
3 / 7 MVP 系统需返工（B-01/B-02/B-03 阻塞修复）
0 / 7 MVP 系统已批准

## Session Extract — /review-all-gdds 2026-06-01
- Verdict: FAIL（3 阻塞，4 warnings）→ **全部已修复（同会话内）**
- GDDs reviewed: 7
- Report: design/gdd/gdd-cross-review-2026-06-01.md

### 修复明细（2026-06-01 同会话）
- ✅ **B-01/B-02** — health-damage-system.md 公式 2 重构为引用 counter-attack-combo 公式 1（[0.8, 1.1, 1.6] 为权威值，合计 70 HP）；删除 health-damage Tuning Knobs 中的 combo_position_multipliers；修正失败的 AC（20/25/30/75 → 16/22/32/70）
- ✅ **B-03** — player-controller-system.md 新增 `attack` InputMap 动作 + `attack_input_pressed` 信号；Core Rules 第 11 条（攻击输入转发规则：纯转发，不锁移动，counter-attack 系统门控）；Interactions 表 + Dependencies 表 + Cross-References 表 + 3 个新 AC
- ✅ **W-01** — parry-telegraph Formula 3 system_state 枚举去除 STAGGERING
- ✅ **W-02** — boss-state-machine 双向一致性备注 ❗ → ✅
- ✅ **W-03** — boss-state-machine Tuning Knob `phase_hp_threshold` → `phase_threshold_pct`
- ✅ **W-04** — parry-telegraph Visual/Audio 表「Boss 硬直中（STAGGERING）」→「Boss STAGGERED 期间（反击连段系统管理）」

### 设计决策（2026-06-01）
- Attack 输入处理：控制器**不新增 ATTACKING 状态**，仅在 IDLE/RUNNING/AIRBORNE 时转发 `attack_input_pressed` 信号；反击连段系统门控（仅 COUNTER_WINDOW_OPEN + 无冷却时执行）。设计哲学：职责分离 + MVP 简化

### Systems-index 状态
所有 7 个 MVP GDD 状态恢复为 Designed（修订完成）。

### Gate Check Result (2026-06-01)
- `/review-all-gdds` v2: ✅ PASS（0 阻塞，0 warnings）— `design/gdd/gdd-cross-review-2026-06-01-v2.md`
- v2 还修复了 v1 遗漏的 3 项额外陈旧引用（W-05/W-06/W-07）
- `/gate-check systems-design`: ✅ PASS — Director panel skipped (lean, context efficiency)
- **production/stage.txt 已更新为 'Technical Setup'**

### /create-architecture 完成（2026-06-01）
- 产出：docs/architecture/architecture.md v1.0
- TD Sign-Off: APPROVED WITH CONDITIONS
- 条件：ADR-001 + ADR-003 必须在第一次 sprint 前 Accepted
- 72 个技术需求已提取并映射到 5 个架构层
- 5 个 Required ADR 已识别（见下方）

### Required ADRs（全部完成 ✅）
1. ✅ ADR-0001: 信号路由架构 — EventBus Autoload，直连例外（1:1 controller 信号）
2. ✅ ADR-0002: BossData 资产结构 — GDScript Resource 子类 (.tres)；GameEnums 共享枚举
3. ✅ ADR-0003: RetryContext + 场景重置 — Autoload + in-place reset < 100ms
4. ✅ ADR-0004: 玩家状态机 — enum-based + _transition_to() 中心调度 + CONNECT_ONE_SHOT 模式
5. ✅ ADR-0005: 动画→代码边界 — CONNECT_ONE_SHOT + HitpauseManager (Engine.time_scale=0)

### Technical Setup 阶段剩余工作
- [x] /test-setup — ✅ 创建 tests/ (unit/integration/smoke/evidence) + GUT runner + CI workflow + 示例测试
- [x] /ux-design — ✅ 创建 accessibility-requirements.md (Standard 段) + interaction-patterns.md (8 模式)
- [ ] /architecture-review（**新会话**中运行，不在 ADR 同一会话）→ 生成 requirements-traceability.md

### /test-setup 完成（2026-06-01）
- tests/README.md + gut_runner.gd + unit/ + integration/ + smoke/critical-paths.md + evidence/
- tests/unit/health_damage/health_damage_test.gd（框架动作确认占位测试）
- .github/workflows/tests.yml（gdUnit4-action，godot 4.6，main push/PR）
- 手动待办：Godot AssetLib 安装 GUT 插件并启用

### /ux-design 完成（2026-06-01）
- design/accessibility-requirements.md — Standard 段（键盘+手柄完整导航 / WCAG-AA / 色非依存三重信号 / 重映射 / Reduce Motion）
- design/ux/interaction-patterns.md — 8 个模式正式化：Segmented Status Bar / Continuous Bar+Phase Ticks / Contextual Timer Bar / State-Colored Indicator / Hit Counter Badge / Transient Confirmation Flash / Minimal Death Screen / World-Space HUD Element

### Recommended next（**新会话**）
1. `/architecture-review` — 生成追溯矩阵 (requirements-traceability.md) + TR registry，完成 Technical Setup 阶段
   - ⚠️ 必须在新会话运行（不与 /architecture-decision 同会话，保证审查独立性）
2. 之后 `/gate-check technical-setup` — 验证可进入 Pre-Production（预期通过：5 ADR + tests + ux + architecture 齐备）
2. 建议 ADR 顺序（待 /create-architecture 输出确认）：
   - 信号路由（EventBus vs 节点直连）— 大多数系统的开放问题指向此
   - RetryContext 实现（Autoload vs 场景参数传递）
   - BossData 资产结构（Resource 子类 vs JSON）
   - AnimationPlayer.animation_finished vs 内部计时器（影响 Boss SM AC-04/AC-16）

## Session Extract — /architecture-review 2026-06-01
- Verdict: **CONCERNS**
- Requirements: 92 total — 86 covered (93%), 4 partial, 2 gap
- New TR-IDs registered: 92（tr-registry.yaml 首次实填，复用 ADR 已引用编号）
- GDD revision flags: None（无 HIGH RISK 引擎发现）
- Top findings:
  1. 🔴 CONFLICT-01: ADR-0003 200ms 跳过守卫 vs instant-retry AC-03（任意帧跳过含 RED_FLASH）— 需协调二选一
  2. ⚠️ GAP-02: 格挡/反击调参存储位置未定义（TR-PTS-011, TR-CAC-002/003/006）— ADR-0002 schema 仅含 telegraph_duration_override；建议 /create-control-manifest 拍板
  3. ❌ GAP-03: HUD 反击条世界坐标跟随未决（TR-HUD-008）— 留给 /ux-design hud 或新 ADR
  4. ℹ️ DOC-01: architecture.md「ADRs not written」陈旧表述需更新
- ADR 依赖排序: 0001→0002→0003→0004→0005，无环，全 Accepted
- 引擎: Godot 4.6 一致；0 废弃 API；duplicate_deep()(4.5) 正确标注
- Report: docs/architecture/architecture-review-2026-06-01.md
- Index: docs/architecture/requirements-traceability.md
- Pre-gate checklist: tests/unit ✅ · tests/integration ✅ · .github/workflows/tests.yml ✅ · design/accessibility-requirements.md ✅ · design/ux/interaction-patterns.md ✅ — 全部就绪


## Session Extract — /dev-story 2026-06-03 (retry-context story-001)
- Story: production/epics/retry-context/story-001-retry-context-autoload.md — RetryContext Autoload
- Files changed: game/autoloads/retry_context.gd (new, 105 lines), game/tests/unit/retry_context/retry_context_test.gd (new, 13 test functions), game/project.godot (RetryContext Autoload 등록)
- Test written: game/tests/unit/retry_context/retry_context_test.gd (13 functions — 3×AC-04 round-trip, 4×AC-10 clear, 2×AC-13 death_count, 4×AC-is_fresh_start)
- Blockers: None
- KEY REMINDER: new class_name scripts need class-cache regen. Run: `C:\game\godot\Godot_v4.6.2-stable_win64_console.exe --headless --editor --quit --path C:\game\comeon\game`
- Next: /code-review game/autoloads/retry_context.gd game/tests/unit/retry_context/retry_context_test.gd then /story-done production/epics/retry-context/story-001-retry-context-autoload.md

## Session Extract — /story-done 2026-06-03 (retry-context story-001)
- Verdict: COMPLETE
- Story: production/epics/retry-context/story-001-retry-context-autoload.md — RetryContext Autoload
- Tests: 13/13 passed (GUT headless, 0.479s)
- Tech debt logged: None
- Next recommended: Story 002 — HitpauseManager Autoload + Runtime Verification

## Session Extract — /dev-story 2026-06-03 (retry-context story-002)
- Story: production/epics/retry-context/story-002-hitpause-manager-autoload.md — HitpauseManager Autoload + Runtime Verification
- Files changed: game/autoloads/hitpause_manager.gd (new, 61 lines), game/tests/unit/hitpause/hitpause_manager_test.gd (new, 4 pass + 3 pending), game/project.godot (HitpauseManager Autoload 등록)
- Test written: game/tests/unit/hitpause/hitpause_manager_test.gd (4 automated pass, 3 pending — AC-timing/AC-timer-verify/AC-independence는 수동 런타임 검증 필요)
- Known warning: "8 unfreed children" — test_time_scale_set_to_zero_on_trigger의 999s timer가 lingering; 기능 문제 없음
- Blockers: None (AC-timing 등 수동 검증은 /story-done에서 처리)
- Next: /code-review game/autoloads/hitpause_manager.gd game/tests/unit/hitpause/hitpause_manager_test.gd then /story-done production/epics/retry-context/story-002-hitpause-manager-autoload.md

## Session Extract — /story-done 2026-06-03 (retry-context story-002)
- Verdict: COMPLETE WITH NOTES
- Story: production/epics/retry-context/story-002-hitpause-manager-autoload.md — HitpauseManager Autoload + Runtime Verification
- Tech debt logged: 2 items (trigger_hitpause 음수 방어, GUT 경고) → docs/tech-debt-register.md
- Next recommended: retry-context epic 완료 — 다음 에픽으로 이동
