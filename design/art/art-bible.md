# Art Bible: 刃响 (Blade Echo)

*Created: 2026-05-31*
*Status: Complete*
*Visual Identity Anchor: 「暗神话辉煌」(Dark Mythic Grandeur)*

---

## 1. Visual Identity Statement

**ONE-LINE VISUAL RULE:**
> 每一帧都是一件毁坏的神器——美到可以挂在腐化神殿里，腐化到让人隐隐不安。
> *(Every frame is a sacred artifact of a ruined god — beautiful enough to hang in a corrupted temple, corrupted enough to make you uneasy.)*

**日常决策测试**：「这个视觉决定，放进腐化神殿里合理吗？」纯粹的美或纯粹的恐怖都不合格——必须是**美丽与毁坏并存**。

### Supporting Principles

**PRINCIPLE 1 — 腐化赋予美意义**
*(Corruption Gives Beauty Meaning — serves Pillar: 画面即叙事)*

每个视觉元素必须同时携带它曾有的辉煌 *和* 堕落的痕迹。当面临"更美"还是"更黑暗"的选择时，两者都不选——选择**美丽而破碎的**。

> *设计测试*：这个元素让我既想靠近又感到不适吗？如果只有一种感觉，它还没做完。

---

**PRINCIPLE 2 — 攻击预警是视觉高潮**
*(Attack Telegraphs Are the Visual Climax — serves Pillar: 每个神明都是一首歌)*

每个攻击预警必须既在功能上清晰，又在美学上精彩。一个"只是可读"的预警特效没做完——它必须同时是这帧画面里最美的东西。

> *设计测试*：如果截这一帧发社交媒体，预警效果会是主体吗？

---

**PRINCIPLE 3 — 剪影优先于细节**
*(Silhouette Over Detail — serves Pillar: 读懂才能赢)*

在游戏摄像机距离下，每个 Boss 的剪影在缩略图尺寸必须立即可读。任何与 Boss 剪影或攻击读取竞争的元素，该元素让步。

> *设计测试*：将 Boss 缩放到 64×64 像素——仍然立即知道它是什么吗？

---

*注：支柱 4「失败是学习」为 UX/体验支柱，无对应视觉身份原则——其视觉影响（快速死亡动画、极简重试界面）在 Section 8 资产规范中处理。*

---

## 2. Mood & Atmosphere

### Game State Atmosphere Targets

| 游戏状态 | 情感目标 | 光照特征 | 氛围词 | 能量等级 | 核心视觉元素 |
|---|---|---|---|---|---|
| **Hub 枢纽区域** | 休憩前的凝视——战斗已过，下一个未知 | 冷蓝光，低对比，弥散光源 | 空旷、沉默、悬置、等待 | 沉思 | 远处缓缓旋转的神明碎片 |
| **Boss 竞技场——进场** | 进入神明领域的敬畏与压迫 | 暖橙/冷紫强烈对比，侧逆光 | 壮阔、压迫、不祥、华丽 | 庄重 | Boss 在背光中的完整轮廓剪影 |
| **主动战斗** | 与音乐共舞的专注——危险但有节奏感 | 动态光，随攻击序列闪烁，中高对比 | 炽热、节奏、精准、危险 | 激烈/受控 | 攻击序列触发时的光影律动 |
| **格挡窗口时刻** | 时间凝固的顿悟——万物清晰，一击在即 | 高亮度冷白光，极高对比，背景压暗 | 结晶、静止、清澈、必然 | 瞬间暂停 | Boss 全身白色结晶光晕爆发 |
| **Boss 击败/胜利** | 悲悯的胜利——神明倒下，你是它的终结者 | 光源随 Boss 消逝变暗，蓝紫余晖 | 肃穆、悲悯、庄重、余韵 | 降落 | 战斗粒子从结晶融化后缓缓飘落 |
| **玩家死亡** | 短暂的遗憾，不是惩罚 | 快速高对比红闪→立即过渡到重试 | 短促、清晰、不拖沓 | 立即重置 | 击杀攻击的回闪（1.5s，可跳过）|
| **叙事解锁** | 为敌人的故事感到悲伤——理解带来悲哀 | 极暗背景，单一暖光源聚焦画面，高ISO感 | 神圣、孤独、缓慢、真实 | 沉默 | 神明全身立绘的慢速缓现（fade in）|

### Cross-State Rules

- **Boss 色调即身份**：每个 Boss 有独立主色调（独立色温/色调），进入其竞技场时光照切换至该色调——Boss 的颜色就是它的身份标识。
- **玩家中性色**：玩家角色始终保持中性色（蓝灰），在所有 Boss 色调环境中不突出——玩家是见证者，不是世界的主角。
- **格挡→胜利序列**：格挡白色结晶光晕先持续 0.5s，然后融化溶解为粒子下落（不同时触发，避免视觉噪声叠加）。
- **死亡克制原则**：死亡视觉效果必须在 1.5s 内完成（含可跳过的回闪）——任何拖延重试的视觉元素都违反「失败是学习」支柱。

---

## 3. Shape Language

**Governing Logic**: Shape is the first layer of the reading system — before color, before motion, before sound. Every shape decision must answer two questions simultaneously: "Is this readable?" and "Is this sacred?" Both must be yes.

### Character Silhouette Philosophy

**Player Character**
- Dominant shape: single vertical with one asymmetric diagonal (weapon integrated — reads as one object, not figure-plus-object)
- Bounding box: ~1:3 width-to-height ratio at neutral stance
- No decorative protrusions above shoulder line at idle — head/shoulder stays clean so boss shapes dominate the upper visual field
- At 64×64px: vertical + weapon angle reads unambiguously as "human with weapon"
- At 16×16px: must resolve to a vertical + one diagonal
- Emotional read: containment and intentionality against bosses that overflow the frame

**Boss Characters — Three-Layer Corruption Rule**

| Layer | Description | Test |
|---|---|---|
| 1. Divine Core | Geometric, symmetrical primary shape communicating the god's original domain | Readable at 64×64px without detail |
| 2. Grandeur Extension | Secondary shapes (wings, halos, weapons, trailing forms) — symmetrical or near-symmetrical at macro level | Silhouette communicates "this was complete" |
| 3. Corruption Fracture | Asymmetric breakage — shattered extensions, angular tears, collapsed limbs | Fracture point = location of boss's most powerful attack telegraph |

At 16×16px: only the Divine Core survives. This is intentional — at icon size, you identify the god before its fall. The 16×16 silhouette shows what the god was.

**Environmental Elements**
- Horizontal dominant shapes; max height 60% of player height for interactive objects, 40% for ambient decoration
- Hazards use diagonal shapes (distinct grammar — "can hurt you but is not alive")
- No environmental vertical strong enough to imply agency

---

### Environment Geometry: Collapsed Sacred Architecture

The world uses formal sacred geometry underneath with organic collapse on top.

**Formal layer**: Rectilinear, symmetrical (platforms, columns, archways — right angles, bilateral symmetry). Communicates: gods built with absolute authority; gods don't build crooked temples.

**Collapse layer**: Organic, asymmetric (fracture lines following stress physics, root invasion, pooled substances obeying gravity). Communicates: something overcame the god's will.

Rules:
- Platform shapes are rectilinear — flat tops, vertical sides, right angles. Platforms hold.
- A column that reads as whole at 25% zoom shows stress fractures at 100% zoom — environment has zoom-dependent integrity.
- Ground plane: horizontal shapes only. No upward-pointing shapes in the ground plane. Upward = threat (reserved for bosses and telegraphs).
- Backgrounds: large, soft, radial shapes (light halos, broken ring structures). These create visual "held breath" — enormity without competing for attention.

---

### UI Shape Grammar: Partial Echo, Not Full Integration

UI uses the architectural vocabulary without the corruption layer. UI represents clarity — the god's intention, not the god's current state. Clean UI is what makes telegraphs beautiful by contrast.

| UI Element | Shape | Rule |
|---|---|---|
| Player health bar | Horizontal rectangle, chamfered corners (45°, no curves) | Depletes right-to-left; empty housing persists — absence is more powerful than nothing |
| Boss health bar | Wider horizontal, slight sawtooth along top edge, phase threshold ticks (vertical line) | No number — boss is a being to understand, not a resource to deplete |
| Lore panels | Tall rectangle + arch top derived from boss's own architecture (unique per boss), double-line border motif | Connects lore to the specific god; the arch shape is the god's identity in architectural form |
| Parry window indicator | 8-point starburst, unequal arm lengths (crystalline shattering) | Must pass Principle 2 test: frozen as a still image, it should read as compositionally complete |

**Absolute UI Rule**: No organic or true curves in any UI element. All UI curves are chamfered corners (straight-segment approximations). UI is built, not grown.

---

### Hero Shapes vs. Supporting Shapes

**Visual Hierarchy Law** (not about size — about visual weight):
> Attack telegraphs > Boss silhouette > Player silhouette > UI shapes > Environmental details > Backgrounds

**Attack Telegraph Shape Rules**:
- Melee sweeps: filled arc tracing weapon path (not outline), boss's color temperature, high saturation
- Projectile paths: narrow directional cone or beam, pointed terminus at impact location
- AOE: expanding ring, hard inner edge + soft outer edge
- Grab/pull: inward-pointing chevrons along a path
- Phase transition: full-screen radial fracture from boss center
- All telegraphs intentionally violate the environment's vocabulary — they feel like a rupture in visual grammar

**Background / Receding Shapes**:
- Soft edges (no hard silhouette contours)
- Low internal contrast (narrow value range)
- Non-directional (no pointing or radiating)

**Attention Conflict Rule** (mechanical, testable — in order):
1. Hard edge vs. soft edge → hard edge wins
2. Both hard edges → higher internal saturation wins
3. Both equivalent saturation → stronger directional energy wins
4. Both directional → redesign until one yields (two directional shapes = confusion, not drama)

This rule guarantees: when a telegraph fires, it wins every conflict by step 1 or 2. Telegraphs are always built with hard edges and maximum saturation.

