# Roadmap 4 — 战斗系统深化计划

## Context

Roadmap 3 完成后，项目已有完整的4武器槽、铁鞭连招、标准敌人、掉落系统。用户提出碎片化的下一步设计笔记，涵盖：按键重映射、Counter核心系统、铁鞭距离差异化、新敌人（持盾兽人）、波次刷怪、UI增强（受击方向/小地图/距离环/准星变色）。本计划将这些碎片整合为可执行的分阶段路线。

---

## Phase 1: 按键重映射（基础，影响所有后续工作）

### project.godot 输入映射变更

| 新增/修改 | 动作名 | 绑定键 | 用途 |
|-----------|--------|--------|------|
| 新增 | `dash_sprint` | Left Shift | 独立冲刺 |
| 新增 | `action_key` | F | 动作键/副武器攻击 |
| 新增 | `weapon_left` | Q | 左手武器/上一把武器 |
| 新增 | `weapon_next` | E | 下一把武器 |
| 修改 | `whip_throw` | Wheel Up + Wheel Down | 双向滚轮触发铁鞭 |

### 代码变更

- **`scripts/weapon/weapon_manager.gd`**: 删除滚轮切武器逻辑，替换为 `weapon_left`(Q) / `weapon_next`(E) 监听。抓取中不切武器。
- **`scripts/weapon/iron_whip.gd`**: 挥鞭触发从 `secondary_fire`(右键) 改为 `whip_throw`(滚轮)。盾牌模式仍用 `secondary_fire` 但仅在 GRABBING 状态下响应。处决保持 R 键。
- **`scripts/weapon/weapon_node.gd`**: 添加 F 键副武器攻击和右键瞄准的输入监听骨架。
- **`scripts/player/player_controller.gd`**: 添加 `dash_sprint`(Shift) 冲刺逻辑——按住时移速×1.5。

---

## Phase 2: 敌人系统增强（Counter 基础 + 新属性 + 新状态）

### EnemyData 新增字段（全部 @export）

```gdscript
@export var armor: float = 0.0           # 护甲值
@export var height: float = 1.8          # 身高(m)，影响碰撞体
@export var shield_block_chance: float = 0.0  # 举盾格挡概率
@export var detection_interval: float = 0.5   # AI检测间隔(s)
```

### EnemyState 扩展

```
现有: SPAWNING, IDLE, CHASE, ATTACK, PAIN, STUNNED, GRABBED, EXECUTED, DEATH
新增: WALKING, RUNNING, DEFENDING
保留 CHASE 向后兼容，新敌人使用新状态
```

### Physics-based Armor 护甲系统

**`scripts/damage/damageable.gd`**: 添加 `armor` 属性（敌人用，区别于玩家的护甲吸收机制）。
- 敌人护甲：直接减伤，每点护甲吸收1点伤害（与玩家护甲50%吸收不同）
- 护甲归零后伤害全扣血量

### Counter 系统（核心机制）

**`scripts/enemy/enemy.gd` → `_on_damaged()`**: 新增 counter 判定：
- 若敌人处于 ATTACK 状态且受击 → 眩晕值直接清零 → 强制进入 STUNNED 状态
- 若敌人处于 ATTACK 状态且受击 → 特殊视觉反馈（青蓝色闪白 + "Counter!" HUD提示）
- 护甲保护：先扣护甲再扣血量，受击反馈不变

**`scripts/core/game_bus.gd`**: 新增信号 `counter_triggered(enemy: Node)`

**`scripts/ui/player_status.gd`**: 监听 counter_triggered，显示"反击!"提示（类似现有盾牌抵挡提示）

### 距离判定工具方法

**`scripts/enemy/enemy.gd`**: 新增 `_get_distance_bracket(dist: float) -> String`:
- super_far (>5m), far (4-6m), medium (2-4m), close (0.5-2m), melee (<0.5m)
- 超远距离: 8m以上（sight_range 外层）

### AI 检测间隔

基类添加 `_detection_timer`，按 `detection_interval` 间隔执行距离判定和状态决策，不再每帧检测。

---

## Phase 3: 铁鞭距离差异化系统

### WhipData 新增字段

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `melee_threshold` | 0.5m | 贴身阈值 |
| `close_threshold` | 2.0m | 近距离阈值 |
| `medium_threshold` | 4.0m | 中距离阈值 |
| `far_threshold` | 6.0m | 远距离阈值 |
| `melee_damage` | 15.0 | 贴身爆裂伤害 |
| `melee_stun` | 30.0 | 贴身眩晕 |
| `melee_knockback` | 20.0 | 贴身击退 |
| `melee_cooldown` | 0.5s | 贴身冷却 |
| `medium_damage` | 6.0 | 中距离缠绕伤害 |
| `medium_stun` | 50.0 | 高眩晕(主打控制) |
| `medium_snare_duration` | 1.0s | 定身时间 |
| `far_damage` | 4.0 | 远距离鞭挞伤害 |
| `far_stun` | 30.0 | 远距离眩晕 |
| `far_yank_distance` | 3.0m | 强制拉近距离 |
| `super_far_stun` | 15.0 | 超远标记眩晕 |
| `super_far_mark_duration` | 3.0s | 增伤标记持续时间 |
| `super_far_damage_multiplier` | 1.5x | 下次受击增伤倍率 |

