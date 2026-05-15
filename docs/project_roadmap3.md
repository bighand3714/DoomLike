# DoomLike Roadmap 3 — 武器动作细化、敌人交互与表现升级

> 目标：在现有生存竞技场基础上，细化玩家武器手感与敌人战斗交互。右手武器扩展为4槽位（步枪/霰弹枪/手枪/拳头），左手铁鞭扩展抓取→盾牌→甩出→冲刺处决完整连招。新增标准敌人（跳跃攻击型），新增测试关卡与掉落补给系统。全面提升视觉反馈（子弹弹道线、命中X字准星、圈外浓雾）。

---

## 设计边界

- 所有数值参数（伤害/眩晕/击退/射速/换弹时间/冲刺距离等）均通过 `@export` 暴露到 Godot 编辑器 Inspector 面板。
- 所有动作必须有画面反馈（开枪→弹道线、命中→X字准星、挥鞭→鞭影、抓取→举起、冲刺→位移）。
- 武器建模使用 CSGBox3D 拼合，在 3D 编辑器中可直接查看。
- 敌人使用几何体占位模型，颜色/形状区分类型。
- 不引入正式 3D 模型、动画、音频资源。

---

## Phase 1：武器栏位扩展与按键重映射

### 1.1 输入映射更新

- [ ] 修改 `project.godot` 输入动作：
  - 新增 `weapon_3` → 键位 `3`
  - 新增 `weapon_4` → 键位 `4`
  - 保留 `weapon_1` → 键位 `1`（步枪）
  - 保留 `weapon_2` → 键位 `2`（霰弹枪）
  - 保留 `primary_fire` → 鼠标左键
  - 保留 `secondary_fire` → 鼠标右键
  - 保留 `reload` → R 键
  - **新增 `whip_throw` → 鼠标滚轮向下**（甩出/冲刺） ★设计说明：抓取状态下滚轮向下触发铁鞭动作，非抓取状态下仍为 WeaponManager 切武器。IronWhip._input() 在抓取状态消耗滚轮事件避免冲突。

### 1.2 WeaponManager 槽位扩展

- [ ] 将默认武器加载从 2 把扩展到 4 把：步枪、霰弹枪、手枪、拳头
- [ ] `_input()` 中处理 `weapon_1`~`weapon_4` 切槽（而非仅 1/2）
- [ ] 滚轮向上/向下循环切换武器（保留现有逻辑）
- [ ] 更新 `reset_all_weapons()` 覆盖 4 把武器

### 1.3 WeaponData 参数扩展

- [ ] 新增 `knockback_force: float = 0.0` —— 每颗弹丸击退力度
- [ ] 新增 `infinite_ammo: bool = false` —— 无限弹药标记（手枪/拳头）
- [ ] 新增 `is_melee: bool = false` —— 近战武器标记（拳头），近战武器不使用射线而使用近战距离判定
- [ ] 新增 `melee_range: float = 2.0` —— 近战攻击距离

### 1.4 WeaponNode 近战支持

- [ ] `_fire()` 中检测 `weapon_data.is_melee`：
  - 近战：从摄像机前方 `melee_range` 距离内做短射线检测
  - 远程：保持现有射线逻辑
- [ ] 无限弹药武器：`_fire()` 不扣 `_current_mag`，不触发换弹

---

## Phase 2：四把右手武器实现

### 2.1 步枪 (Rifle) — slot 1

- [ ] 新建 `scripts/weapon/rifle.gd`，`class_name Rifle extends WeaponNode`
- [ ] 新建 `assets/weapons/rifle.tres` (WeaponData)：

| 参数 | 值 | 说明 |
|------|-----|------|
| `weapon_name` | "步枪" | |
| `slot_index` | 0 | 按键 1 |
| `damage` | 10.0 | 普通伤害 |
| `max_range` | 80.0m | 主力远程 |
| `damage_type` | HITSCAN | |
| `fire_mode` | AUTO | 按住连发 |
| `fire_rate` | 8.0 发/秒 | 中高速连射 |
| `mag_size` | 25 | |
| `reserve_ammo` | 100 | |
| `reload_time` | 2.0s | |
| `spread_angle` | 2.5° | 轻微散布 |
| `pellet_count` | 1 | |
| `stun_damage` | 3.0 | 低眩晕 |
| `knockback_force` | 2.0 | 低击退 |
| `move_spread_mult` | 1.8 | |