**The Resting State**: Between attacks, boss and player silhouettes are the dominant shapes; environment holds the space. The resting state is as designed as the attack state — it is the visual breath between phrases, and what makes the next attack feel like an event.

---

## 4. Color System

### Primary Palette — 7 Colors

| 色名 | Hex | 角色 | 叙事含义 |
|---|---|---|---|
| **虚空墨** | `#0D0B1A` | 世界底色 | 永远带色偏（暖/冷取决于 Boss 色温区），从不用纯黑——世界有厚度，不是虚空 |
| **锈翡翠** | `#1C3A2E` | 植被侵蚀层 | 神殿腐化的中间地带——自然在吞噬神圣秩序 |
| **淤青紫** | `#3D1F5C` | 神明头冠色 | 积累了千年的信仰与痛苦——这是祭祀的颜色 |
| **枯骨白** | `#E8DFC8` | 永恒物质 | 石材、骨骼、被遗忘的铭文——一切曾经存在但已被遗弃的事物 |
| **血迹赤** | `#7A1C2E` | 过去式暴力 | **仅用于已发生的伤害**——血迹、旧伤、腐化纹路。从不用于实时攻击预警 |
| **锈金** | `#8B6914` | 衰减的权威 | 神明坠落后的黄金——不是财富，是失去的辉煌 |
| **霜白** | `#EDF3FF` | 格挡专属色 | **全游戏此色仅用于格挡/受击结晶瞬间**。玩家看到霜白 = 格挡窗口。无例外 |

---

### Semantic Color Vocabulary

每种颜色在这个世界有且只有一种情感功能。当颜色在叙事和系统之间出现冲突时，**系统语义优先**。

| 颜色 | 语义 | 禁止用途 | 设计测试 |
|---|---|---|---|
| 红 / 血迹赤 | 过去式暴力——已经发生的伤害 | **绝对禁止用于攻击预警**（玩家已经学会红=危险，误用会破坏信任） | 如果红出现在屏幕上，玩家是否应该已经受伤了？ |
| 金 / 锈金 | 权威的衰减——曾经神圣，现在堕落 | 不用于「成功」或「奖励」反馈（那是玩游戏的语言，不是这个世界的语言） | 这个金色让人感到惋惜还是觉得值钱？ |
| 白 / 霜白 | 格挡的结晶瞬间 | **绝对禁止在 UI 元素中使用**（会触发条件反射误判） | 玩家看到霜白是否立即想按格挡键？ |
| 蓝灰 | 玩家——世界的见证者 | 不用于 Boss 或环境装饰（玩家必须在任何 Boss 色调环境中保持视觉中性） | 玩家角色是否在所有 Boss 颜色背景下都不突出？ |
| 紫 / 淤青紫 | 积累的信仰与祭祀 | 不用于「危险」或「伤害」语义（紫是历史，不是威胁） | 这个紫是否带有仪式感和重量感？ |
| 黑 / 虚空墨 | 介质——世界的厚度 | 不用于「空」（空应该用深色带色偏，不是平坦的纯黑） | 如果把这个黑色去掉，世界是否变得扁平？ |
| 高饱和霓虹色调 | 即将到来的攻击预警 | 不用于装饰或背景（高饱和 = 危险信号，滥用后读取性崩溃） | 这个颜色在背景中是否会被误读为装饰？ |

---

### Boss Color Identity System

每个 Boss 拥有独立的色相区域——进入 Boss 竞技场时，光照切换至该 Boss 的色温，整个世界被其身份「染色」。

**规则：**
- 最多 **6 个 Boss**，各占色相盘中不重叠的扇形区域（间距 ≥40°）
- 每个 Boss 颜色有三层：**主色**（竞技场光照）/ **次色**（Boss 身体主调）/ **腐化强调色**（攻击预警使用的高饱和变体）
- 攻击预警颜色 = 该 Boss 腐化强调色，不是主调色板中的其他颜色
- Boss 打败后，其颜色从竞技场中逐渐消逝——光照回归 Hub 冷蓝

**设计示例（占位，最终 Boss 阵容待确认）：**

| Boss | 主色 | 竞技场色温 | 腐化强调色（预警） | 设计意图 |
|---|---|---|---|---|
| 破钟 | 铜橙 `#FF6B1A` | 暖橙，强侧逆光 | 过饱和琥珀 | 曾经报时，现在只响丧钟 |
| 溺档案者 | 深青 `#1A5C6B` | 冷绿，水下散射光 | 荧光青绿 | 知识在腐败中发光 |
| 灰烬君 | 白灰 `#C8C2B8` | 冷白，极低饱和 | 纯白（明度对比预警） | 已燃尽，靠余热威慑 |

> **灰烬君技术注意**：白灰 Boss 的预警无法依赖色相——必须用明度（预警时白色区域亮度+40% 以上）+ 形状（扩张的几何形）双重信号。这是技术实现风险项，需在资产规范中专项处理。

---

### UI Color Palette

UI 的职责是「清晰的神意」——使用世界色彩，但去除腐化层。UI 不腐化。

**规则：**
- UI 颜色 = 主调色板对应色，**降饱和度 15–20%** + **~85% 透明度叠加**
- 目标：玩家感知 UI 与世界在同一空间，但 UI 不竞争视觉注意力

**绝对禁止在 UI 中使用：**
1. **霜白** `#EDF3FF` — 专属格挡颜色，出现在 UI 会触发条件反射误判
2. **全饱和 Boss 主色** — Boss 颜色 = Boss 身份，UI 使用会稀释读取性
3. **纯白** `#FFFFFF` — 没有叙事含义，也没有情感重量，在这个世界中是错的

**UI 颜色映射示例：**

| UI 元素 | 使用颜色 | 说明 |
|---|---|---|
| 玩家血条 | 枯骨白变体 `~#C8BFA8` + 85% | 你的生命是永恒物质在消耗 |
| Boss 血条 | 该 Boss 主色，降饱和 15% | Boss 颜色即身份，血条是身份的剩余量 |
| 文字 / 叙事面板 | 枯骨白 `#E8DFC8` | 被遗忘的文字，在黑暗中仍可读 |
| 格挡指示器 | 霜白 `#EDF3FF` | **唯一例外**：格挡指示器必须是霜白，因为它就是在告诉玩家「现在格挡」 |

---

### Colorblind Safety

**核心原则：亮度对比是主信号，色相是辅助信号。**

任何对玩家有信息价值的视觉元素，色盲玩家在全灰度模式下必须能正常读取。

**攻击预警的色盲安全要求（强制）：**
- 预警颜色与背景的**明度差 ≥ 40%**（在灰度图像中仍清晰可辨）
- 预警同时触发：颜色变化 + **形状扩张/边缘硬化** + **音效**（三信号并行）
- 不存在「只能靠色相区分」的游戏信息

**生产门控：**
> **全灰度游玩测试**是正式发布前的强制门控。必须能在黑白屏幕上完成至少一个完整 Boss 战，且胜率不低于彩色版本的合理范围。此测试在 `/vertical-slice` 阶段执行。

**已知风险项：**
- 灰烬君的白色预警在灰度模式下与 Boss 本体几乎同色——需在资产规范中制定专项补偿方案（形状扩张幅度加倍，音效优先级提升）

---

## 5. Character Design Direction

### 5.0 设计前提

本节所有规则必须可被外包团队独立执行，无需口头补充。每条规则末尾附**合规测试（Compliance Test）**——强制检查项，非建议。所有规则均与 Section 1–4 系统保持向后兼容。

---

### 5.1 玩家角色视觉原型

**定义：行刑见证人（The Witnessing Blade）**

不是英雄、猎手、仆役。玩家角色是存在于神明坍塌时代的**见证者**——职能是观察、理解、终结。视觉上不传达"强大"，传达"精确"。

**R5.1-A 轮廓节制原则**
玩家整体轮廓在任何游戏镜头距离下必须能用一笔连续线条描绘。武器作为轮廓对角线融入身体，无外露装饰物突出肩线以上（服务支柱 1：玩家视觉信息量必须低于 Boss）。
> *Compliance Test*: 玩家与任意 Boss 并排缩放至 64×64px，玩家轮廓凸起数量应比 Boss 少 40% 以上。

**R5.1-B 中性色彩隔离原则**
玩家全程使用中性蓝灰色系（虚空墨 #0D0B1A + 枯骨白 #E8DFC8 之间的过渡灰调），在所有 Boss 场景中不吸收、不反射 Boss 特征色温（见 Section 4：玩家 = 见证者，他的颜色让 Boss 的故事更响亮）。
> *Compliance Test*: 将玩家叠放于所有 6 个 Boss 竞技场背景截图，玩家主色块不应被视觉识别为任一 Boss 调色盘的一部分。

**R5.1-C 神明关系定义**
玩家 vs. Boss = **刃 vs. 神祠**。玩家是器物（精确、冷静、功能性），Boss 是衰朽神殿（宏大、破碎、充满历史重量）。不是弱小 vs. 强大，是**尺度的对比**。玩家的精工细节密度明显高于 Boss 腐化层，但整体体积远小于 Boss。
> *Compliance Test*: 在同一帧内，玩家功能性细节（武器边缘、护具接缝）应在游戏镜头距离下清晰读取，但不产生视觉噪音与 Boss 轮廓竞争。

---

### 5.2 Boss 全局规则

以下规则适用于**所有 Boss**，与其个体叙事设计无关。

**R5.2-A 三层腐化结构必须显现**
神性核心层 / 宏大延伸层 / 腐化断裂层必须在同一静帧中同时可读。不允许腐化层仅存在于动画（静帧必须可见）。（服务支柱 3：第一帧即开始阅读其坠落叙事）
> *Compliance Test*: 对 Boss 静帧盲测——不了解叙事的测试者能否在 10 秒内用"某种东西曾经是……，现在正在……"描述？若不能，腐化叙事不充分。

