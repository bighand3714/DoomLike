# Roadmap 4 — 战斗系统深化 · 设计文档

> 所有数值均为 `@export`，可在编辑器中直接调整。

---

## 1. 输入系统

### 1.1 按键映射

| 按键 | 动作名 | 功能 |
|:--|:--|:--|
| `W` `A` `S` `D` | `move_*` | 移动 |
| 鼠标 | `look` | 控制镜头 |
| 鼠标左键 | `primary_fire` | 主武器攻击（开枪 / 近战） |
| 鼠标右键 | `aim` | 自动瞄准（按住） |
| 滚轮向上 | `whip_throw` | 铁链 |
| 滚轮向下 | `whip_throw` | 铁链 |
| Left Shift | `dash_sprint` | 冲刺（配合 WASD 四方向，无方向键默认后冲刺） |
| `1` `2` `3` `4` | `weapon_slot_1~4` | 武器槽切换 |
| `R` | `reload` | 换弹（武器向上 90° 旋转 + UI 提示"换弹中···"） |
| `F` | `action_key` | 动作键（副武器攻击） |
| `Q` | 待定 | 待定 |
| `E` | 待定 | 待定 |
| Space | `jump` | 跳跃 |

### 1.2 与旧版差异

| 变更 | 旧 | 新 |
|:--|:--|:--|
| 滚轮 | 切武器 | 铁链触发（双向） |
| 切武器 | 滚轮 | `1` `2` `3` `4` 数字键 |
| 冲刺 | 无独立键 | Left Shift（四方向冲刺） |
| 右键 | 铁鞭挥鞭 | 自动瞄准（按住） |
| 铁链 | 右键触发 | 滚轮触发 |
| 处决 | R 键 | Q 键 / 待定 |

---

## 2. 战斗系统

### 2.1 COUNTER 系统

**规则**：敌人处于攻击动作时受到玩家攻击 → 眩晕值大幅上涨 + 短暂硬直 + 打断攻击动作。

- Counter 窗口：敌人 ATTACK 状态的全阶段（前摇 / 判定 / 后摇）
- 视觉效果：敌人青蓝色闪白 + HUD 显示 "Counter!"
- 若眩晕值满 → 强制进入眩晕状态

**信号流**：

```
Enemy._on_damaged() → 检测 is_in_attack_state
  → GameBus.counter_triggered.emit(enemy, position)
    → PlayerStatus 显示 "Counter!" 提示
    → 敌人青蓝色闪白
```

### 2.2 距离判定

| 档位 | 距离范围 | 定位 |
|:--|:--|:--|
| 贴身 (melee) | < 0.5m | 肉搏攻击范围 |
| 近距离 (close) | 0.5m ~ 1m | 近战武器攻击范围 |
| 中距离 (medium) | 1m ~ 2m | 中距离武器攻击范围 |
| 远距离 (far) | 2m ~ 5m | 远距离武器攻击范围 |
| 超远距离 (super_far) | > 5m | 超长武器攻击范围 |

> 敌方 AI、铁链效果、距离环均以此五档为统一基准。

### 2.3 铁链武器（副武器）

**基础参数**：

| 参数 | 默认值 | 说明 |
|:--|:--|:--|
| `whip_length` | 2.0m | 铁链最大有效长度 |
| `whip_damage` | 4.0 | 正常攻击伤害 |
| `whip_stun` | 40.0 | 正常攻击眩晕值 |
| `whip_cooldown` | 0.8s | 攻击冷却 |
| `grab_distance` | 1.5m | 抓取后敌人距离 |
| `dash_distance` | 5.0m | 冲刺处决距离 |
| `dash_speed` | 25.0m/s | 冲刺速度 |
| `dash_damage` | 60.0 | 冲刺对前方敌人伤害 |
| `dash_aoe_damage` | 30.0 | 冲刺 AOE 伤害 |
| `throw_speed` | 35.0m/s | 甩出速度 |
| `throw_damage` | 35.0 | 甩出伤害 |
| `execution_damage` | 999.0 | 处决伤害 |
| `execution_score_bonus` | 25 | 处决加分 |

**基础攻击**：铁链命中敌人 → 少量血量伤害 + 中量眩晕值。若目标有护甲 → 不造成伤害与眩晕。

**连招流程**：