- [ ] `Rifle._setup_model()`：CSGBox3D 拼合长枪造型（枪身+枪托+枪管+弹匣），颜色深灰/黑

### 2.2 霰弹枪 (Shotgun) — slot 2，改为双管猎枪

- [ ] 更新 `assets/weapons/shotgun.tres`：

| 参数 | 原值 | 新值 | 说明 |
|------|------|------|------|
| `weapon_name` | "霰弹枪" | "霰弹枪" | |
| `slot_index` | 1 | 1 | 按键 2 |
| `damage` | 10.0 | 14.0 | 提高单颗弹丸伤害 |
| `max_range` | 25.0m | 20.0m | 中距离 |
| `fire_rate` | 2.0 | 1.5 | |
| `mag_size` | 2 | 2 | 双管 |
| `reserve_ammo` | 20 | 24 | |
| `reload_time` | 2.0s | 2.5s | |
| `spread_angle` | 10.0° | 8.0° | 稍收拢散布 |
| `pellet_count` | 7 | 8 | 8颗弹丸 |
| `stun_damage` | 5.0 | 8.0 | 全中=64眩晕 |
| `knockback_force` | — | 6.0 | 中击退 |

- [ ] `Shotgun._setup_model()` 改为双管猎枪造型（两根并排枪管+木质色枪身）
- [ ] 近距离（<5m）全中 8×14=112 伤害 + 64 眩晕，标准敌人(100HP, 100眩晕)一击眩晕

### 2.3 手枪 (Pistol) — slot 3

- [ ] 更新 `assets/weapons/pistol.tres`：

| 参数 | 原值 | 新值 | 说明 |
|------|------|------|------|
| `weapon_name` | "手枪" | "手枪" | |
| `slot_index` | 0 | 2 | 按键 3 |
| `damage` | 15.0 | 18.0 | 单发有威力感 |
| `max_range` | 50.0m | 60.0m | |
| `fire_rate` | 2.5 | 1.8 | 射速较慢 |
| `fire_mode` | SEMI | SEMI | |
| `infinite_ammo` | — | true | 无限子弹 |
| `stun_damage` | 8.0 | 6.0 | 中低眩晕 |
| `knockback_force` | — | 4.0 | 中低击退 |

- [ ] 手枪模型保持现有外观，可稍加大枪身彰显威力感

### 2.4 拳头 (Fist) — slot 4

- [ ] 新建 `scripts/weapon/fist.gd`，`class_name Fist extends WeaponNode`
- [ ] 新建 `assets/weapons/fist.tres` (WeaponData)：

| 参数 | 值 | 说明 |
|------|-----|------|
| `weapon_name` | "拳头" | |
| `slot_index` | 3 | 按键 4 |
| `damage` | 12.0 | 偏低伤害 |
| `max_range` | 2.0m | 近战距离（=melee_range） |
| `damage_type` | MELEE | |
| `fire_mode` | SEMI | 每按一次打一拳 |
| `fire_rate` | 2.5 | 比手枪(1.8)稍快 |
| `infinite_ammo` | true | |
| `is_melee` | true | 近战判定 |
| `melee_range` | 2.0m | |
| `stun_damage` | 10.0 | 中等眩晕 |
| `knockback_force` | 8.0 | 中击退 |

- [ ] `Fist._setup_model()`：肉色/肤色小方块拳套，或空手（无模型仅碰撞检测）
- [ ] 拳头命中时播放短促前冲动画（覆写 `_apply_recoil()`，武器前移而非后座）

### 2.5 WeaponManager 武器创建逻辑更新

- [ ] `_create_weapon()` 扩展判断分支：
  - `weapon_data.is_melee` → `Fist.new()`
  - `fire_mode == PUMP` → `Shotgun.new()`
  - `fire_mode == AUTO` → `Rifle.new()`
  - 其余 → `Pistol.new()`
- [ ] `_load_default_weapons()` 按顺序加载：步枪→霰弹枪→手枪→拳头

---

## Phase 3：子弹弹道线视效