**R5.2-B 尺度主宰原则**
Boss 在竞技场中视觉占屏 **30%–60%**（16:9，标准战斗距离）。低于 30% 存在感不足；高于 60% 预警可读性下降。（服务支柱 1）
> *Compliance Test*: 1920×1080 截图中，Boss 非透明像素占比测量值必须在 30%–60% 范围内。

**R5.2-C 剪影唯一性原则**
每个 Boss 在 64×64px 灰度缩略图下必须与其他所有 Boss 不可混淆。禁止两个 Boss 使用相同基础几何原型。（服务支柱 2：每首歌的视觉主题在最低分辨率下已经不同）
> *Compliance Test*: 所有 Boss 缩略图（64×64px 灰度）随机排列，10 秒内不依赖颜色能否区分全部个体？若不能，剪影设计不通过。

**R5.2-D 神性对称 / 腐化不对称分治原则**
神性核心层和宏大延伸层必须保持严格双侧对称（允许 ±5° 动态倾斜）。腐化断裂层必须不对称，且断裂最严重的方向指向该 Boss **招牌攻击预警发出方向**。（叙事与机制统一，服务支柱 2 + 3）
> *Compliance Test*: 翻转 Boss 腐化断裂层，两侧形态应明显不同。翻转后"镜像版本"若看起来合理，腐化层对称性不合格。

**R5.2-E 预警视觉锚点规则**
招牌攻击预警必须从 R5.2-D 定义的腐化断裂点发出，使用与 Boss 主色温最高对比度的颜色标记（禁止使用血迹赤 #7A1C2E，见 Section 4）。（服务支柱 1）
> *Compliance Test*: 遮蔽 Boss 的预警 VFX，仅看静帧形体，能否预测攻击大概会从哪个方向发出？能则锚点设计合格。

---

### 5.3 个体辨识规则

**首次读取层级（First-Impression Hierarchy）**

玩家第一次看到新 Boss 时，视觉信息必须按以下顺序接收：

```
Layer 1 — 剪影形态（0–0.5秒）    // 神明类型：这是什么东西？
Layer 2 — 色温主调（0.5–1.5秒）  // 情绪调性：这是什么感受？
Layer 3 — 腐化特征（1.5–3秒）    // 叙事：它曾经是什么，现在怎么了？
Layer 4 — 腐化断裂点（3–5秒）    // 战斗预知：危险从哪里来？
```

Layer 1/2 信息不允许被 Layer 3/4 细节噪音提前中断。

**R5.3-A 轮廓锁定优先**
Boss 的装饰性复杂细节不允许出现在轮廓外边缘——所有复杂性发生在轮廓内部。外边缘保持干净。
> *Compliance Test*: 将 Boss 转为纯色剪影，剪影本身是否已传达神明类型？若不能，轮廓设计不通过。

**R5.3-B 色温专属性**
每个 Boss 的主色温在色轮上与其他所有 Boss 相差 ≥40°（见 Section 4）。此色温必须应用于宏大延伸层，不允许被腐化层中性色冲淡至无法辨认。
> *Compliance Test*: 所有 Boss 宏大延伸层取色在色轮上标注，任意两点角度差 ≥40°。

---

### 5.4 表情与姿态风格

**情绪寄存器：抑制的宏大（Suppressed Grandeur）**

不是夸张的日系动作风格；不是完全写实的人体比例表演。是：有限度的宏大感——动作幅度被神明的**衰朽重量**压制，但核心情绪在游戏镜头距离下仍可读取。

参照：《Blasphemous》宗教壁画凝固感 + 《Furi》精准攻击前摇感。

**R5.4-A Boss 姿态：受损的威严**
待机姿态同时传达：曾经的权威（脊柱垂直、肢体展开、视线俯视）+ 腐化重量（某肢体不自然偏斜或轻微下沉）。待机姿态不允许看起来"放松"——腐化是重量，不是懈怠。
> *Compliance Test*: 遮住腐化视觉特征，剩余姿态是否仍传达"曾经是权威神明"？若不能，待机设计不通过。

**R5.4-B 玩家角色姿态：功能性静止**
待机姿态传达"准备就绪"——重心略低于中性站立，武器处于出鞘中间状态，视线水平（不俯视、不仰视）。不允许包含任何情绪性装饰动作（甩发、挥手、耸肩等）。
> *Compliance Test*: 玩家待机帧是否同时可读为"即将行动"和"见证者"？若只能读取其一，姿态设计不通过。

**R5.4-C 攻击前摇：高度克制的信号化**
预警动作的肢体位移幅度不超过该肢体静止位置的 **60%**（以骨骼绑定长度为基准）。情绪强度通过光效和粒子传递，而非夸张肢体位移。（服务支柱 1：过大位移与攻击本体混淆）
> *Compliance Test*: 预警动画帧与待机帧骨骼叠加对比，位移量是否 ≤60%？若超出，超余部分转移至 VFX 层。

---

### 5.5 LOD 哲学

**原则：两距离服务两功能（Two Distances, Two Purposes）**

| 距离 | 等效分辨率 | 服务功能 | 必须清晰 | 必须避免 |
|---|---|---|---|---|
| **战斗阅读距离** | 64×64px 等效 | 剪影识别、预警读取、层级辨认 | 轮廓形态、腐化断裂方向、色温主调 | 细节噪音打断剪影线条 |
| **暂停欣赏距离** | 原始游戏分辨率 | 叙事细节、艺术质量、世界观密度 | 纹理质量、腐化符文、材质层次 | 过度简化导致近景贫乏 |

**R5.5-A 细节密度分区**
Boss 视觉复杂性集中于轮廓内部**中心区域**，向轮廓边缘方向逐渐简化。轮廓边缘 20% 区域的细节密度不得高于中心区域的 30%。
> *Compliance Test*: Boss 美术稿中，边缘区域是否明显比中心"安静"？若边缘细节密度过高，64×64px 剪影将产生噪音。

**R5.5-B 战斗预警细节豁免**
预警相关视觉元素（腐化断裂点高光、预警颜色信号、攻击方向指示器）不受 R5.5-A 限制——允许在任何区域出现，允许突破轮廓边缘。前提：该细节必须明确服务于攻击预警信息，不得用于单纯装饰。
> *Compliance Test*: 对任何突出轮廓边缘的视觉元素提问——"是预警信号还是装饰？"若为装饰，必须移入轮廓内部。

**R5.5-C 玩家角色细节恒定**
玩家功能性细节（武器边缘、防具接缝）在所有游戏镜头距离下保持恒定清晰度。玩家不设置"暂停欣赏层"——他没有叙事细节需要被近景阅读。
> *Compliance Test*: 玩家缩放至游戏镜头最远距离，武器握持点和主要防具分区线是否仍可辨认？若不能，需简化近景细节以换取远景清晰度。

---

### 5.6 外包合规速查表

| 编号 | 规则 | 一句话测试 |
|------|------|------------|
| R5.1-A | 玩家轮廓节制 | 64×64px 下，玩家轮廓凸起数量 < Boss 的 60%？ |
| R5.1-B | 玩家色彩隔离 | 玩家主色块在所有 Boss 场景中保持中性？ |
| R5.1-C | 玩家-Boss 关系 | 对比是尺度（精密 vs. 宏大）而非强弱？ |
| R5.2-A | 三层可见性 | 静帧内三层腐化结构同时可读？ |
| R5.2-B | 尺度主宰 | Boss 占屏 30%–60%？ |
| R5.2-C | 剪影唯一性 | 64×64px 灰度下所有 Boss 剪影各不相同？ |
| R5.2-D | 对称分治 | 神性层对称、腐化层不对称，断裂方向指向招牌攻击？ |
| R5.2-E | 预警锚点 | 遮蔽 VFX 后，仅凭形体能预测攻击来向？ |
| R5.3-A | 轮廓锁定 | 纯色剪影本身已传达神明类型？ |
| R5.3-B | 色温专属 | 所有 Boss 主色温色轮间距 ≥40°？ |
| R5.4-A | Boss 待机威严 | 遮蔽腐化特征后，姿态仍读取为权威神明？ |
| R5.4-B | 玩家待机功能 | 待机帧同时读取为"准备就绪"和"见证者"？ |
| R5.4-C | 前摇克制 | 预警动作肢体位移 ≤60%，超余转移至 VFX？ |
| R5.5-A | 细节密度分区 | 轮廓边缘区域明显比中心"安静"？ |
| R5.5-B | 预警细节豁免 | 所有突出轮廓的元素均为预警功能，无纯装饰？ |
| R5.5-C | 玩家细节恒定 | 最远游戏镜头下，玩家武器握持点和防具分区线仍可辨认？ |

---

## 6. Environment Design Language

### 6.1 建筑风格与文明关系

**文明身份：祭仪帝国的遗迹（Ritual-Imperial Ruins）**

建筑由以神明为国家中心的古代帝国建造——不为居住，为**容纳神明的在场**。每一块石材的尺度按照神的体型而非人的体型规划。柱高是人类身高的 8–12 倍；拱门宽度允许一个 Boss 以站立姿态通过；地面台基深度暗示地下有更深的空间。

**三种材质层级：**

| 材质层级 | 类型 | 叙事含义 |
|---|---|---|
| 第一层：神圣建材 | 深色磨光石材（玄武岩质感，无明显颗粒） | 帝国以神之名建造，永恒意图 |
| 第二层：神明标记 | 冷锻铸铁装饰件（门扉、链条、嵌条） | 神明的力量被物质化为结构 |
| 第三层：有机侵入 | 苔藓、根系、凝固液体 | 衰败后自然的接管——或神明本身的腐化渗漏 |

**关键比例规则：**
- 所有拱形结构净高不低于画面高度的 60%（标准游戏摄像机视角）
- 可站立平台水平宽度至少为玩家碰撞盒宽度的 4 倍
- 装饰细节（浮雕、铭文、符文）**仅出现在垂直面**（墙壁、柱身），从不出现在平台顶面——平台顶面保持视觉中性
- 柱子在 25% 缩放下呈现完整垂直轮廓；在 100% 观察时，柱身中段可见应力裂缝（遵循力学逻辑，非装饰性随机纹路）

