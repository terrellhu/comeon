# Sprint 002 — 2026-06-05 to 2026-06-18

> **Stage**: Production
> **Status**: Active
> **Previous Sprint**: Foundation + Core Layer (21 stories, 100% completion, 4 days)
> **Gate Check**: Pre-Production → Production (CONCERNS — accepted 2026-06-04)

## Sprint Goal

完成全部 5 个 MVP Feature 层系统实现（BossStateMachine · ParryTelegraphSystem · CounterAttackComboSystem · InstantRetrySystem · HUDSystem），使完整 Boss Rush 游戏循环可在 Production 代码中端到端运行。

## Capacity

| 项目 | 值 |
|---|---|
| 总天数 | 14 天（2026-06-05 至 2026-06-18） |
| 缓冲（20%） | 3 天（保留给未计划工作） |
| 可用 | **11 个工作天** |
| 前序速度基准 | 5.25 stories/day（Foundation+Core sprint） |
| 本期保守估算 | 3 stories/day（Feature 层集成复杂度更高） |
| 容量 | ~33 个故事当量 |

## Sprint Opening Sequence (Day 1 Required — Before Any Feature Code)

在写第一行 Feature 代码之前，必须按顺序完成：
1. S002-I01 — 解决 CONFLICT-01
2. S002-I02 — 解决 GAP-02
3. S002-I03 — 创建 Feature 层 epics + stories
4. S002-I04 — 创建物理集成测试场景（可与 I01–I03 并行）

## Tasks

### Must Have — Day 1 基础设施

| ID | 任务 | 估算 | 依赖 | 验收标准 |
|---|---|---|---|---|
| S002-I01 | 解决 CONFLICT-01：修订 ADR-0003（200ms skip guard vs GDD AC-03）| 2h | — | ADR-0003 修订版本 Accepted；GDD AC-03 文本一致；InstantRetrySystem 故事可无歧义编写 |
| S002-I02 | 解决 GAP-02：codify 格挡/反击参数存储架构到 control-manifest | 1h | — | GAP-02 在 control-manifest Open Items 中标记 CLOSED；ParryTelegraphSystem 存储方案明确 |
| S002-I03 | 创建 Feature 层 epics + stories（`/create-epics layer:feature` × 5 + `/create-stories [epic]` × 5） | 2h | S002-I01, S002-I02 | 5 个 Feature epics 存在于 `production/epics/`；所有故事文件存在且通过 `/story-readiness` |
| S002-I04 | 创建物理集成测试场景（`test_pc_jump_integration.gd`）— 关闭 9 个 pending 测试 | 3h | — | CharacterBody2D + 地板碰撞 + GUT InputSender；PC-002/003/005/006 共 9 个 pending → PASS；总测试通过数提升至 316+ |

### Must Have — Feature 层系统实现

实现顺序基于 ADR 依赖图。括号内为估算故事数和天数。

| ID | 系统 | 故事数 | 估算 | 依赖 | Epic 路径（S002-I03 后创建） |
|---|---|---|---|---|---|
| S002-F01 | BossStateMachine | ~5 | 1.5d | HealthDamageSystem (done) | `production/epics/boss-state-machine/` |
| S002-F02 | HUDSystem（MVP signal-driven） | ~4 | 1.5d | HealthDamageSystem (done), EventBus (done) | `production/epics/hud-system/` |
| S002-F03 | ParryTelegraphSystem | ~5 | 2d | GAP-02 resolved, BossStateMachine | `production/epics/parry-telegraph-system/` |
| S002-F04 | CounterAttackComboSystem | ~5 | 2d | ParryTelegraphSystem | `production/epics/counter-attack-combo/` |
| S002-F05 | InstantRetrySystem | ~5 | 2d | CONFLICT-01 resolved, all other MVP systems | `production/epics/instant-retry-system/` |