### 3.1 弹道线系统

- [ ] 在 `WeaponNode` 中新增 `_spawn_tracer(from: Vector3, to: Vector3)` 方法
- [ ] 弹道线：使用 `MeshInstance3D` + 细长 `BoxMesh`（宽高约 0.02m，长度=射线距离）
  - 颜色：半透明白色 `Color(1, 1, 1, 0.4)`
  - 材质：`SHADING_MODE_UNSHADED` + `TRANSPARENCY_ALPHA`
- [ ] 弹道线放在枪口 `_muzzle.global_position` 到命中点（命中）或 `max_range` 处（未命中）
- [ ] 弹道线 0.12 秒后自动消失（`create_timer` → `queue_free`）
- [ ] 霰弹枪每次射击生成 8 条弹道线（每条弹丸独立方向）

### 3.2 枪口位置修正

- [ ] 每把武器的 `_setup_model()` 中设置 `_muzzle.position` 为枪口实际位置：
  - 步枪：前方 0.8m
  - 霰弹枪：前方 0.6m
  - 手枪：前方 0.4m
  - 拳头：前方 0.3m（拳锋位置）

---

## Phase 4：命中反馈 X 字准星

### 4.1 准星命中反馈

- [ ] `WeaponNode.hit_something` 触发时，在 main.gd 中检测目标是否为 Enemy：
  - 命中敌人：准星显示 X 字（两个对角红线，45°/-45°），0.12s 后消失
  - 命中非敌人（墙壁等）：仅现有闪红（保持不变）
- [ ] 实现方式：在 `_setup_crosshair()` 中创建两个对角 ColorRect（默认 `visible = false`），命中敌人时显示再隐藏
- [ ] 拳头（近战）命中敌人时也触发 X 字反馈

### 4.2 准星样式

- [ ] 正常状态：绿色十字（现有 4 个 ColorRect，保持不变）
- [ ] 命中状态：红色 X 字叠加（两个旋转 45°/-45° 的 ColorRect），0.12s 后消失
- [ ] 未命中（打空/打墙）：准星短暂闪红（现有逻辑），不显示 X 字

---

## Phase 5：铁鞭扩展——举起/盾牌/甩出/冲刺

### 5.1 数据参数扩展

- [ ] `WhipData` 新增字段（放在 `assets/weapons/iron_whip.tres` 可调节）：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `dash_distance` | 5.0m | 冲刺距离 |
| `dash_speed` | 25.0 m/s | 冲刺速度 |
| `dash_damage` | 60.0 | 对被撞敌人的伤害 |
| `dash_aoe_damage` | 30.0 | 路径上对其他敌人的伤害 |
| `dash_knockback` | 25.0 | 超高击退 |
| `dash_grabbed_damage` | 150.0 | 对被抓起敌人的大伤害 |
| `throw_damage` | 35.0 | 甩出对被甩敌人的伤害 |
| `throw_speed` | 35.0 m/s | 甩出初速 |

### 5.2 状态机扩展

- [ ] `WhipState` 枚举新增：`SHIELDING`、`THROWING`、`DASHING`
- [ ] `GRABBING` 内部区分三个子模式：
  - **左手举起**（默认）：敌人固定在 `LeftHandHolder` 前方上方，scale 缩小到 0.6~0.7
  - **盾牌模式**（按住右键）：敌人移到摄像机正前方 1.5m，scale 恢复 1.0
  - 释放右键 → 回到左手举起

### 5.3 抓取位置调整

- [ ] 默认抓取位置改为左手区域：`LeftHandHolder.global_position + Vector3(0, 0.5, -0.3)`
- [ ] 敌人被抓时 `scale` 缩小到 0.65，模拟"被举起"
- [ ] 盾牌模式位置：`camera_forward * 1.5 + Vector3(0, 0.3, 0)`，scale 恢复 1.0
- [ ] 现有盾牌抵挡逻辑（`to_enemy.dot(player_forward) > 0.35`）保持有效

### 5.4 滚轮向下——甩出 (Whip Throw)