> *设计测试*: 遮盖所有角色后，仍能判断出"这栋建筑的建造者相信神明是真实存在的"——若只能读出"废墟"，需加入神明尺度的证据。

---

### 6.2 贴图哲学

**选择：风格化手绘（Stylized Hand-Painted），非 PBR**

PBR 的均质光照响应无法携带主观情绪权重——同种石材在 Boss 受伤与未受伤时视觉效果相同。本游戏的情绪权重**画在贴图本身**。参照：Hollow Knight 极简轮廓 + Blasphemous 宗教图像质感的中间态。

光影信息烘焙进漫反射贴图（Diffuse Baked），允许美术直接控制视觉叙事优先级。

**"圣洁但腐败"的贴图品质标准：**

*圣洁层（Sanctity Layer）——必须存在：*
- 石材表面有均匀打磨痕迹，暗示原始工艺级别极高
- 铁质装饰件的铸造边缘清晰（即使已锈蚀，轮廓仍精准）
- 地面接缝线条整齐，铺砌逻辑可推断

*腐败层（Decay Layer）——叠加在圣洁层上方：*
- 锈迹从铁件向石材渗透，产生锈金色 #8B6914 晕染向虚空墨 #0D0B1A 扩散
- 石材裂缝内部积液：颜色为该 Boss 的专属色（淤青紫 #3D1F5C 或 Boss 主色），**不是中性黑**——积液颜色泄露神明的腐化性质
- 有机物颜色被神明域能污染：锈翡翠 #1C3A2E（偏冷、偏毒、偏暗），不是自然绿色

**贴图分辨率规格：**

| 类型 | 分辨率 | 说明 |
|---|---|---|
| 大型结构（背景建筑块） | 2048×2048 | 低密度烘焙，近景不可进入 |
| 中型道具（柱子、平台块） | 1024×1024 | 满足 100% 缩放下可读裂缝细节 |
| 小型道具（碎石、植物） | 512×512 | — |

> *设计测试*: 将腐败层单独抠出，颜色信息应能独立指向该 Boss 的主色系——若腐败层颜色在任何 Boss arena 里都适用，则腐败层缺乏足够的域特异性。

---

### 6.3 道具密度规则

**核心逻辑：密度服务于视觉层级，而非装饰性丰富感**

视觉层级（Section 3）：**预警 > Boss > 玩家 > UI > 环境 > 背景**。道具密度的功能是在保证可信度的前提下，为高层级元素让出视觉带宽。

**密度分级：**

| 区域 | 前景道具数量/屏 | 道具类型 | 禁止 |
|---|---|---|---|
| **Hub** | 8–14 件 | 叙事性道具（破损神像、废弃供品台、枯萎仪式植物） | 尖锐向上形状、强烈发光道具 |
| **Boss Arena 前景** | 3–6 件，必须全部静态 | 叙事性 + 结构性 | 高度超过玩家角色站立高度 50% 的垂直道具 |
| **Arena 入口走廊** | Hub→Arena 过渡递减 | 叙事性，损毁程度递增 | 同时使用 Hub 色温与 Boss 色温 |

Arena 中景（一层景深后退）：8–12 件，可有轻微粒子效果但不发强光；背景层亮度低于前景至少 40%。

> *设计测试*: 在 Boss Arena 截图中临时隐藏 Boss 和玩家，剩余环境元素不应吸引视线到任何单一焦点——若某件道具反复拉回视线，其亮度或形状需降级。

---

### 6.4 环境叙事规则

**原则：每件道具是名词，每组道具是句子**

叙事不依赖文字。通过**物体状态、位置关系、与神明体积的比例对比**传递。

**"神曾居于此"的视觉证据清单：**

1. **尺度错位（Scale Dislocation）：** 人类尺度物体（椅子、容器、台阶踏步）与神明尺度建筑的比例严重失衡——一张石质宝座扶手高度等同于一扇普通门的高度。
2. **仪式痕迹（Ritual Residue）：** 供品台上有已凝固的有机物（液体状、黑色、凝固于流淌中途）。蜡烛凝固形态保留最后燃烧时的形状，暗示在某一时刻**同时熄灭**，而非逐渐耗尽。
3. **力量泄漏（Power Leakage）：** 神明域能以物质形态渗透到环境中，属性唯一（火焰域 = 裂缝里已冷却的岩浆；水域 = 悬在垂直墙面上的凝固积水）。
4. **崇拜者的末路（The Last Worshippers）：** 武器、盔甲碎片散落，不完整，向 Arena 中心方向倒伏——暗示最后一批人是**向神明走去**的，而不是逃离的。

**每个 Arena 必须包含的叙事道具组：**
- 该 Boss 神明的**标志性器物**（象征其域能的物质化道具）× 至少 1 件，置于背景可读区域
- **崇拜规模的证据**（破损的集会设施，数量暗示曾经的信徒体量）× 至少 2 件
- **失控的时间点证据**（某个动作被中断的痕迹：半铺的地砖、倾倒未洒的容器）× 1 件

> *设计测试*: 将 Arena 所有视觉元素描述为名词列表（无形容词），陌生人能否猜出"这里住着什么类型的神明"？若只能猜出"废墟"，叙事密度不足。

---

### 6.5 Hub 区域设计规则

**Hub 的视觉身份：唯一接近人类尺度的空间**

Hub 内建筑比例**接近人类尺度**——经历神明尺度的 Arena 后，Hub 的"小"本身就是设计内容。

**Hub 专属视觉规则：**
- **色温：** 固定冷蓝色主调（6500K–8000K 等效，霜白 #EDF3FF + 虚空墨 #0D0B1A 混合感）。全游戏此色温为 Hub 排他性标识，任何 Boss Arena 不得使用相同范围。
- **建筑比例：** Hub 拱门净高不超过画面高度 **35%**（对比 Arena 的 60% 最低要求，制造明确空间语感差异）。
- **光源类型：** 必须是**可识别来源**的光（残破天窗、裂缝透光、固态光源）。禁止无来源的 ambient glow 作主光源——来源可识别暗示此空间仍处于物理世界规则之内。
- **叙事功能道具：** 镜子/反光表面（玩家自我审视，呼应"死亡是教师"支柱）；记录性道具（刻文墙面、抽象符号铭刻，密度暗示有意记录）；通往各 Arena 的通道在 Hub 中**必须可见**——玩家应能感知所有 Boss 方向，制造主动选择感。

**禁止在 Hub 使用：** Boss 色温环境光 / 强烈发光粒子效果 / 向上尖锐形状 / 血迹赤 #7A1C2E 作主色

> *设计测试*: 将 Hub 截图与任意 Boss Arena 截图并排，不看任何角色，3 秒内必须能区分——若无法区分，色温或比例规则被违反。

---

### 6.6 Boss Arena 设计规则

**根本逻辑：Arena 是神明的身体延伸，不是战斗背景**

神明域能从 Boss 本体渗透到 Arena 每一处细节。Boss 受伤时 Arena 有所反应；Boss 死亡时 Arena 发生不可逆改变。

**跨所有 Arena 共享的固定元素：**
- 地面平台结构：水平，顶面视觉中性，直角（Section 3 已锁定）
- 建筑基础形态：正式矩形体量 + 有机崩塌层（Section 3 已锁定）
- 前景道具密度：每屏 3–6 件静态（Section 6.3）
- 叙事道具组：三类必须道具（Section 6.4）
- 背景层结构：3 层视差（Section 6.7）

**每个 Boss 专属的可变元素：**

| 可变元素 | 规格 |
|---|---|
| **色温身份** | Arena 级排他性色温，体现于环境光、积液颜色、有机物颜色、背景层主色调 |
| **力量泄漏材质** | 定义：泄漏区域、物质视觉状态（固态/凝固液体/晶体化）、随 Boss 血量变化规则 |
| **垂直空间设计** | 平台层级数量 2–4 层；最高可站立平台距画面顶部留 ≥15% 空余 |
| **标志性器物** | 首次进入时置于画面中段偏背景层，Boss 战进程中可选择性发生视觉状态变化 |

**Boss 死亡后 Arena 状态（Post-Death State）：**
- 域能撤退：域能材质颜色变为枯骨白 #E8DFC8，饱和度归零
- 某结构性元素发生**不可逆改变**（不是特效结束后恢复原状，而是持续可见的改变）
- 改变状态在玩家下次经过时仍然存在——胜利也留下痕迹（"死亡是教师"支柱）

> *设计测试*: 提取任意 Boss Arena 的色温 + 域能材质 + 标志性器物，这三项必须能唯一指向该 Boss——若任意一项替换到另一 Boss 的 Arena 中感觉不违和，该项独特性不足。

---

### 6.7 背景层规则

**视差层级：3 层固定结构**

3 层是"屏息宏大感"与"gameplay 可读性不受干扰"之间的平衡点。4 层以上在高速战斗中产生不可控视觉噪音；2 层以下缺乏足够空间深度。

| 层级 | 视差系数 | 内容 | 视觉特征 | 禁止 |
|---|---|---|---|---|
| **Layer 1 — Architectural Void** | 0.1–0.2 | 建筑外轮廓剪影、残破穹顶弧线 | 纯剪影，无贴图细节，填充虚空墨，轮廓线用虚空墨 +10% 亮度 | 任何发光效果、暖色系、可辨识细节纹理 |
| **Layer 2 — Sacred Halo** | 0.3–0.5 | 大型软边光晕（radial gradients）、破损环形结构、极低透明度粒子（0.05–0.1 alpha） | 全部软渐变，无硬边；光晕直径 ≥ 屏幕高度 80%；该 Boss 色温色降饱和至 30% 以下 | 硬边形状、高饱和度色彩、运动周期 <8 秒 |
| **Layer 3 — Environmental Texture Mid** | 0.6–0.75 | 背景建筑面细节（有贴图墙面、背景柱群）、悬挂物、静止域能积聚 | 亮度整体压低 40%，对比度压低 20% | 高频率运动、与前景预警信号颜色相近的发光效果、前景道具类型的重复 |