```
滚轮(铁链) → 命中眩晕状态敌人 → 抓取（敌人显示在玩家左手侧）
  被抓取状态中：
    ├─ 右键 → 肉盾模式（敌人位于玩家正前方，抵挡攻击）
    │    ├─ 滚轮向下 → 冲刺处决（向前冲出，前方敌人大伤害+击退倒地）
    │    └─ 滚轮向上 → 甩出（敌人向前飞出，沿途敌人被撞飞倒地）
    └─ 倒地敌人 → 处决（Q键，999伤害+加分）
```

**倒地机制**：敌人倒地后判断自身状态 → 尝试起身。

---

## 3. 敌人系统

### 3.1 敌人属性（EnemyData @export）

| 属性 | 类型 | 说明 | 默认值 |
|:--|:--|:--|:--|
| `max_health` | float | 最大血量 | 100 |
| `max_stun` | float | 最大眩晕值 | 100 |
| `armor` | float | 护甲值（1 护甲 = 吸收 1 伤害） | 0 |
| `move_speed` | float | 基础移动速度 (m/s) | 4.0 |
| `weight` | float | 重量（影响击退 / 拉取抵抗力） | 70 |
| `height` | float | 身高 (m)，影响碰撞体尺寸 | 1.8 |
| `detection_interval` | float | AI 检测间隔 (s) | 0.5 |
| `score_value` | int | 击杀分数 | 10 |
| `spawn_cost` | int | 刷新消耗 | 1 |

### 3.2 敌人技能属性

**攻击技能参数**：

| 参数 | 说明 | 默认值 |
|:--|:--|:--|
| `attack_damage` | 攻击伤害 | 20 |
| `attack_range` | 攻击触发距离 (m) | 1.0 |
| `attack_windup` | 前摇时间 (s) | 1.0 |
| `attack_duration` | 判定窗口 (s) | 0.1 |
| `attack_recovery` | 后摇时间 (s) | 0.5 |
| `attack_cooldown` | 攻击冷却 (s) | 2.0 |

**防御技能参数**：

| 参数 | 说明 | 默认值 |
|:--|:--|:--|
| `shield_block_chance` | 举盾格挡概率 | 0.0 |
| `can_defend` | 是否具备防御技能 | false |

### 3.3 敌人状态

| 状态 | 说明 |
|:--|:--|
| `SPAWNING` | 入场 / 生成中 |
| `IDLE` | 默认待机 |
| `WALKING` | 走动（以基础移速接近） |
| `RUNNING` | 跑动（以 1.5 倍移速接近） |
| `ATTACK_PREPARE` | 攻击准备（前摇阶段） |
| `ATTACK_ACTIVE` | 攻击触发（判定窗口） |
| `ATTACK_RECOVER` | 攻击完成（后摇阶段） |
| `DEFENDING` | 防御状态 |
| `PAIN` | 受击硬直 |
| `STUNNED` | 眩晕（可被抓取） |
| `GRABBED` | 被铁链抓取 |
| `KNOCKED_DOWN` | 倒地 |
| `EXECUTED` | 被处决中 |
| `DEATH` | 死亡 |

> 攻击系状态（PREPARE / ACTIVE / RECOVER）统一视为 ATTACK 阶段，Counter 窗口贯穿全程。

### 3.4 敌人动作

| 动作 | 说明 | 动画表现 |
|:--|:--|:--|
| 默认动作 | 待机 | 站立呼吸 |
| 走动动作 | 慢速接近 | 行走循环 |
| 跑动动作 | 快速接近（1.5× 移速） | 奔跑循环 |
| 技能动作 | 攻击 / 防御，随敌人类型而异 | 武器挥砍 / 举盾 |
| 死亡动作 | 死亡倒地 | 后仰倒地 |

### 3.5 敌人 AI 决策框架

**检测周期**：每 `detection_interval` 秒执行一次（而非每帧）。

**决策流程**：`入场 → 判断玩家位置与距离 → 决定策略 → 死亡`

**通用策略表**（具体敌人可覆写）：

| 距离档 | 通用行为 |
|:--|:--|
| 超远距离 (>5m) | RUNNING 跑动接近玩家 |
| 远距离 (2~5m) | WALKING 接近，有防御技能则 DEFENDING |
| 中距离 (1~2m) | 检测周围近战敌人数，>2 则侧翼包抄，否则接近 |
| 近距离 (0.5~1m) | 概率进入攻击或防御 |
| 贴身 (<0.5m) | 直接攻击 |

---

## 4. 新敌人：普通近战兽人 (OrcEnemy)

### 4.1 属性