### 五档鞭法

| 档位 | 距离 | 效果 | 用途 |
|------|------|------|------|
| 贴身 | <0.5m | 高伤害+强力击退，不拉取 | 紧急推开 |
| 近 | 0.5-2m | 现有行为：伤害+眩晕+可抓取拉取 | 标准连招起手 |
| 中 | 2-4m | 低伤害+高眩晕+短暂定身 | 控制/打断 |
| 远 | 4-6m | 低伤害+中眩晕+强制拉近3m | 追击/缩短距离 |
| 超远 | >6m | 无伤害+低眩晕+增伤标记(下次伤害×1.5) | 先手标记 |

### 敌人类新增方法

- `apply_snare(duration)`: 定身，velocity=0，持续duration秒
- `apply_damage_mark(duration, multiplier)`: 增伤标记，下次受击×multiplier，被消耗或duration后消失

### 视觉反馈

鞭线颜色按档位区分：贴身红、近橙、中金、远青、超远紫。

---

## Phase 4: 新敌人——普通近战兽人 (OrcEnemy)

### EnemyData 资源文件

**`assets/enemies/orc_melee.tres`**:
```
enemy_id = "orc_melee", enemy_name = "兽人战士", enemy_role = "ground_melee"
max_health = 100, max_stun = 100, armor = 100
height = 1.5, weight = 70
move_speed = 4.0, attack_range = 1.0, attack_damage = 25
damage_type = MELEE
attack_windup = 1.0, attack_duration = 0.1, attack_recovery = 0.5, attack_cooldown = 2.0
shield_block_chance = 0.4, detection_interval = 0.5
stun_recovery_rate = 8.0, stun_resistance = 0.2, knockback_resistance = 0.3
score_value = 20, spawn_cost = 3
model_color = Color(0.3, 0.55, 0.25)
```

### CSG 模型

- 身体: CSGCylinder3D (r=0.4, h=1.0) 墨绿色
- 头: CSGSphere3D (r=0.2) 稍亮绿色
- 左手: CSGBox3D (0.15³) + 扁CSGCylinder3D(r=0.3, h=0.05) 作为圆盾
- 右手: CSGBox3D(0.04×0.4×0.04)斧柄 + CSGBox3D(0.15×0.08×0.2)斧刃
- 双腿: CSGBox3D(0.2×0.4×0.2) ×2
- 碰撞体: CapsuleShape3D (r=0.4, h=1.5)

### AI 行为

**检测周期**: 每 0.5s 判定一次

| 距离档 | 行为 |
|--------|------|
| super_far | RUNNING 冲向玩家 |
| far | WALKING 接近；检查周围近战敌人>2 → 尝试侧翼包抄 |
| medium | WALKING 接近 + 40%概率举盾(DEFENDING) |
| close | 直接 ATTACK |
| melee | ATTACK |

**攻击流程（1m触发）**:
1. 快速跑至距玩家0.5m处
2. 进入 ATTACK(phase=0, windup): 1秒前摇，斧子上举（模型旋转+发光）
3. phase=1(attack): 0.1秒判定窗口，右前方0.5m³命中框，对角线劈砍
4. phase=2(recovery): 0.5秒后摇

**Counter 窗口**: 攻击全阶段(phase 0/1/2)受击 → 眩晕=0 → STUNNED

**防御**: phase 0-2 期间若 shield_block_chance 触发 → 减伤50%

### 新增文件

- `scripts/enemy/orc_enemy.gd` — 继承 Enemy
- `scenes/enemies/orc_enemy.tscn` — 打包场景
- `assets/enemies/orc_melee.tres` — 数据资源

---

## Phase 5: 波次刷怪系统

### WaveData 资源

**`scripts/enemy/wave_data.gd`** (新建):
```gdscript
class_name WaveData extends Resource
@export var wave_number: int = 1
@export var enemy_entries: Array[Dictionary]  # [{id, count}]
@export var spawn_interval: float = 2.0
@export var rest_time: float = 8.0
```

### SpawnManager 升级