**"屏息宏大感"技术实现：** 背景主结构（Layer 1 轮廓，Layer 2 光晕）必须在单一截图中无法被完整框入——至少有一个维度超出画面边界。

> *设计测试*: 显示背景三层并隐藏前景所有元素，在纯背景截图中不应能找到任何硬边形状或纯色填充区域——全部形态必须是渐变、剪影、或低对比度软边面。

---

### 6.8 光照作为环境设计元素

**双重职责原则：光照同时服务于氛围叙事 AND gameplay 可读性，两者没有优先级之分**

**光照三层分工：**

**层级 1 — Gameplay Foundation Light（游戏性基础光）**
- 功能：确保所有 gameplay-critical 元素（平台边缘、玩家轮廓、Boss 触发区域）在任何战斗状态下均清晰可辨
- **方向：全游戏固定从左上方或右上方 45°**（一致方向让玩家建立稳定空间感知，不随 Arena 变化）
- 技术标准：平台顶面亮度高于侧面 ≥15%；玩家受光面与背景亮度差 ≥20%
- **禁止：** 该层光照的强度或方向不得随 Boss 战斗状态变化

**层级 2 — Atmosphere Overlay Light（氛围叠加光）**
- 功能：传递该 Boss 的域能氛围，增强神明压迫感
- 叠加在层级 1 之上，允许随 Boss 状态变化，但变化速率不超过 0.5 秒渐变过渡
- **禁止：** 不得将任何平台顶面亮度压低至低于层级 1 标准值的 **85%**

**层级 3 — Telegraph Light（预警光照）**
- 功能：攻击预警的光照实现（Section 1 Principle 2 的物理执行）
- 颜色与氛围叠加光必须有明确色相差距（**Hue 差 ≥30°**）
- 响应速度：从无到可见不超过 3 帧（60fps 下即 **50ms**）
- 来源：从 Boss 本体向外辐射，不从环境光源模拟
- **禁止：** 不得使用该 Boss 专属色温的同色系（如火焰 Boss 的预警不能是更亮的橙色，必须跳到对比色）

**光照反模式（Lighting Anti-Patterns）：**
- Boss Arena 中使用均质环境光（无方向感的全局照明）
- 攻击特效泛光压暗平台可站立区域
- 使用与预警信号相同或相近颜色的环境装饰发光（制造误读）
- Hub 区域使用暖色光（暖色保留为"神明存在/域能激活"的专属信号）

> *设计测试*: 在游戏截图中，找到亮度最高的 3 个区域——这 3 个区域必须全部属于：预警信号、Boss 受光面、玩家受光面。若任何最高亮度区域属于环境道具或背景，光照层级被违反。

---

## 7. UI/HUD Visual Direction

*Art Direction + UX Alignment integrated. Conflicts resolved as documented.*

---

### 7.1 HUD 空间哲学

**定位原则：「铸刻式」——非世界内嵌，但拒绝悬浮**

HUD 元素像铭文一样刻在屏幕边缘的结构框架内，从属于画面的建筑语言，而非漂浮于其上。

**元素位置：**
- **玩家血条：** 锚定屏幕左下角，贴边 18px 安全边距。位置原因：玩家视线主焦点在角色身上（屏幕左侧偏中），血条处于余光区域，死亡判断在眼角完成，不强迫注意力转移。
- **Boss 血条：** 锚定**屏幕顶部居中**，水平延伸至屏幕宽度 60%。第一阶段满血时，血条上边缘与 Boss 脚部之间垂直留白 ≥ 屏幕高度 15%——这段空白是攻击预警最清洁的展示区。
- **格挡指示器（8 点星形）：** 始终以玩家角色为中心，偏移量为角色重心上方 24px。它附着角色，不附着屏幕——格挡是身体感，不是数字感。

**战斗开始入场：** Boss 出场动画期间（约前 2 秒），HUD 透明度从 0% 在 1 秒内升至 85%——Boss 出场是电影感时刻，HUD 不参与。

> *设计测试*: 截取任意战斗高潮帧，移除所有 HUD 元素，画面构图仍然完整；放回 HUD，它们像印章一样强化画面，而不是像标签一样贴在画面上。

---

### 7.2 字体方向

**字体个性定位：手工刻制的碑文体，而非数字印刷体**

**字体权重与对比度：**
- **主体文字**（Boss 名、章节标题）：高笔画对比度衬线体（Serif），细横画 + 粗竖画，类碑文刻刀切割感。中文字体方向：类宋体但结构更紧收，笔画端部明显，不使用圆头。
- **次级文字**（提示文本、按键标注）：等宽无衬线（Monospace Sans），字重 Medium——系统/记录/冷静的语调，神的遗存被整理归档的感觉。
- 不存在第三级字体。

**尺寸层级（1080p 基准）：**

| 用途 | 尺寸 | 字重 |
|---|---|---|
| Boss 名称（揭示时刻） | 64–80px | Serif Bold |
| 次要标题（Hub 地点等） | 36px | Serif Regular |
| 提示/按键标注 | 20px | Mono Medium |
| 警告信息（极少使用） | 24px | Mono Bold |

**禁止出现的 UI 文字：**
- Boss 血量数字 / 玩家血量数字 / 伤害跳字（任何数字弹出）
- 「生命值」「HP」等标签
- 「第 X 次尝试」或任何尝试计数
- Boss 倒计时数字

---

### 7.3 图标语言

**图标造型原则：建筑雕刻的平面投影**

所有图标继承 Section 3 的绝对规则（无有机曲线），并延伸为：**所有图标必须能被解读为某种建筑元件的正视图**。

- **线框：** 单像素细轮廓 + 内部几何填充，无渐变，无阴影。填充颜色使用当前场景调色板色彩较底色亮度提升 20%。
- **允许形状：** 菱形（格挡/时机）/ 截断三角形（阶段门槛）/ 多边形嵌套（等级/强度）/ 锯齿圆环（充能/冷却，偶数锯齿 ≥8 齿）
- **禁止：** 圆形图标 / 心形 / 5 角星形（5 点是自然生长形；8 点晶体星形已专属格挡指示器）
- Boss 所在场景的建筑拱形语言映射到其 Boss 阶段刻度装饰元件。图标不是中立的，每个图标带有神庙记忆。

> *设计测试*: 将图标缩小至 16×16px，仍能清楚区分其用途类别；放大至 128×128px，图标应当像一枚铸造徽章，而非一张向量插画。

---

### 7.4 UI 动态词汇

**核心原则：机械精确 + 一次性断裂，没有弹性**

运动像齿轮啮合，停止像刀落砧板。**禁止任何 ease-out-back（回弹）或 bounce（弹跳）缓动**。

**关键词：** 机械咬合 / 晶体断裂 / 霜封（快速凝固而非渐变淡出）

**玩家血条受伤：**
- 伤害触发 → 血条在 2 帧（33ms）内跳切至新长度（不做平滑过渡），然后在 8 帧内显示残留「余血」线（颜色为消失血量段的颜色 +30% 亮度），余血线在 12 帧内线性衰减消失。
- 禁止：任何形式的平滑滑动作为主动画——血条不「流动」。

**Boss 血条受击：**
- 延迟 4 帧（67ms）后跳切——一瞬蓄力感，然后断裂。
- 锯齿上沿在 6 帧内微震动（±2px，三次），象征神的愤怒。
- 阶段 tick 线被压过时：tick 线发枯骨白光（非霜白）持续 0.3s + 低频重击音效——这是阶段过渡的主动信号，不能只靠静态标记。tick 线颜色永久变为哑光金色，不可逆。

**格挡指示器（成功格挡）：**

格挡信号有两个视觉阶段，**形态必须明确区分**：

| 信号 | 来源 | 形态 | 语义 |
|---|---|---|---|
| 窗口开启（输入提示） | Boss 腐化断裂点 | 8 点星芒**聚合**（向内收缩姿态） | "现在行动" |
| 成功确认（反馈） | 玩家角色位置 | 8 点星芒**爆发**（向外释放），0 帧到满尺寸 | "你做到了" |

成功确认星形：静止 12 帧后以「碎裂」方式消失——8 个臂各自独立飞出（臂延伸方向，8–16px），Alpha 在 4 帧内降至 0。禁止旋转动画、脉冲闪烁、尺寸呼吸感。

**格挡多模态备份（四信号并行，缺一不可）：**

| 信号通道 | 窗口开启 | 成功确认 |
|---|---|---|
| 视觉形状 | 8 点星芒聚合 + 边缘硬化 | 8 点星芒爆发 + 全屏边缘冷光 1 帧 |
| 视觉亮度 | 局部亮度提升 40%（≥2 帧持续） | 全画面冷光瞬时闪烁（1 帧） |
| 音效 | 高频「凝聚音」（<0.2s） | 冲击音 + 谐波尾音 |
| 手柄振动 | 轻振（0.15s，左扳机） | 重振（0.2s，双马达异步） |

振动必须在无障碍选项中可关闭，关闭后其余三信号通道仍完整有效。

**Lore 面板入场：**
左右两半从各自方向以 6 帧线性运动滑入（无缓动），在中线接触时产生 1 帧整体亮度 +15% 的石材碰撞感，随后稳定。文字在面板稳定后 3 帧内同时显现——像揭幕，不像打字。

---

### 7.5 逐屏艺术指导

#### 战斗 HUD

**核心指令：HUD 的首要职责是让自己消失**

- 整体 HUD 不透明度：85%。
- 玩家低血状态：当血量进入最后 1 格（或 ≤20%）时，血条外框触发慢速亮度脉冲（0.8s 周期，±15%），颜色保持不变——使其从背景中分离，但不侵入视觉注意力。颜色方案：锈金 #8B6914（「失去的权威」与「生命流失」语义对齐）。
- **HUD 在任何情绪状态下保持冷静**——不做边框变红、不做心跳震动。战场的环境光（Section 6 负责）可以随死亡临近改变，HUD 自身不参与。