**实现顺序：**
```
Day 1:  I01 + I02 + I03 + I04
Day 2:  F01 BossStateMachine (unblocked)
Day 2:  F02 HUDSystem (unblocked, can interleave with F01)
Day 4:  F03 ParryTelegraphSystem (GAP-02 resolved)
Day 6:  F04 CounterAttackComboSystem (Parry complete)
Day 8:  F05 InstantRetrySystem (all others + CONFLICT-01 resolved)
Day 10: QA, smoke-check, sign-off
```

### Should Have

| ID | 任务 | 估算 | 备注 |
|---|---|---|---|
| S002-Q01 | 外部玩家测试（5 分钟，1 名非开发者）+ 记录 `/playtest-report` | 2h | CD 要求；Production → Polish gate 需要 |
| S002-Q02 | BossDataLoader Debug run（5 个 assert() 路径）→ `production/qa/evidence/bossdata-assert-debug-2026-06.md` | 1h | QA advisory condition #1 |
| S002-Q03 | HitpauseManager native build 计时验证（60ms ±16.6ms）→ `production/qa/evidence/hitpause-runtime-2026-06.md` | 2h | QA advisory condition #2 |

### Nice to Have

| ID | 任务 | 估算 | 备注 |
|---|---|---|---|
| S002-D01 | Art Bible 末尾添加正式 sign-off 区块 | 0.5h | AD 要求，非阻塞 |
| S002-D02 | `architecture.md` DOC-01 清理（过时"no ADRs"引用） | 1h | TD 建议 |
| S002-D03 | 创建 entity inventory `design/assets/entity-inventory.md` | 2h | 首个 Boss 资产故事开工前升为 Must Have |

## Carryover from Sprint 001

| 任务 | 原因 | 本 Sprint 处理 |
|---|---|---|
| test_pc_jump_integration.gd（9 个 pending 测试） | headless 环境限制 | S002-I04 — Day 1 Must Have |
| HitpauseManager 计时验证 | native build 需求 | S002-Q03 — Should Have |
| BossDataLoader assert() Debug run | Godot Debug 环境 | S002-Q02 — Should Have |
| HD-007 AC-3 `get_entered_phases()` 访问器 | 结构性断言建议 | 在 health-damage epic 中作为小故事处理，或合并到 InstantRetrySystem 集成测试 |

## Risks

| 风险 | 概率 | 影响 | 缓解方案 |
|---|---|---|---|
| CONFLICT-01 解决触发 GDD 连锁修订 | 中 | 高（延迟 InstantRetrySystem）| Day 1 优先；先解决再写 InstantRetry 故事 |
| Feature 层集成 bug（5 系统交叉信号） | 高 | 中（调试时间）| 严格遵循 EventBus；每系统有集成测试；用 MockEventBus 隔离 |
| 5 个 Feature 系统超过 11 天容量 | 中 | 中（需要延期）| 如超容量，F05 InstantRetrySystem 延到 Sprint 003；不降低测试标准 |
| 外部测试难以安排 | 低 | 中 | 早安排；最晚 Sprint 002 第二周 |

## Dependencies on External Factors

- CONFLICT-01 解决后验证不破坏现有 307/331 基线测试
- Feature epics/stories 必须在 `/dev-story` 调用前创建（S002-I03）
- Sprint 002 所有提交使用 `feat(story-id):` 格式（retrospective action item #2）

## Definition of Done

- [ ] S002-I01/I02: CONFLICT-01 + GAP-02 CLOSED
- [ ] S002-I03: 5 个 Feature epics + 全部 stories 已创建
- [ ] S002-I04: `test_pc_jump_integration.gd` 通过，9 个 pending → PASS
- [ ] 全部 5 个 Feature 系统 Status: Complete（所有故事通过 `/story-done`）
- [ ] 测试套件：0 失败，不新增 pending
- [ ] QA 计划存在（`/qa-plan sprint` — 在实现开始前运行）
- [ ] Smoke check PASS（`/smoke-check sprint`）
- [ ] QA sign-off APPROVED 或 APPROVED WITH CONDITIONS（`/team-qa sprint`）
- [ ] 所有 sprint 提交使用 `feat(story-id): description` 格式