**`scripts/enemy/spawn_manager.gd`**: 在现有连续刷怪基础上增加波次模式：
- `_wave_mode: bool` — 开关
- `_current_wave: int` — 当前波次
- `_intermission: bool` — 波间休息
- 波间等待场上敌人清零 + rest_time 后开始下一波
- 每波开始 emit `GameBus.wave_started.emit(wave_number)`

### HUD 波次提示

**`scripts/ui/player_status.gd`**: 监听 `wave_started`，居中大字显示"第N波"2秒后渐隐

---

## Phase 6: UI/视觉增强

### 6a. 受击方向指示器

**`scripts/ui/hit_direction_indicator.gd`** (新建): 
- 屏幕边缘弧形箭头，指向受击来源方向
- 红色半透明，1秒渐隐
- 需要 GameBus 新增 `player_hit_from(position: Vector3)` 信号或复用 `player_hit` 并附加位置

### 6b. 小地图

**`scripts/ui/minimap.gd`** (新建):
- 屏幕角落 150×150 圆形小地图
- `_draw()` 绘制：玩家绿点 + 敌人红点 + 玩家朝向箭头
- 每 0.2s 刷新

### 6c. 玩家脚下距离环

**`scripts/player/player_controller.gd`**: `_setup_distance_rings()`:
- 三个 MeshInstance3D 环(ImmediateMesh torus)：
  - 红环 0.5m (melee范围)
  - 黄环 2.0m (close/中距离)
  - 绿环 4.0m+ (medium+/远距离)
- 随玩家移动，始终贴地(Y=0.05)
- 透明度渐变(红0.3→黄0.2→绿0.15)

### 6d. 准星距离反馈

**`scripts/main.gd`**: 增强现有准星系统：
- 敌人进入当前武器射程内 → 准星变蓝
- 命中敌人 → 准星X型红色(已有)
- 无目标 → 准星绿色(已有)
- 添加 0.3s 保持计时器防闪烁

---

## Phase 7: 测试场景 + @export 审查

### 测试场景

在 `test_arena.tscn` 或新建测试关卡中手动放置：
1. 一个兽人战士（100HP + 100护甲）
2. 玩家持步枪
3. 验证流程：步枪射击破甲 → 眩晕累积 → 铁鞭拉取 → 处决/甩出
4. 验证 Counter：兽人攻击时射击 → 眩晕归零 → 进入 STUNNED

### @export 审查清单

- WhipData: 所有距离阈值/伤害/眩晕/冷却
- EnemyData: armor, height, shield_block_chance, detection_interval
- PlayerController: sprint_speed_multiplier, ads_sensitivity_mult
- WaveData: 所有波次参数
- UI: 指示器尺寸/颜色/透明度/淡出时间

---

## 执行顺序与依赖

```
Phase 1 (按键重映射) ← 最先，影响所有后续
    │
Phase 2 (敌人系统增强：Counter + 新属性 + 新状态 + armor)
    │
    ├── Phase 3 (铁鞭距离系统：依赖新敌人方法 snare/mark)
    │
    ├── Phase 4 (兽人敌人：依赖 Phase 2 新状态 + Counter)
    │
    ├── Phase 5 (波次刷怪：独立，但需要 Phase 4 兽人做测试)
    │
    └── Phase 6 (UI增强：独立)
            │
Phase 7 (测试场景 + @export审查)
```

Phase 1-2 先做，Phase 3/4/5/6 可部分并行。

---

## 关键风险

1. **状态枚举膨胀**: 新增 WALKING/RUNNING/DEFENDING 后共12个状态。保留 CHASE 向后兼容，旧敌人子类不受影响。
2. **滚轮双向触发铁鞭**: 滚轮向上/向下都触发 whip_throw，确保 WeaponManager 不再消费滚轮事件，避免冲突。
3. **右键功能冲突**: 右键=瞄准(ADS)，但铁鞭 GRABBING 状态下右键=盾牌模式。通过状态检查分离：非抓取状态→ADS，抓取状态→盾牌。
4. **Counter 平衡性**: 攻击中受击直接眩晕归零是一击逆转。兽人1秒前摇给了充足counter窗口作为补偿。通过 @export 可后续调整。

---

## 验证方法

1. **按键测试**: 启动游戏，逐一验证所有新按键绑定生效
2. **Counter测试**: 在测试关卡放置兽人，等待其攻击，在攻击阶段射击，确认眩晕归零+HUD提示
3. **铁鞭五档测试**: 在不同距离对兽人使用滚轮铁鞭，确认伤害/效果符合距离档位
4. **护甲系统测试**: 步枪射击带100护甲的兽人，确认前100伤害被护甲吸收
5. **波次测试**: 启动波次模式，确认波间休息+波次提示正常
6. **编辑器审查**: 所有新 Resource(.tres) 参数均可在编辑器中调整