**Boss 血条色盲安全补充：** 每个 Boss 血条在其 tick 标记旁附加该 Boss 的 16×16px 简化剪影图标（纯轮廓），颜色为辅助识别，图标为主识别手段。

> *设计测试*: 在战斗最激烈帧中，用色相隔离工具检查 HUD 色彩是否与任何 Boss 特征色（全饱和度，Section 4 禁区）发生视觉混淆。

#### 主菜单

**视觉处理：神庙前室（Antechamber）**

- 背景：Hub 区域固定镜头（冷蓝色调废墟神庙前厅），3 层轻微视差（远景废墟 / 中景柱廊 / 前景地面裂缝），静止宽幅插图，仅环境粒子（灰烬/光尘）在流动。
- 菜单选项：垂直列，左对齐，基准线在屏幕左侧三分之一处，Serif Bold 40px，字间距 +5%。
- **选中态：** 选项左侧出现一条 2px 垂直短线（高度等同行高），颜色为霜白邻近色 #D8E8F5（非霜白本身）。这条线是光标，是刻刀的痕迹。未选中态不透明度 65%，选中态 100%，4 帧线性过渡。
- 游戏 Logo（刃响）：居于菜单选项正上方，垂直间距为 Logo 高度的 0.8 倍。Logo 字形为手工刻制感，非字库字形（美术部门专项制作）。

> *设计测试*: 主菜单截图不看任何文字，3 秒内应能判断「这是一款成人视觉语言、神话题材的动作游戏」。

#### Boss 传说面板（击败后揭示）

**这是游戏的主要叙事时刻——神的讣告，遗址的碑铭。**

- **进入：** 击败动画结束，画面不切黑。在原战场上叠加半透明霜色蒙版（#1A2030 / 85%），使战场颜色几乎褪去但轮廓仍在，Boss 形体作为剪影可见于背后，像残影。
- **面板尺寸：** 屏幕宽度的 40%，从画面中轴线偏左 5%（视觉重心在左，文字展开向右延伸，构图留有喘息）。面板背景 #0D1218，边框 2px 哑光金线，内边缘 1px 内凹阴影线。无任何发光效果。
- **内容分层（从上至下）：**
  1. Boss 名称：Serif Bold 64px，哑光金色 #C8A96E
  2. 称谓行：Serif Regular 28px，霜白邻近色 #D8E8F5（如「腐化之音 / 第三位堕神」）
  3. 分隔线：0.5px 哑光金线，宽度 80% 面板宽
  4. 传说正文：Serif Regular 20px，暖灰色 #A89F94，行间距 1.6 倍，最多 4 段
  5. 插图区（下半区）：Boss 局部特写插图（非全身——选取最能承载叙事的部位），手绘宗教图像风格，无背景，直接置于深碑石色上
  6. 拱顶区域：Boss 专属符文或纹章，哑光金色填充，刻于拱内
- **退出：** 玩家按任意键，面板以「石板收拢」方式退出（逆入场，16 帧线性），蒙版 24 帧内淡出，Hub 过场直接接续。没有「返回」按钮——完成阅读即是完成仪式。

> *设计测试*: 面板截图在不附任何游戏说明的情况下，5 秒内让观看者理解「这是某个悲剧性存在的墓志铭」。若首先联想到「成就解锁」，视觉处理失败。

#### 死亡屏幕 / 重试

**不是惩罚，是一页翻过去的书页。**

时长上限 1.5 秒，任意时刻可跳过，绝对不使用「你死了」或任何类似文字。

**时间轴：**
- **0–200ms：** 死亡动画最后一帧，叠加全屏 40% 红色瞬闪（#CC2200），持续 2 帧即退出。
- **200–600ms：** 画面快速褪色至深灰 #0A0A0C（非纯黑——纯黑是空无，深灰是沉默），线性过渡 400ms。
- **600–1200ms：** 屏幕中央出现该 Boss 的**相位符号（Phase Symbol）**——Boss 身上某个视觉元素的最小几何抽象，霜白邻近色绘制，无动画，直接出现，静止。这是唯一显示的视觉元素，无文字。
- **1200–1500ms：** 符号淡出（线性 300ms），画面切回 Boss 战开始位置。
- **任意帧：** 玩家输入直接跳至 1500ms → 立即重开。

**相位符号的教育价值：** 玩家多次失败时，他们会开始记住这个符号的细节——对符号越熟悉，说明越了解这个 Boss。符号本身是一道谜题，这是「死亡是教师」的视觉化。

**绝对禁止：** Retry/重试按钮 / 加载进度条 / 死亡计数 / 成就/掉落提示 / 任何提示文字

---

### 7.6 新手引导

**原则：一次性存在提示，不解释机制**

本游戏无传统教程。视觉预警系统即教程，**但**新玩家不知道「格挡键存在」，可能一直尝试躲避或攻击而无法进入学习回路。

**一次性格挡键提示（唯一引导内容）：**
- **触发时机：** 第一个 Boss 的第一次攻击前摇出现时（仅首次）
- **显示方式：** 画面下方浮现当前输入设备对应的格挡键图标（24×24px 最小尺寸，直角几何形，与 UI Shape Grammar 一致）
- **持续时间：** 2 秒后自动消失，此后**永不再出现**
- **内容约束：** 仅显示键位图标，无任何文字说明——这不是「按此键格挡」的指令，这是「这个键存在」的标记

所有输入提示必须以 `InputMap` action 绑定形式渲染（非硬编码图标），支持键鼠/手柄之间的即时热切换。

---

### 7.7 输入与无障碍规格

- **输入设备热切换：** 玩家在会话中间切换输入设备，所有界面输入提示图标**立即更新**（无需重启）。
- **鼠标交互热区：** 所有可点击操作区域 ≥ 44×44px（Fitts's Law 最小目标尺寸）。
- **手柄导航焦点指示器：** 使用几何外框高亮（倒角矩形外框，亮度提升 25%），不依赖颜色。
- **文字背板：** 文字下方始终有不透明度 ≥ 90% 的暗色背板，不得将文字直接叠加在游戏场景图像上。
- **玩家血条空槽：** 空槽内部填充虚空墨 #0D0B1A（非透明），与剩余血量的枯骨白之间亮度差约 70%，灰度模式下完全可辨。
- **振动：** 必须在选项中提供关闭振动的选项；关闭后格挡反馈的其余三信号通道（视觉形状、视觉亮度、音效）仍完整有效。

---

## 8. Asset Standards

*Art Direction + Technical Constraints integrated. Technical conflicts resolved as documented.*

---

### 8.1 文件格式与导出

| 文件类型 | 源文件格式 | 导出格式 | 色彩空间 | 色彩深度 |
|---|---|---|---|---|
| 角色 / Boss / 环境 | `.psd` 或 `.kra` | `.png` | sRGB | 8-bit per channel |
| VFX 粒子纹理 | `.psd` 或 `.kra` | `.png` | sRGB | 8-bit per channel |
| 动画帧序列 | `.psd` 或 `.kra`（单层合并帧） | `.png` 帧序列 | sRGB | 8-bit per channel |
| UI 元素 | 向量图 / `.psd` | `.png` | sRGB | 8-bit per channel |
| 色板参考文件 | `.ase` / `.gpl` | 随交付包附送（不导入引擎） | sRGB | — |

**禁止使用的格式（及原因）：**
- `.webp` — 有损压缩破坏手绘笔触高频细节，放大时产生 artifact
- HDR / `.exr` — 本游戏使用 Diffuse Baked 非 PBR，不需要 HDR 色域
- 16-bit per channel — 手绘风格的美感来自色彩的主动限制，过高位深产生画师无法控制的中间值，与第 4 节 7 色主调色板哲学相悖

**源文件必须保留图层结构**，不得合并后交付——QA 需要单独关闭 telegraph 图层进行视觉合规审核（Section 1 Principle 2）。

---

### 8.2 文件命名规范

**总体结构：**
```
[category]_[subject]_[descriptor]_[variant].[ext]
```
所有字段小写英文，下划线分隔，无空格、连字符、驼峰。

**Category 缩写：**
`char`（角色）/ `boss`（Boss）/ `env`（环境）/ `ui`（界面）/ `vfx`（特效）/ `anim`（动画）/ `ref`（参考，不导入引擎）

**Subject：** 对象正式代号（Boss 使用其英文代号，如 `ironbell`、`ashveil`；环境使用关卡代号，如 `sanctuary`）

**Descriptor 常用词：**
- 动画状态：`idle` / `attack` / `parry` / `death` / `intro`
- 视觉层：`base`（基础）/ `telegraph`（预警）/ `glow`（光效）/ `silhouette`
- 尺寸层级：`large` / `mid` / `small`
- 帧编号：`01`–`24`（两位数补零）
- LOD：`lod0`（全分辨率）/ `lod1`（战斗视距）

**命名示例：**
```
boss_ironbell_idle_base_lod0_01.png
boss_ironbell_attack_sweep_telegraph_lod0_04.png
boss_ironbell_idle_base_lod1.png
char_player_parry_base_lod0_01.png
env_sanctuary_pillar_large_lod0.png
ui_btn_primary_idle.png
vfx_ironbell_charge_soft_large.png
vfx_ironbell_slash_hard_large.png
```

每个 Boss 拥有独立命名空间（subject 字段），确保 Boss 色彩身份系统在文件系统层面强制隔离（Section 4）。

---

### 8.3 纹理分辨率分级

**所有分辨率必须为 2 的幂次（Power of Two）。**

| 资产类别 | 标准分辨率 | 最大 |
|---|---|---|
| Boss 全身（LOD0，暂停欣赏） | 2048×2048 | 2048×2048 |
| Boss 全身（LOD1，战斗视距） | 64×64px 等效 | 256×256 |
| Boss 局部特写 | 1024×1024 | 1024×1024 |
| 玩家角色 | 512×512 | 512×512 |
| 环境前景结构（大型） | 2048×2048 | 2048×2048 |
| 环境中景道具 | 1024×1024 | 1024×1024 |
| 环境小型道具 | 512×512 | 512×512 |
| 背景层（远景/中远景） | 2048×1024 | 4096×2048 |
| UI 图标（几何型） | 64×64 | 128×128 |
| UI 大型元素（立绘、封面）| 1024×1024 | 2048×2048 |
| VFX 粒子纹理（软边缘） | 128×128 | 256×256 |
| VFX 预警纹理（硬边缘） | 256×256 | 512×512 |