- [ ] **非盾牌模式**（左手举起状态）触发：
  - 将被抓敌人沿摄像机前方甩出（`forward + Vector3(0, 0.3, 0)` 轻微上抛）
  - 甩出速度 = `throw_speed`
  - 敌人飞出过程中撞到其他敌人 → 造成 `throw_damage` 范围伤害
  - 敌人撞墙/地面 → 额外碰撞伤害
  - 甩出后清除抓取状态、恢复移速
- [ ] 甩出视觉：沿路径生成拖尾小球（复用 `_spawn_whip_effect` 逻辑）

### 5.5 盾牌模式下滚轮向下——冲刺处决 (Shield Dash)

- [ ] **盾牌模式**（按住右键+敌人居中）触发：
  - 玩家沿摄像机前方冲刺 `dash_distance`
  - 冲刺速度 = `dash_speed`，期间禁用正常移动输入
  - 路径上命中的敌人 → `dash_aoe_damage` + `dash_knockback` 击退
  - 被抓取敌人承受 `dash_grabbed_damage`
  - 冲刺到达距离或撞墙后结束 → 清除抓取状态、恢复移速
- [ ] 冲刺视觉：前方生成冲击波平面或粒子

### 5.6 玩家冲刺支持

- [ ] `PlayerController` 新增：
  - `_dash_velocity: Vector3`、`_is_dashing: bool`
  - `start_dash(direction: Vector3, speed: float, distance: float)` 方法
  - `_physics_process()` 冲刺期间覆盖 normal movement
- [ ] 冲刺期间玩家无重力（或保持高度不变），简化手感

---

## Phase 6：标准敌人 (Standard Enemy)

### 6.1 EnemyData

- [ ] 新建 `assets/enemies/standard_enemy.tres`：

| 参数 | 值 | 说明 |
|------|-----|------|
| `enemy_id` | "standard" | |
| `enemy_name` | "标准敌人" | |
| `max_health` | 100 | 中等血量 |
| `attack_damage` | 20 | |
| `damage_type` | MELEE | 跳跃近战 |
| `move_speed` | 3.5 m/s | |
| `attack_range` | 6.0m | 跳跃触发距离 |
| `sight_range` | 30.0m | |
| `attack_cooldown` | 1.5s | 攻击频率中等 |
| `score_value` | 15 | |
| `spawn_cost` | 2 | |
| `weight` | 1.2 | |
| `max_stun` | 100 | |
| `stun_recovery_rate` | 10.0 | |
| `stun_resistance` | 0.1 | |
| `knockback_resistance` | 0.2 | |
| `model_color` | 红 `Color(1, 0.2, 0.1)` | |
| `is_flying` | false | |
| `attack_windup` | 0.4s | 蓄力下蹲 |
| `attack_duration` | 0.3s | 跳跃空中 |
| `attack_recovery` | 0.5s | 落地硬直 |

### 6.2 跳跃攻击行为

- [ ] 新建 `scripts/enemy/standard_enemy.gd`，`class_name StandardEnemy extends Enemy`
- [ ] 覆写 `_state_attack()` 实现跳跃攻击三段式：
  1. **Windup (0.4s)**：敌人下蹲（`scale.y = 0.6`），身体变亮
  2. **Jump (0.3s)**：以抛物线跳向玩家（起跳瞬间锁定玩家位置）
     - 水平速度 = 到玩家的 XZ 距离 / 0.3s
     - 垂直初速使抛物线顶点约 3~4m
     - 跳跃中使用 `move_and_slide()` 移动
     - 检测与玩家距离 < 1.5m → `_damage_player()`
  3. **Recovery (0.5s)**：落地后 scale 恢复，短暂停顿

### 6.3 交互性设计（开发者发挥）

- [ ] **可打断**：Windup 阶段受击 → 打断跳跃，进入 PAIN
- [ ] **可闪避**：起跳瞬间锁定方向，玩家侧移可避开
- [ ] **可反制**：Recovery 阶段受击 → `apply_stun(amount * 1.5)` 额外眩晕
- [ ] **可预读**：下蹲+变亮 = 0.4s 反应窗口
- [ ] **空中击退增强**：跳跃中受击 → `apply_knockback(dir, force * 1.5)`，可改变落点
- [ ] **连击压力**：多个标准敌人轮番跳跃，玩家需要不停移动