| 属性 | 值 |
|:--|:--|
| 血量 | 100 |
| 眩晕值 | 100 |
| 护甲值 | 100 |
| 移动速度 | 标准移速（约 4.0 m/s） |
| 重量 | 70 |
| 身高 | 1.5m |
| 检测间隔 | 0.5s |

### 4.2 CSG 模型

| 部位 | 造型 | 尺寸 | 颜色 |
|:--|:--|:--|:--|
| 身体 | CSGCylinder3D | r=0.4, h=1.0 | 墨绿 |
| 头 | CSGSphere3D | r=0.2 | 稍亮绿 |
| 左手 | CSGBox3D | 0.15³ | 墨绿 |
| 左手盾 | CSGCylinder3D（扁） | r=0.3, h=0.05 | 灰褐 |
| 右手 | CSGBox3D（斧柄） | 0.04×0.4×0.04 | 褐 |
| 右手斧刃 | CSGBox3D | 0.15×0.08×0.2 | 灰 |
| 左腿 | CSGBox3D | 0.2×0.4×0.2 | 墨绿 |
| 右腿 | CSGBox3D | 0.2×0.4×0.2 | 墨绿 |
| 碰撞体 | CapsuleShape3D | r=0.4, h=1.5 | — |

### 4.3 技能

#### 攻击技能

**攻击流程**：

```
1. 判定：敌距玩家 ≤ 1m → 发动攻击
2. 接近：快速跑至距玩家 0.5m（已 ≤0.5m 则跳过）
3. 前摇 (ATTACK_PREPARE, 1s)：右手斧子上举，模型旋转 + 发光提示
4. 判定 (ATTACK_ACTIVE, 0.1s)：
   - 攻击框：0.5m(长) × 0.5m(宽) × 0.5m(高) 立方体，出现在右手前方
   - 动画：斧子从右上方向左下方斜劈
5. 后摇 (ATTACK_RECOVER, 0.5s)：恢复默认姿态
```

**攻击参数**：

| 参数 | 值 |
|:--|:--|
| 攻击伤害 | 25 |
| 攻击触发距离 | 1m |
| 前摇 | 1s |
| 判定窗口 | 0.1s |
| 后摇 | 0.5s |
| 攻击冷却 | 2s |

#### 防御技能

- **举盾**：进入 DEFENDING 状态，受击时扣除护甲而非血量
- **限制**：举盾期间无法跑动（仅可走动）

### 4.4 Counter 交互

- 攻击全阶段（PREPARE / ACTIVE / RECOVER）受击 → 眩晕值大幅上涨
- 眩晕值满 → 强制进入 STUNNED 状态
- 1s 前摇 = 玩家充足的 Counter 反应窗口

### 4.5 AI 逻辑

| 距离档 | 行为 |
|:--|:--|
| 超远距离 (>5m) | RUNNING 跑动接近玩家 |
| 远距离 (2~5m) | WALKING + DEFENDING 举盾接近 |
| 中距离 (1~2m) | 判断近距离敌人数：>2 则举盾横向移动，≤2 则举盾靠近 |
| 近距离 (0.5~1m) | 默认 DEFENDING，中等概率发动攻击 |
| 贴身 (<0.5m) | 直接攻击 |

### 4.6 文件清单

| 文件 | 说明 |
|:--|:--|
| `assets/enemies/orc_melee.tres` | EnemyData 资源 |
| `scripts/enemy/orc_enemy.gd` | 兽人脚本（继承 Enemy） |
| `scenes/enemies/orc_enemy.tscn` | 打包场景 |

---

## 5. 刷怪系统：波次制

### 5.1 WaveData 资源

```gdscript
class_name WaveData extends Resource
@export var wave_number: int = 1
@export var enemy_entries: Array[Dictionary]  # [{enemy_id: "orc_melee", count: 5}, ...]
@export var spawn_interval: float = 2.0       # 波内生成间隔 (s)
@export var rest_time: float = 8.0            # 波间休息时间 (s)
```

### 5.2 波次流程

```
波次开始 → GameBus.wave_started.emit(wave_number)
  → 按 spawn_interval 逐只生成敌人
  → 全部生成完毕
  → 等待场上敌人清零 + rest_time
  → 下一波
```

### 5.3 HUD 提示

监听 `GameBus.wave_started` → 居中大字显示 "第 N 波" → 2s 后渐隐消失。

---

## 6. UI / 视觉反馈

### 6.1 受击方向指示器