**Boss LOD 双轨制说明：**
- LOD0 服务于「Art Is Story」支柱：Boss 介绍画面和暂停欣赏时的圣像品质
- LOD1 服务于「Read to Win」支柱：战斗中瞬读色块剪影，必须**手工制作**（非自动缩放——自动缩放无法做出「保留剪影、丢弃材质」的语义化决策）

---

### 8.4 LOD 层级期望

**本游戏使用语义化 LOD（非距离触发），LOD 切换由游戏逻辑控制。**

| 资产类别 | LOD 层级数 | 触发条件 |
|---|---|---|
| Boss 角色 | 2 级 | LOD0：介绍 / 暂停；LOD1：战斗实时状态 |
| 玩家角色 | 1 级 | 始终使用单一分辨率 |
| 环境前景结构 | 2 级 | LOD0：静止状态；LOD1：战斗时远景简化 |
| 其余资产 | 1 级 | 无需分级 |

**LOD1 视觉测试（必须通过）：**
在 64px 高度下，以下三个问题必须全部可目视回答：「这是哪个 Boss？」「它是待机还是攻击前摇？」「攻击方向是左还是右？」若任一问题无法回答，LOD1 设计不合格。

---

### 8.5 导出哲学

**每个资产交付包必须包含：**
1. 源文件（含图层，未合并）
2. 合并导出 PNG（已按尺寸规格裁切）
3. 图层清单（`.txt`，Boss 资产为强制要求）
4. 色彩抽样文件（`.ase`），用于核对第 4 节色板一致性

**Boss 资产额外要求：**
- Telegraph 层单独导出为独立 PNG（非合并），QA 单独审核预警层硬边缘合规性
- LOD1 版本手工制作（非自动缩放）

**明确不需要提交（及原因）：**

| 不需要的内容 | 原因 |
|---|---|
| Normal Map | Diffuse Baked 非 PBR，光照由画师直接绘制在 Diffuse 层 |
| AO Map / Roughness / Metallic | 同上，均已 baked 进 Diffuse |
| Specular Map | 高光为画师在 Diffuse 层的手绘决策，非引擎计算 |
| Trim Sheet | 3D 技术，对 2D 精灵动画无效 |
| Sprite Atlas（美术侧） | Atlas 合并由 Technical Artist 在 Godot Import 侧处理，美术按帧交付独立 PNG |

---

### 8.6 动画资产规格

**交付格式：独立帧 PNG 序列，不使用 Spritesheet**

原因：Boss 动画帧包含 telegraph 层，需要独立校验，Spritesheet 会使多图层审核极为困难。

**帧命名：**
```
[category]_[subject]_[animation_name]_[layer]_[frame_number].png
```
帧编号两位数补零，从 `01` 开始；同一动画所有层须帧数对齐（即使部分帧为空白透明）。

**图层分离交付（Boss 攻击动画必须）：**

| 图层 | 内容 | 强制/可选 |
|---|---|---|
| `base` 层 | Boss 形体动画，无预警信息 | 强制 |
| `telegraph` 层 | 纯预警视觉信息，背景透明 | 强制 |
| `glow` 层 | 额外光效，蓄力阶段自发光 | 可选 |

**帧率标准：**

| 动画类型 | 标准帧率 | 最大帧数 |
|---|---|---|
| Boss 攻击动画（含预警） | 24 fps | 48 帧（2 秒） |
| Boss 待机动画 | 12 fps | 96 帧（8 秒） |
| Boss 出场动画 | 24 fps | 120 帧（5 秒） |
| 玩家角色动画 | 24 fps | 24 帧（1 秒） |
| VFX 打击帧 | 30 fps | 16 帧 |
| VFX 氛围粒子 | 12 fps | 16 帧/循环 |

帧动画 Sprite Sheet 的帧边界设置 **2px 空白间隔（padding）**，防止 Linear filter 下帧间渗色。

---

### 8.7 VFX / 粒子资产规格

**核心分类：Soft VFX（软边缘）vs. Hard VFX（硬边缘），必须在文件名和交付包中明确区分**（命名使用 `soft` / `hard` 描述符）。

| VFX 类别 | 视觉特征 | 功能 | Alpha 边缘 | 色彩饱和度 |
|---|---|---|---|---|
| **Soft VFX** | 羽化边缘、低对比度 | 氛围、余韵、场景情绪 | 羽化宽度 ≥ 纹理宽度 30% | 低饱和度，同 Boss 色温 |
| **Hard VFX** | 锐利轮廓、最大饱和度 | 攻击预警、危险标识 | 羽化宽度 ≤ 2px | 饱和度 ≥ 90% (HSL S) |

**Hard VFX 硬边缘合规测试：** 将纹理缩小至 64×64px，边缘仍须清晰可辨。若缩小后边缘模糊，说明原始边缘硬度不足，退回修改。

**VFX 色彩隔离规则：** 任何 VFX 纹理的色相，不得在两个不同 Boss 的 VFX 包中同时出现（功能性复用例外，如通用白色打击闪光）。违反此规则会在场景切换时产生 Boss 身份混淆（与 Section 2「每个 Boss 色调即身份」原则冲突）。

---

### 8.8 Godot 4.6 技术约束

#### 贴图内存与压缩

**贴图内存预算：** 单场景同时驻留 GPU 内存总量 ≤ **294MB**（未压缩）。启用压缩后可扩展约 4 倍容量。

**Hub ↔ Arena 场景切换时必须卸载上一场景贴图**，不允许两个 Boss Arena 贴图集同时驻留内存。

**压缩格式（PC / Windows D3D12）：**

| 贴图类型 | 推荐压缩格式 |
|---|---|
| 普通不透明贴图 | BC1 (DXT1) |
| 带透明通道贴图 | BC3 (DXT5) |
| Boss 正面立绘、玩家角色（视觉质量关键） | BC7 或 Lossless |
| 大型背景结构 | BC1/BC3（优先节省内存） |

**注意：** BC 块压缩对手绘纯色区域比 PBR 纹理更敏感，可能产生 banding。Boss 贴图和玩家贴图在导入后必须在目标平台预览验证，必要时逐资产切换至 BC7 或 Lossless。

#### Godot 4.6 Import 关键设置

| 贴图类别 | Mipmaps | Filter | Fix Alpha Border | 注意 |
|---|---|---|---|---|
| 大型背景结构 | **启用** | Linear | 启用 | |
| 中型道具 | **启用** | Linear | 启用 | |
| 小型道具 | 启用（道具）/ **禁用**（VFX Sprite Sheet）| Linear | **VFX 必须启用** | |
| UI 元素 | **禁用** | Linear | 启用 | UI 固定分辨率，Mipmap 只会造成模糊 |
| 粒子 Sprite Sheet | **禁用** | Linear | 启用 | Mipmap 导致帧间渗色（bleeding） |

**硬性规则：**
- UI 贴图**禁止启用 Mipmaps**
- 粒子 Sprite Sheet**禁止启用 Mipmaps**
- 所有贴图必须是 **2 的幂次方尺寸**（POT），美术在画布阶段即应使用 POT 画布

#### Sprite Atlas 分组策略

| Atlas 分组 | 内容 | 卸载策略 |
|---|---|---|
| UI Atlas | 所有 HUD 元素、图标 | 全局常驻 |
| Player Atlas | 玩家角色所有动画帧 | 全局常驻 |
| VFX Atlas（每 Boss 一组）| 该 Boss 粒子纹理 | 随 Boss 场景卸载 |
| Environment Atlas（每 Arena 一组）| 该 Arena 中小型道具 | 随场景卸载 |
| 大型结构贴图 | 独立存放（尺寸已达单 Atlas 上限） | 随场景卸载 |

UI 贴图和游戏世界贴图**禁止混入同一 Atlas**（UI 在 CanvasLayer 渲染，混用不产生合批收益）。

#### Shader 与后处理

- 单帧激活的独立 shader program 数量 ≤ **16 个**（超出产生 pipeline state change 开销）
- **Shader Baker（Godot 4.5+）** 必须在正式发布前预编译所有 shader 变体——D3D12 首次 shader 编译慢，格挡结晶化首次触发时若未预编译会产生明显帧卡顿
- 屏幕空间效果通过 `Compositor + CompositorEffect` 实现（Godot 4.6 标准后处理链），不使用已废弃的 Viewport shader 链
- `canvas_item` shader 中使用 `SCREEN_TEXTURE` 时必须配置 `BackBufferCopy`，否则采样到上一帧内容

#### Godot 4.6 重要变更

- **D3D12 默认（4.6）**：Windows 上 D3D12 为默认渲染器。BC7 压缩在 D3D12 路径下兼容性优于 Vulkan，仍需在目标硬件验证。
- **Glow 在 Tonemapping 之前处理（4.6）**：格挡结晶光晕和 Boss 死亡余晖使用 Glow 效果的强度值不能沿用 4.5 以前的参数，必须在 4.6 版本重新调试。为防止 Glow 污染非格挡白色像素（违反霜白专属色原则），格挡 Glow 使用独立 CompositorEffect，仅对格挡渲染层应用，不使用全局 Glow。
- **TileMapLayer 替代 TileMap（4.3）**：所有地形和平台使用 TileMapLayer，禁止使用已废弃的 TileMap 节点。
- **Shader texture uniform 类型变更（4.4）**：`.gdshader` 文件中使用 `uniform sampler2D`，而非旧的 `uniform Texture2D`。

#### 灰烬君专项技术风险