### 6.4 场景资源

- [ ] 新建 `scenes/enemies/standard_enemy.tscn`
- [ ] 模型：红色长方体 `CSGBox3D(1.0, 1.8, 0.6)` 身体 + 小方块头部

---

## Phase 7：掉落补给系统

### 7.1 掉落管理器

- [ ] 新建 `scripts/pickup/drop_manager.gd`，`class_name DropManager extends Node`
- [ ] `@export` 掉落概率表：

| 掉落物 | 概率 | 说明 |
|--------|------|------|
| 弹药 (ammo_pickup) | 40% | 补充 10~20 发备弹 |
| 血包 (health_pickup) | 30% | 恢复 15~25 HP |
| 护甲 (armor_pickup) | 20% | 恢复 15~25 护甲 |
| 无掉落 | 10% | |

- [ ] 通过 GameBus 信号获取敌人死亡位置（`Enemy._on_died()` 中 emmit 携带位置）
- [ ] 在敌人死亡位置实例化 Pickup 场景，小幅弹起动画
- [ ] 掉落物 30 秒后自动消失（防止堆积）

### 7.2 弹药拾取智能补充

- [ ] `ammo_pickup.gd` 修改：如果当前武器无限弹药（手枪/拳头），遍历找最近使用过的有限弹药武器补充备弹
- [ ] 所有武器已满时 → 不拾取，弹药包保留

---

## Phase 8：测试关卡

### 8.1 测试关卡场景

- [ ] 新建 `scenes/levels/test_arena.tscn`
- [ ] 根 `Node3D`，挂 `ArenaLevel`
- [ ] `arena_radius = 45.0`，地面灰色
- [ ] `boundary_marker_count = 72`
- [ ] 添加 `PlayerStart` 在圆心
- [ ] **不自动刷怪**（SpawnManager 不启用或不存在）
- [ ] 预放几个标准敌人在 `SpawnRoot` 中，可在编辑器内增删

### 8.2 关卡注册

- [ ] `LevelRegistry` 新增 `const TEST := "test"`
- [ ] `_data` 字典新增条目：`display_name="测试关卡"`, `scene_path="res://scenes/levels/test_arena.tscn"`

---

## Phase 9：圈外浓雾与视觉增强

### 9.1 环境雾

- [ ] `ArenaLevel` 新增 `@export` 雾参数：
  - `fog_enabled: bool = true`
  - `fog_density: float = 0.02`
  - `fog_color: Color`（每关覆写）
  - `fog_start_distance: float`（约 `arena_radius * 0.7`）
- [ ] `_ready()` 或 `level_ready` 时创建/更新 `WorldEnvironment` 节点
- [ ] 虚方法 `_get_fog_color()` 子类覆写：
  - 荒漠：沙黄色
  - 熔岩：暗红/黑
  - 测试：灰色
- [ ] 雾使用 `FogMode.DEPTH` 深度雾，圈内清晰圈外朦胧

### 9.2 边界外视觉

- [ ] 边界柱外生成深色地面延伸（可选，简单 `CSGBox3D` 大环），加雾后形成自然的不可见边界

---

## Phase 10：专业化增强（★ 标记，开发者建议，按需选做）

> 以下为从项目专业性角度建议增加的内容，非用户明确要求，标记 ★ 以示区分。

### 10.1 ★ 武器切换动画

- [ ] 切枪时当前武器下沉→隐藏，新武器上抬→显示（Tween 动画约 0.2s）
- [ ] 切换期间短暂禁用射击（0.2s），防止切枪瞬发

### 10.2 ★ 换弹分段动画

- [ ] 手枪：弹匣弹出→插入新弹匣→上膛（Tween 控制武器 position/rotation）
- [ ] 霰弹枪：打开枪膛→逐发塞入 2 颗子弹→合上枪膛
- [ ] 步枪：弹匣弹出→插入→拉枪机
- [ ] 拳头：无需换弹

### 10.3 ★ 伤害数字弹出

- [ ] 命中敌人时在命中位置弹出伤害数字（`Label3D`，漂浮上升+渐隐，约 0.8s 消失）
- [ ] 颜色区分：普通伤害白色，眩晕值蓝色，处决金色