- 屏幕边缘弧形箭头，指向伤害来源方向
- 红色半透明，1s 渐隐
- 新建 `scripts/ui/hit_direction_indicator.gd`

### 6.2 小地图

- 屏幕角落 150×150 圆形
- `_draw()` 绘制：玩家绿点 + 敌人红点 + 玩家朝向箭头
- 每 0.2s 刷新
- 新建 `scripts/ui/minimap.gd`

### 6.3 玩家脚下距离环

三个贴地圆环（ImmediateMesh torus，Y=0.05），随玩家移动：

| 环 | 半径 | 对应距离档 | 透明度 |
|:--|:--|:--|:--|
| 红环 | 0.5m | 贴身边界 | 0.3 |
| 黄环 | 1.0m | 近距离边界 | 0.2 |
| 绿环 | 2.0m | 中距离边界 | 0.15 |

### 6.4 准星距离反馈

| 状态 | 准星表现 | 颜色 |
|:--|:--|:--|
| 无目标 | 默认十字 | 绿 |
| 敌人在武器射程内 | 十字 | 蓝 |
| 命中敌人 | X 型交叉线 | 红 |
| Counter 触发 | 特殊闪白 | 青蓝 + "Counter!" |

- 0.3s 保持计时器防止闪烁

### 6.5 命中 X 字确认

- 命中敌人时显示 45° / -45° 红色交叉线
- 0.12s 渐隐消失
- 已实现，保持不变

### 6.6 地图边缘雾

- ArenaLevel 深度雾（`FOG_MODE_DEPTH`）
- 各关卡颜色：荒漠沙黄 / 熔岩暗红 / 测试灰色
- 已实现，保持不变

---

## 7. 附录：全部 @export 参数清单

### 7.1 WeaponData

```
damage, max_range, fire_mode, fire_rate,
mag_size, reserve_ammo, stun_damage, knockback_force,
infinite_ammo, is_melee, melee_range
```

### 7.2 WhipData（铁链）

```
whip_length, whip_damage, whip_stun, whip_cooldown,
grab_distance, dash_distance, dash_speed,
dash_damage, dash_aoe_damage,
throw_speed, throw_damage,
execution_damage, execution_score_bonus
```

### 7.3 EnemyData（新增）

```
armor, weight, height, detection_interval,
shield_block_chance, can_defend, spawn_cost
```

### 7.4 PlayerController（新增）

```
sprint_speed_multiplier, ads_sensitivity_mult
```

### 7.5 WaveData

```
wave_number, enemy_entries, spawn_interval, rest_time
```

### 7.6 UI 参数

```
受击方向指示器：尺寸、颜色、透明度、淡出时间
小地图：尺寸、刷新间隔、颜色
距离环：各环半径、颜色、透明度
准星：颜色过渡时间、X 型持续时间
```

---

## 8. 实施顺序

```
Phase 1  输入重映射            ← 基础，影响所有后续
Phase 2  敌人系统增强           ← Counter + 新状态 + 护甲
Phase 3  铁链连招更新           ← 配合新按键 + 倒地/处决
Phase 4  兽人敌人              ← 依赖 Phase 2 新状态
Phase 5  波次刷怪              ← 独立，需要 Phase 4 做测试
Phase 6  UI 增强               ← 独立，可并行
Phase 7  测试场景 + @export 调参 ← 最终验证
```

Phase 1–2 必须先做，Phase 3/4/5/6 可部分并行。

---

## 9. 设计笔记

### 关键风险

1. **状态枚举膨胀**：新增 PREPARE/ACTIVE/RECOVER/DEFENDING/KNOCKED_DOWN 后共 14 个状态。旧敌人不使用的状态自然不会被触发，向后兼容。
2. **滚轮冲突**：滚轮双向触发铁链，确保 WeaponManager 不再消费滚轮事件。
3. **右键功能迁移**：右键从铁鞭改为自动瞄准，铁鞭改为滚轮。需确保所有相关代码同步更新，不留残留输入监听。
4. **处决键变更**：处决从 R 改为 Q（或待定），需更新铁链状态机中的处决逻辑和 HUD 提示。
5. **护甲对铁链免疫**：有护甲的敌人免疫铁链伤害和眩晕，需在命中判定中优先检查护甲。

### 设计原则

- 所有数值 `@export`，编辑器可调
- 新旧敌人共存，不破坏已有功能
- 每个系统独立可测，不互相阻塞
- 距离判定五档为全系统统一基准