灰烬君（白灰 Boss）的攻击预警无法依赖色相（见 Section 4 及 Section 6.6 灰烬君注），必须用明度对比 +40% + 形状扩张双重信号。在 Godot 4.6 中，对 Boss Sprite 特定区域进行 mask-based additive blending 需要专属 shader（`boss_ashking_telegraph.gdshader`）。此 shader 列为高优先级开发项，必须在 Vertical Slice 阶段验证可行性。

---

### 8.9 外包自检清单

外包团队每次提交资产附上此清单，美术总监依此进行首轮 QA：

**通用检查项（所有资产）：**
- [ ] 源文件已附（含图层，未合并）
- [ ] 导出 PNG 尺寸符合 8.3 分辨率表，且为 2 的幂次
- [ ] 文件命名符合 8.2 规范
- [ ] 色彩空间：sRGB，色彩深度：8-bit per channel
- [ ] 色彩抽样文件（.ase）已附，色相在对应 Boss 色板范围内
- [ ] 无 Normal Map、AO Map、Roughness Map

**Boss 资产额外检查项：**
- [ ] Telegraph 层已单独导出（独立 PNG，非合并）
- [ ] LOD1 版本（64px 高）已手工制作（非自动缩放）
- [ ] LOD1 视觉测试通过（Boss 身份 / 动作状态 / 攻击方向三问均可回答）
- [ ] Telegraph 层边缘硬度合规（64px 缩小测试边缘仍清晰）
- [ ] 图层清单文本文件已附
- [ ] VFX 色相未与其他 Boss 色标重叠

**动画资产额外检查项：**
- [ ] 以帧序列 PNG 交付（非 Spritesheet）
- [ ] 帧编号两位数补零，从 01 开始
- [ ] Base / Telegraph / Glow 层帧数对齐
- [ ] 帧率符合 8.6 规格表
- [ ] 单动画帧数未超过 8.6 最大帧数限制
- [ ] Sprite Sheet 帧间隔 ≥2px padding

**VFX 资产额外检查项：**
- [ ] Soft/Hard 类型在文件名中明确标注（`soft` / `hard` 描述符）
- [ ] Soft VFX：边缘羽化宽度 ≥ 纹理宽度 30%
- [ ] Hard VFX：边缘羽化宽度 ≤ 2px
- [ ] Hard VFX：主色饱和度 ≥ 90%（HSL S 值）
- [ ] Hard VFX：缩小至 64px 边缘仍清晰可辨

---

## 9. Reference Direction

本节列出 6 个参考来源。每个来源标注**借鉴什么**、**明确不借鉴什么**，以及关联的圣经章节——防止出现"我们在做 X 的翻版"的误读。参考是方向加法器，不是复制蓝图。

---

### REF-01 — Hollow Knight（Team Cherry，2017）

**借鉴什么**
- **黑暗厚度**：黑色不是缺席颜色，是有重量的物质。前景阴影、角色轮廓和背景虚空使用不同深度的黑色（#0D0B1A 为最深锚点），制造三维层次感。
- **负空间主导权**：画面中空白区域与内容区域比例至少 60:40。空是语言，不是待填充的缺口。
- **物质残存叙事**：不通过文字说明世界历史，通过遗留物体的形状和腐化程度暗示——残存的脊骨比墓志铭更有力量。

**明确不借鉴**
- 昆虫/小生物美学——刃响的神明是人形巨物，非虫形小怪。
- 横版冒险探索结构——刃响无探索，仅有 Boss 战。
- Hollow Knight 的"孤独忧郁"情感底色——刃响的暗是"神圣腐坏的辉煌"，不是"被遗忘的渺小"。

**关联章节**：Section 2（各状态情绪目标）、Section 6.7（前景道具密度）

---

### REF-02 — Blasphemous（The Game Kitchen，2019）

**借鉴什么**
- **宗教图像姿态语法**：受难、跪拜、高举、束缚——这些姿态在西班牙苦修传统中有精确的叙事含义。刃响从中借鉴「仪式姿态有含义」的原则：Boss 的起始姿态必须传达它的神话身份，而非纯粹的威胁感。
- **冻结的仪式感**：角色在神圣时刻"定住"——不是动作停止，是物理法则被信仰暂停。Boss 发动大招时的蓄力帧应有这种"世界屏息"的静止质感。
- **受苦即辉煌**：最受苦的形态往往视觉上最宏伟——腐化与荣耀不对立。

**明确不借鉴**
- 西班牙天主教具体图像（荆棘冠、十字架形态）——刃响使用东方神话语系，混入西方宗教符号会稀释身份。
- 像素艺术的精度质感——刃响是 HD 手绘，非像素。
- Blasphemous 的苦难是惩罚性的——刃响的苦难是自愿献祭性的，情感底色不同。

**关联章节**：Section 5.4（Boss 姿态语法）、Section 7.5（死亡界面仪式感）

---

### REF-03 — Bloodborne（From Software，2015）

**借鉴什么**
- **神圣与腐化的材质共存逻辑**：同一个表面同时是「曾经神圣的」和「正在腐化的」——不是两个图层叠加，是材质本身记录了两种状态的历史。黄金器皿上的血迹、大理石柱上的骨刺生长方式。
- **宏伟与扭曲的比例语言**：建筑超出正常人体尺度，但不荒谬——神明应该居住在这种尺度里。刃响 Boss 战场设计直接引用这个比例感。
- **武器即身份延伸**：玩家角色的武器是视觉叙事的核心载体，不是工具。玩家角色（行刑见证人）的武器形态必须承载世界身份。

**明确不借鉴**
- Bloodborne 的克苏鲁/洛夫克拉夫特宇宙恐怖美学——刃响的不安是「美丽腐坏」而非「理解禁忌」。
- 写实 PBR 材质流程——刃响使用风格化手绘，参照 Bloodborne 的是材质叙事逻辑而非制作管线。
- Bloodborne 的血腥内脏美学——刃响的血迹是仪式痕迹（过去时态），不是内脏展示。

**关联章节**：Section 3（材质形态语言）、Section 6.2（环境材质三层）

---

### REF-04 — Furi（The Game Bakers，2016）

**借鉴什么**
- **攻击预警的节奏语法：身体束缚 + 光爆发**：Boss 蓄力时躯体「收紧、压制、缩小」，释放时光效「爆发、扩张」——这个收缩/扩张节奏制造了攻击预警的戏剧张力。刃响的腐化光芒预警直接继承这个节奏结构。
- **一对一战斗的演出密度**：每个 Boss 都值得一段完整的视觉叙事——没有杂兵填充注意力，因此每个 Boss 的视觉设计必须承载全部观赏价值。
- **Boss 是表演者**：攻击不是威胁投射，是 Boss 在表演自身——玩家是观众与参与者双重身份。

**明确不借鉴**
- Furi 的赛博朋克/霓虹色彩系统——刃响的色彩是暗神话泥金，非电子霓虹。
- Furi 的枪械弹幕机制——刃响是纯近战 Boss 战。
- Furi 的叙事节奏（跑路 + Boss 轮流）——刃响无探索过渡段。

**关联章节**：Section 1 原则 2（预警是视觉高潮）、Section 5.4（Boss 攻击预警规范）、Section 6.8（舞台光源：预警灯）

---

### REF-05 — 王兵纪录片（《铁西区》2003，《和凤鸣》2007）

**借鉴什么**
- **纪念碑式衰败的构图语法**：构建超出画框的建筑体量——观众只能看到局部，但感知到整体的巨大。刃响的 Boss 战场背景直接使用这个原则：背景建筑不完整出现，压迫感来自不可见的延伸。
- **废弃即历史化**：空旷的工厂、锈蚀的机械不是"坏掉的"，是"曾经巨大的系统留下的遗迹"。刃响的废墟不是简单的脏，是权力规模留下的沉默证明。
- **存在感而非装饰性**：画面里的每个物体都在诉说自己曾经发生过什么，不只是填充空间。

**明确不借鉴**
- 纪录片的写实摄影质感——刃响是风格化手绘，借鉴的是构图原则而非材质质感。
- 王兵的压抑/绝望情感底色——刃响的废墟壮丽而非悲凉，是「神明曾在此」而非「人被遗弃于此」。

**关联章节**：Section 6.6（背景构图原则）、Section 6.7（前景叙事密度）

---

### REF-06 — 河鍋暁斎妖怪卷轴（19世纪日本，Kawanabe Kyōsai）

**借鉴什么**
- **东方剪影的唯一性传统**：江户/明治时代的妖怪绘物不从西方解剖学推导——它们有自己的姿态语法、比例逻辑和肢体延伸方式。刃响的 Boss 剪影必须在这个传统中被识别为"东方神物"，而非西方怪物加东方纹样。
- **流动与定格并存的形态**：暁斎的妖怪在极度动态（飘动、扭曲、旋转）和极度静止（凝视、等待、蓄势）之间切换——这个切换本身就是恐惧的来源。刃响的 Boss 待机动画应继承这个原则：大部分时间「极度庄严静止」，攻击时「极度流动爆发」。
- **墨色浓淡的信息层次**：笔墨的浓淡不只是美学，是叙事轻重——神圣核心用浓墨，腐化延伸用淡墨晕染。这对应刃响的三层腐化规则（神圣核心 / 辉煌延伸 / 腐化断裂）。

**明确不借鉴**
- 江户时代的滑稽妖怪（搞笑百鬼）——刃响不要幽默感，要庄严感。
- 平面浮世绘的颜色系统（朱红、金黄大色块）——刃响的颜色更暗、更多污浊混色，非浮世绘的鲜明原色。
- 卷轴画的水平展开构图——刃响是竖屏感知的 2D 战斗场景，构图轴不同。

**关联章节**：Section 3（形态语言与剪影哲学）、Section 5.2（Boss 剪影5项规则）

---

### 参考使用原则

> 六个参考来源应作为**方向加法器**而非**临摹蓝本**使用。
> 每次引用一个参考时，必须能回答：「我从这里借鉴的是什么原则，而不是什么外观？」
>
> 如果新资产让人第一反应是「这像 [参考名]」，说明借鉴方式有误——
> 应该是「这让我想到了 [情绪/原则]，但我不知道这是从哪来的」。