### 10.4 ★ 屏幕震动

- [ ] 玩家受伤 → 轻微屏幕震动（Camera3D 偏移振荡，约 0.15s）
- [ ] 霰弹枪开枪 → 轻微震动
- [ ] 铁鞭冲刺命中 → 较大震动

### 10.5 ★ 音效占位接口

- [ ] GameBus 新增 `play_sfx(sfx_name: String, position: Vector3)` 信号
- [ ] 当前用 `print()` 代替实际音效播放
- [ ] 后续接入音频资源时只需修改监听端

---

## 文件变更清单

### 新增脚本
- [ ] `scripts/weapon/rifle.gd`
- [ ] `scripts/weapon/fist.gd`
- [ ] `scripts/enemy/standard_enemy.gd`
- [ ] `scripts/pickup/drop_manager.gd`

### 新增资源
- [ ] `assets/weapons/rifle.tres`
- [ ] `assets/weapons/fist.tres`
- [ ] `assets/enemies/standard_enemy.tres`

### 新增场景
- [ ] `scenes/enemies/standard_enemy.tscn`
- [ ] `scenes/levels/test_arena.tscn`

### 重点修改文件
- [ ] `project.godot` — 输入映射（weapon_3/weapon_4/whip_throw）
- [ ] `scripts/weapon/weapon_data.gd` — knockback_force/infinite_ammo/is_melee/melee_range
- [ ] `scripts/weapon/weapon_node.gd` — 弹道线视效、近战判定、无限弹药
- [ ] `scripts/weapon/weapon_manager.gd` — 4 槽位扩展、武器创建逻辑
- [ ] `scripts/weapon/whip_data.gd` — dash_*/throw_* 参数
- [ ] `scripts/weapon/iron_whip.gd` — SHIELDING/THROWING/DASHING 状态
- [ ] `scripts/weapon/shotgun.gd` — 双管猎枪模型
- [ ] `scripts/player/player_controller.gd` — 冲刺位移支持
- [ ] `scripts/ui/player_status.gd` — 抓取状态更新
- [ ] `scripts/main.gd` — X字准星扩展、drop_manager 集成
- [ ] `scripts/level/level_registry.gd` — +test 关卡
- [ ] `scripts/level/arena_level.gd` — 雾参数导出
- [ ] `scripts/enemy/enemy_manager.gd` — 掉落管理器连接
- [ ] `scripts/core/game_bus.gd` — +enemy_death_position 信号
- [ ] `scripts/pickup/ammo_pickup.gd` — 智能补充备弹
- [ ] `assets/weapons/pistol.tres` — 参数调整（无限弹/射速/伤害）
- [ ] `assets/weapons/shotgun.tres` — 参数调整（双管/8弹丸/伤害）

---

## 按键映射总结

| 按键 | 功能 |
|------|------|
| `1` | 步枪（全自动、主力远程） |
| `2` | 霰弹枪（双管猎枪、中距离） |
| `3` | 手枪（无限子弹、保底远程） |
| `4` | 拳头（无限、保底近战） |
| 鼠标左键 | 开枪/挥拳 |
| 鼠标右键 | 挥鞭 / 抓取中按住=盾牌模式 |
| `R` | 换弹 / 抓取中=处决 |
| 滚轮向上 | 下一把武器 |
| 滚轮向下 | 上一把武器 / 抓取中=甩出 / 盾牌模式=冲刺处决 |
| `WASD` | 移动 |
| `Space` | 跳跃 |
| `Esc` | 暂停 |

---

## 推荐实现顺序

1. **Phase 1** — 武器栏位基础（input + WeaponData + WeaponManager 架构先就位）
2. **Phase 2** — 四把武器实现（步枪/霰弹枪改/手枪改/拳头）
3. **Phase 3** — 子弹弹道线视效
4. **Phase 4** — X字准星命中反馈
5. **Phase 5** — 铁鞭扩展（举起/盾牌/甩出/冲刺）
6. **Phase 6** — 标准敌人（跳跃攻击+交互性）
7. **Phase 7** — 掉落补给系统
8. **Phase 8** — 测试关卡
9. **Phase 9** — 圈外浓雾
10. **Phase 10** — ★ 专业化增强（按需选做）
