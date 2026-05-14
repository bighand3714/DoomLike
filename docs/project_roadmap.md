# DoomLike 项目路线图 — 原子化任务拆解

> **当前进度：第六阶段（UI/HUD+菜单+拾取）已完成** — 核心移动 + 武器/射击 + 敌人AI + 菜单/拾取/护甲系统已可运行。关卡在编辑器中手动搭建（CSG），Phase 5（导出.tres管线）待实现。总进度 92/134 任务（69%）。
>
> **⚠️ Phase 5、Phase 6 暂缓** — 新方向以 `project_roadmap2.md` 为准，当前优先执行 Roadmap 2 的 Phase 0 前置整理。

---

## 第一阶段：原型搭建（Phase 1）

### 1.1 玩家移动系统 ✅
- [x] WASD 移动 + 加速度/摩擦力平滑
- [x] 鼠标视角旋转（Y轴身体 + X轴摄像机分离）
- [x] 重力 + 地面检测
- [x] 空格跳跃（仅限地面）
- [x] Esc 切换鼠标捕获/释放
- [x] Y轴反转选项 (`invert_y`)
- [x] 垂直视角限制 (`vertical_limit`)

### 1.2 基础场景搭建 ✅
- [x] 主场景树结构（Main → Player / Level / UI）
- [x] 测试房间（CSG 硬编码：地板、天花板、4面墙、中央柱子）
- [x] 灯光系统（方向光 + 补光）
- [x] 准星（绿色 4×4 像素 ColorRect，自动居中）
- [x] FPS 计数器（每 0.5 秒刷新）

### 1.3 关卡数据结构定义 ✅
- [x] `LevelData` Resource 类（扇区/墙壁/实体）
- [x] `Sector` 内部类（地板/天花板高度、纹理、亮度、墙壁列表）
- [x] `WallDef` 内部类（起止点、三段纹理、Portal 引用）
- [x] `ThingDef` 内部类（类型枚举、位置、角度、子类型）
- [x] `LevelBuilder` 类骨架（`build()` / `_build_sector()` / `_place_thing()` / `serialize()`）

### 1.4 编辑器模式骨架 ✅
- [x] `GameModeManager` 类（PLAY/EDIT 枚举、切换、信号）

---

## 第二阶段：武器与射击（Phase 2）

> **目标**：实现射击核心循环——按下鼠标左键 → 射线检测 → 命中反馈。产出最小可玩原型（能开枪打死东西）。
>
> **不在此阶段**：敌人 AI（Phase 3）、HUD 显示（Phase 6）、真实音效/贴图（Phase 7）。

---

### 2.1 武器数据定义（`scripts/weapon/weapon_data.gd`）

新建文件，定义纯数据结构——与 3D 节点分离，方便后续编辑器配置和存档。

- [x] **2.1.1** 创建 `WeaponData` Resource 类
  - 字段：`weapon_name: String`、`damage: float`、`range: float`、`fire_rate: float`（发/秒）、`mag_size: int`、`reserve_ammo: int`、`reload_time: float`、`spread_angle: float`（散布角度，0 = 完美精准）、`pellet_count: int`（弹丸数，1 = 单发）、`fire_mode: enum`（`SEMI` 半自动 / `AUTO` 全自动 / `PUMP` 泵动式）
  - 保存为 `.tres` 文件的蓝图，可在编辑器中直接调参
  - 文件路径：`scripts/weapon/weapon_data.gd`

- [x] **2.1.2** 创建 `DamageType` 枚举
  - 值：`HITSCAN`（瞬时命中）、`PROJECTILE`（飞行投射物）、`EXPLOSION`（范围爆炸）、`MELEE`（近战）
  - 放在独立文件或 `weapon_data.gd` 顶部，全局可引用

---

### 2.2 武器节点基类（`scripts/weapon/weapon_node.gd`）

新建文件，定义挂在场景中的武器 3D 节点。每把具体武器（手枪、霰弹枪……）是它的子类。

- [x] **2.2.1** 创建 `WeaponNode` 基类（`extends Node3D`）
  - `@export var weapon_data: WeaponData` — 拖入 `.tres` 配置即生效
  - 运行时状态变量：`_current_mag: int`、`_current_reserve: int`、`_can_fire: bool`、`_is_reloading: bool`
  - `_fire_timer: Timer` — 控制射速间隔
  - `_reload_timer: Timer` — 控制换弹时间

- [x] **2.2.2** 武器生命周期方法（在子类中覆写）
  - `_on_equip()` — 武器被切换到手中时调用（播放举起动画）
  - `_on_unequip()` — 武器被切走时调用（播放收起动画）
  - `_on_primary_fire()` — 按下主攻击键（鼠标左键）
  - `_on_secondary_fire()` — 按下副攻击键（鼠标右键，预留）
  - `_on_reload()` — 按下换弹键

- [x] **2.2.3** 武器节点场景模板
  - 子节点：`MeshInstance3D`（武器模型占位）、`MuzzleFlash`（枪口位置 Marker3D）、`AnimationPlayer`
  - 枪口位置放在 WeaponHolder 前方，作为射线/粒子发射起点

---

### 2.3 射击核心逻辑（写在 `WeaponNode` 基类中）

所有枪共享的射击流程，避免每把枪重复实现。

- [x] **2.3.1** 主射击函数 `_fire()`
  - 调用顺序：检查弹药 → 检查射速 → 检查换弹中 → 扣弹药 → 每颗弹丸调 `_fire_single_pellet()` → 启动射速计时器
  - 半自动模式：`Input.is_action_just_pressed("primary_fire")`
  - 全自动模式：`Input.is_action_pressed("primary_fire")`
  - 泵动式：射击后短暂锁定，需等待泵动动画完成

- [x] **2.3.2** 单发弹丸函数 `_fire_single_pellet(spread_offset: Vector2)`
  - 从 `%Camera3D` 中心发射 `RayCast3D`
  - 射线方向 = 摄像机前方 + `spread_offset` 偏移（散布）
  - 碰撞检测：命中 `Damageable` → 调用 `take_damage()`；命中墙壁 → 生成弹孔占位
  - 返回命中信息（碰撞点、碰撞对象），供子类扩展

- [x] **2.3.3** 散布计算 `_get_spread()`
  - 根据 `weapon_data.spread_angle` 在圆锥内随机取方向偏移
  - 支持移动惩罚（移动时散布增大 1.5×）
  - 霰弹枪多弹丸：每个弹丸在散布角内均匀随机分布

- [x] **2.3.4** 弹药逻辑
  - 射击时 `_current_mag -= 1`
  - 弹匣空时自动触发换弹（`_start_reload()`）
  - 手动换弹：R 键 → `_start_reload()`
  - `_finish_reload()`：从备弹补充弹匣（`reserve -= (mag_size - current_mag)`），备弹不足则部分装填
  - 换弹中不能射击（`_is_reloading` 标记阻止 `_fire()`）
  - 切换武器中断换弹

---

### 2.4 武器管理器（`scripts/weapon/weapon_manager.gd`）

挂在 Player 节点上，管理武器栏位和切换逻辑。

- [x] **2.4.1** 创建 `WeaponManager`（`extends Node3D`，挂到 Player）
  - `@export var weapon_slots: Array[WeaponData]` — 武器栏位（最多 N 个）
  - `_current_slot_index: int` — 当前使用的武器索引
  - `_weapon_nodes: Array[WeaponNode]` — 已实例化的武器节点

- [x] **2.4.2** 武器切换
  - 数字键 1-N：直接切到对应栏位
  - 滚轮上下：`_next_weapon()` / `_prev_weapon()`
  - 切换流程：`_unequip_current()` → 隐藏旧武器 → 显示新武器 → `_equip_new()`
  - 空栏位自动跳过

- [x] **2.4.3** 输入转发
  - `_input(event)` 中检测 `primary_fire` / `reload` 动作，转发给当前武器的对应方法
  - 确保换弹中 / 切换中不转发射击输入

- [x] **2.4.4** 添加输入映射
  - 在 Godot 项目设置中添加 `primary_fire`（鼠标左键）、`secondary_fire`（鼠标右键）、`reload`（R）、`weapon_1`~`weapon_N`（数字键）、`weapon_next`/`weapon_prev`（滚轮）

---

### 2.5 首把武器：手枪（`scripts/weapon/pistol.gd`）

验证整条武器管线能跑通的"最简实现"。

- [x] **2.5.1** 创建 `Pistol` 类（`extends WeaponNode`）
  - 创建 `pistol.tres`（WeaponData）：伤害 15、射程 50m、射速 2.5 发/秒、弹匣 8、备弹 50、散布 2°、弹丸数 1、半自动
  - `_on_primary_fire()` 覆写：调用基类 `_fire()`、播放射击动画、播放音效占位
  - 动画：射击时武器向后微量位移（`_apply_recoil()`，在 `_physics_process` 中平滑回弹）

- [x] **2.5.2** 手枪 3D 占位模型
  - 用 `CSGBox3D` 组合搭一个简陋的手枪外形（枪管 + 握把，3-4 个盒子）
  - 或直接用 `BoxMesh` 长方体占位
  - 挂在 WeaponHolder 下，通过 WeaponManager 控制显隐

- [x] **2.5.3** 手枪射击音效占位
  - 用 `AudioStreamPlayer3D` 播放空音频或 beep 音
  - 挂在 WeaponNode 模板中，子类可覆盖音频资源

---

### 2.6 第二把武器：霰弹枪（`scripts/weapon/shotgun.gd`）

验证多弹丸散布、泵动式射速限制。

- [x] **2.6.1** 创建 `Shotgun` 类（`extends WeaponNode`）
  - 创建 `shotgun.tres`（WeaponData）：伤害 10×7、射程 30m、弹匣 2、备弹 20、散布 8°、弹丸数 7、泵动式
  - `_on_primary_fire()` 覆写：调用基类 `_fire()`（自动处理 7 颗弹丸）、播放泵动动画
  - 泵动逻辑：射击后锁定 0.6 秒（泵动动画时长），期间不能射击但可以切换武器

- [x] **2.6.2** 霰弹枪 3D 占位模型
  - CSG 组合：长枪管 + 弹仓 + 握把/枪托
  - 外形比手枪明显更大

---

### 2.7 伤害系统（`scripts/damage/damageable.gd`）

为 Phase 3 敌人系统做好接口准备。本阶段先用一个简单的"靶子"验证。

- [x] **2.7.1** 创建 `Damageable` 类（`extends Node`）
  - `signal died()` — 生命值归零时发射
  - `signal damaged(amount: float, type: DamageType)` — 受到伤害时发射
  - `var health: float`、`var max_health: float`
  - `func take_damage(amount: float, type: DamageType) -> void`：扣血、发射信号、检查死亡
  - `func is_dead() -> bool`

- [x] **2.7.2** 创建测试靶子 `ShootingTarget`（`scripts/damage/shooting_target.gd`）
  - `extends CSGBox3D` 或 `StaticBody3D`，附带 `Damageable` 子节点
  - 放在测试房间中（替换中央柱子）
  - 受伤时材质短暂闪红（`_on_damaged` 中用 Tween 改变 albedo_color）
  - 死亡时变灰 + 禁用碰撞

- [x] **2.7.3** 击中标记反馈
  - 在 `main.gd` 或 WeaponManager 中监听当前武器的命中事件
  - 击中 Damageable 时准星短暂变红（ColorRect color → 红色，50ms 后恢复绿色）
  - 为击中标记添加独立信号或回调

---

### 2.8 集成与验证

- [x] **2.8.1** 将 WeaponManager 挂到 Player 场景树
  - Player 下已有 WeaponHolder → WeaponManager 挂在 WeaponHolder 位置
  - 初始武器栏位：手枪（slot 1）+ 霰弹枪（slot 2）
  - 默认装备手枪

- [x] **2.8.2** 在测试房间放置 2 个靶子
  - 替换中央柱子为一个靶子
  - 在一面墙前再放一个靶子（测试不同距离）

- [x] **2.8.3** 端到端测试清单
  - 按左键射击 → 射线命中靶子 → 靶子闪红 → 靶子血量归零变灰
  - 按 R 换弹 → 弹匣回满、备弹减少 → 换弹中不能开枪
  - 数字键 1/2 切换手枪/霰弹枪 → 模型切换、弹药独立
  - 空弹匣自动触发换弹
  - 距离 > `range` 时射线无碰撞（超出射程不造成伤害）
  - 射击墙壁 → 不报错、弹孔占位出现在碰撞点（可选）

---

### Phase 2 新增文件清单

```
scripts/
  weapon/
    weapon_data.gd        # WeaponData Resource + DamageType 枚举
    weapon_node.gd         # WeaponNode 基类（射击/弹药/换弹逻辑）
    weapon_manager.gd      # 武器栏位管理 + 切换
    pistol.gd              # 手枪（半自动）
    shotgun.gd             # 霰弹枪（泵动式 + 多弹丸）
  damage/
    damageable.gd          # 可受伤接口
    shooting_target.gd     # 测试靶子
```

---

## 第三阶段：敌人系统（Phase 3）

> **目标**：实现敌人 AI 核心循环——敌人能看见玩家 → 追过来 → 攻击 → 被打死。产出"有敌人可打"的完整战斗体验。
>
> **不在此阶段**：投掷物抛物线与弹道特效（Phase 3.4 做火球基础，美术打磨在 Phase 7/8）、敌人巡逻路径点编辑器（Phase 5）、BOSS 战斗（Phase 8 多关卡）。

---

### 3.1 敌人基类（`scripts/enemy/enemy.gd`）

新建文件，定义所有敌人共享的数据、状态机和基础行为。每个具体敌人（Imp、Demon Soldier）是它的子类。

- [ ] **3.1.1** 创建 `Enemy` 基类（`extends CharacterBody3D`）
  - 为什么用 CharacterBody3D：敌人需要在物理世界中移动，需要碰撞检测和 `move_and_slide()`
  - 本阶段不使用 NavigationAgent3D（Godot 导航系统），改为简化的"朝玩家直线移动 + 射线检测撞墙就停"，保持 DOOM 风格的直线追杀感
  - 预留 `NavigationAgent3D` 集成接口，后续可切换为真导航

- [ ] **3.1.2** 敌人状态枚举 `EnemyState`
  - `IDLE` — 待机（玩家未发现时，原地站立或缓慢踱步）
  - `PATROL` — 巡逻（沿预设路径点移动，Phase 3 暂时原地转圈代替）
  - `CHASE` — 追击（发现玩家，朝玩家方向移动）
  - `ATTACK` — 攻击（在攻击距离内，执行攻击动作）
  - `PAIN` — 受击硬直（受伤瞬间短暂停顿，0.3 秒后恢复追击）
  - `DEATH` — 死亡（播放死亡动画/变灰，禁用碰撞，等待尸体消失）

- [ ] **3.1.3** 状态机框架
  - `_state: EnemyState` — 当前状态
  - `_process_state(delta: float)` — 每帧根据当前状态分发到对应的处理函数
  - 各状态处理函数签名：`_state_idle(delta)`、`_state_chase(delta)`、`_state_attack(delta)`、`_state_pain(delta)`、`_state_death(delta)`
  - `_transition_to(new_state: EnemyState)` — 状态切换函数，负责"离开旧状态"和"进入新状态"的清理/初始化
  - 状态迁移图：
    ```
    IDLE/PATROL → CHASE（看见玩家）
    CHASE → ATTACK（进入攻击距离）
    ATTACK → CHASE（玩家跑出攻击距离）
    任意状态 → PAIN（受到伤害，除 DEATH 外）
    PAIN → CHASE（硬直结束）
    任意状态 → DEATH（生命值归零）
    ```

- [ ] **3.1.4** 敌人属性（`@export` 可配置）
  - `move_speed: float = 4.0` — 追击移动速度（比玩家慢，玩家可以风筝）
  - `attack_range: float = 15.0` — 攻击触发距离（米）
  - `sight_range: float = 30.0` — 发现玩家距离（米），超过此距离敌人不会反应
  - `attack_cooldown: float = 1.0` — 攻击间隔（秒），防止连续无脑输出
  - `pain_duration: float = 0.3` — 受击硬直时间
  - `death_duration: float = 2.0` — 死亡动画/尸体停留时间
  - `knockback_force: float = 3.0` — 受击击退力度

- [ ] **3.1.5** 生命值集成
  - 自动创建 `Damageable` 子节点（在 `_ready` 中检查，没有则 `Damageable.new()` 并 `add_child`）
  - 连接 `Damageable.damaged` → `_on_damaged(amount, type)`，在其中处理 PAIN 状态切换和击退
  - 连接 `Damageable.died` → `_on_died()`，在其中处理 DEATH 状态切换、碰撞禁用、定时 `queue_free()`
  - `max_health` 和初始 health 从 `@export var enemy_data: EnemyData` 配置文件中读取（类似 WeaponData 的数据驱动思路）

- [ ] **3.1.6** 玩家检测（"视觉"系统）
  - 在 `_physics_process` 中持续检查：玩家是否在 `sight_range` 范围内？
  - 粗略检查：`global_position.distance_to(player.global_position) < sight_range`
  - 精确检查：从敌人位置向玩家发射一条射线（`PhysicsRayQueryParameters3D`），确认中间没有墙壁遮挡
  - 如果粗略距离通过但射线被墙壁挡住 → 视为"看不见玩家"
  - 一旦"看见"就进入 CHASE 状态，不需要每帧验证（简化设计：敌人一旦发现就"锁定目标"，不会跟丢）

- [ ] **3.1.7** 追击移动逻辑（`_state_chase(delta)`）
  - 计算敌人到玩家的方向向量（只用 XZ 平面，忽略 Y 轴高度差——DOOM 的 2.5D 传统）
  - 用 `velocity = direction * move_speed` 向玩家移动，调用 `move_and_slide()`
  - 到达 `attack_range` 内时切换到 ATTACK 状态
  - 玩家跳出 `sight_range * 1.5` 时切换回 IDLE/PATROL（给一点余量，不频繁切换）

- [ ] **3.1.8** 受击反应（`_state_pain(delta)`）
  - 进入 PAIN 时：`_pain_timer = pain_duration`
  - 每帧减计时器，归零后切换到 CHASE
  - 视觉：子类覆写 `_flash_pain()`（材质变亮/变白），基类提供默认实现（用 `material_override.albedo_color` Tween 闪白）
  - 击退：`velocity = (self.global_position - damage_source.global_position).normalized() * knockback_force`（沿"伤害来源→敌人"方向推开）

- [ ] **3.1.9** 死亡处理（`_state_death(delta)`）
  - 进入 DEATH 时：禁用 CollisionShape3D（`collision.disabled = true`），防止挡路/继续被打
  - 视觉：子类覆写 `_on_death_visual()`，基类默认把 `material_override.albedo_color` 调暗/变灰
  - 计时 `death_duration` 秒后 `queue_free()`
  - 发射信号 `enemy_died(self)`（供 main.gd 统计击杀数、触发开门等）

---

### 3.2 敌人配置文件（`scripts/enemy/enemy_data.gd`）

类似 `WeaponData` 的数据蓝图，把敌人参数从代码中抽离为 Resource 文件。

- [ ] **3.2.1** 创建 `EnemyData` Resource 类
  - `@export var enemy_name: String = "未命名敌人"`
  - `@export var max_health: float = 100.0`
  - `@export var move_speed: float = 4.0`
  - `@export var attack_damage: float = 10.0`
  - `@export var attack_range: float = 15.0`
  - `@export var sight_range: float = 30.0`
  - `@export var attack_cooldown: float = 1.0`
  - `@export var damage_type: WeaponData.DamageType` — 敌人造成的伤害类型（Imp 火球=PROJECTILE，士兵枪击=HITSCAN，啃咬=MELEE）
  - `@export var display_name: String` — HUD 杀死提示用

- [ ] **3.2.2** 创建 `imp.tres` 和 `demon_soldier.tres`
  - Imp：生命 80、速度 5、攻击 15（火球）、攻击距离 12m、视野 30m
  - Demon Soldier：生命 120、速度 3、攻击 8（hitscan）、攻击距离 20m、视野 35m

---

### 3.3 投射物系统（`scripts/enemy/projectile.gd`）

火球、火箭弹、等离子弹等飞行物体的基类。敌人和玩家都可以生成投射物。

- [ ] **3.3.1** 创建 `Projectile` 基类（`extends Area3D`）
  - 为什么用 Area3D：投射物需要"当我和某物重叠时"的检测，不需要物理推搡。Area3D 的 `body_entered` / `area_entered` 信号为此设计
  - `@export var speed: float = 15.0` — 飞行速度（m/s）
  - `@export var damage: float = 15.0` — 命中伤害
  - `@export var lifetime: float = 5.0` — 最大存活时间（秒，超时自动销毁，防止飞出地图占用内存）
  - `@export var damage_type: WeaponData.DamageType = PROJECTILE`

- [ ] **3.3.2** 投射物飞行逻辑
  - `_physics_process(delta)` 中 `global_position += direction * speed * delta`（直接位移，不模拟重力）
  - `lifetime -= delta`，归零时 `queue_free()`

- [ ] **3.3.3** 投射物碰撞处理
  - 连接 `body_entered(body: Node3D)` 信号
  - 命中 Player → 调用 `body.take_damage()` 或向玩家下面的 Damageable 查找
  - 命中墙壁/地面 → 生成命中特效占位（火花粒子/弹孔）、`queue_free()`
  - 命中其他投射物 → 互相抵消？（暂定：不处理，只和墙/玩家碰撞）
  - 碰到任何 `StaticBody3D` / `CharacterBody3D` 即销毁（不穿透）

- [ ] **3.3.4** 投射物视觉占位
  - `_ready()` 中创建 `CSGSphere3D`（半径 0.15m，亮色材质）作为火球占位模型
  - 或创建 `MeshInstance3D` 用 `SphereMesh`
  - 子类覆写 `_setup_visual()` 自定义外观
  - 可选：`PointLight3D` 子节点让火球发光（动态光源，本阶段先跳过）

---

### 3.4 敌人 AI：小恶魔 Imp（`scripts/enemy/imp.gd`）

验证整条敌人管线能跑通的"最简实现"——能发现玩家、追过来、扔火球、被打死。

- [ ] **3.4.1** 创建 `Imp` 类（`extends Enemy`）
  - 在 `_ready()` 中加载 `imp.tres`（EnemyData）
  - 覆写 `_setup_model()`：用 CSGBox3D 搭一个简陋的人形占位（身体 + 头 + 四肢，简单盒子人）

- [ ] **3.4.2** Imp 攻击行为（`_state_attack(delta)`）
  - 攻击方式：火球投射物（远程）+ 爪击（近战，贴脸时）
  - 远程攻击（玩家距离 > 2m）：生成 `Projectile` 实例，方向朝向玩家位置（瞄准玩家当前位置发射）
  - 近战攻击（玩家距离 ≤ 2m）：直接对玩家调用 `take_damage()`（近战伤害 10 点，HITSCAN 但范围判定）
  - 攻击后设 `_attack_cooldown` 计时器，期间留在 ATTACK 状态但不发射，计时结束才能再攻击
  - 攻击时短暂停顿（`velocity = Vector3.ZERO`，持续 0.2 秒）

- [ ] **3.4.3** Imp 投射物生成
  - 在敌人头顶位置（`global_position + Vector3(0, 1.5, 0)`）生成火球
  - 火球方向 = `(player.global_position - spawn_pos).normalized()`
  - 火球速度 10m/s（比手枪子弹慢很多，玩家能躲）
  - 火球伤害 15 点

- [ ] **3.4.4** Imp 受伤/死亡覆盖
  - 覆写 `_flash_pain()`：Imp 受击时材质变亮白色 0.2 秒
  - 覆写 `_on_death_visual()`：Imp 死亡时缩小 30% + 变灰 + 缓缓下沉（Tween `scale` 和 `position.y`）
  - 死亡音效占位（`AudioStreamPlayer3D.play()` 空音频）

---

### 3.5 第二只敌人：恶魔士兵 Demon Soldier（`scripts/enemy/demon_soldier.gd`）

验证"不同敌人类型可共享基类但行为不同"的架构。

- [ ] **3.5.1** 创建 `DemonSoldier` 类（`extends Enemy`）
  - 加载 `demon_soldier.tres`
  - 覆写 `_setup_model()`：比 Imp 更大、更方正的盒子人（装甲外观）

- [ ] **3.5.2** 士兵攻击行为
  - 远程 hitscan 攻击（瞬时命中，类似玩家手枪）
  - 从敌人位置向玩家方向发射射线检测（`PhysicsRayQueryParameters3D`）
  - 命中玩家 → 造成 `enemy_data.attack_damage` 伤害
  - 攻击间隔 1.5 秒（比 Imp 慢，因为有"举枪→射击→收枪"的节奏）
  - 攻击时有 0.1 秒的"举枪前摇"（玩家能看到敌人准备动作的窗口）

- [ ] **3.5.3** 士兵移动模式区别
  - 追击时偶尔"停顿射击"：每追 2 秒，停 0.5 秒射击一次，然后继续追
  - 没有近战攻击（纯远程）
  - 比 Imp 稍慢（`move_speed = 3.0`）

---

### 3.6 敌人放置与生成（集成到 `main.gd` 和 Level）

在测试关卡中手动放置敌人，验证完整战斗循环。

- [ ] **3.6.1** `main.gd` 中添加敌人实例化功能
  - `_spawn_enemy(enemy_scene: PackedScene, position: Vector3) -> Enemy`
  - 或将敌人直接放在 main.tscn 中（本阶段手动拖入场景）

- [ ] **3.6.2** 在测试房间中放置敌人
  - 2 只 Imp：分散在房间角落
  - 1 只 Demon Soldier：放在房间中央或柱子附近
  - 敌人初始状态为 IDLE，朝向随机

- [ ] **3.6.3** 敌人管理器（`scripts/enemy/enemy_manager.gd`）
  - `active_enemies: Array[Enemy]` — 当前存活敌人列表
  - 监听 `enemy_died` 信号，从列表中移除
  - `all_clear()` — 检查是否所有敌人死亡（触发开门/通关）
  - 挂载到 Level 节点或 main.gd 中

---

### 3.7 战斗 HUD 增强

在现有的 PlayerStatus HUD 基础上，添加战斗相关信息。

- [ ] **3.7.1** 命中标记（Hit Marker）
  - 击中敌人时准星短暂变红（30ms），然后恢复绿色
  - 在 WeaponNode 的 `hit_something` 信号中检测命中目标是否为 Enemy
  - 在 `main.gd` 或 PlayerStatus 中处理此逻辑

- [ ] **3.7.2** 击杀计数
  - 在 PlayerStatus HUD 中添加"击杀数"标签（右上角，武器信息上方）
  - 监听 Enemy 死亡信号，递增计数

- [ ] **3.7.3** 受伤效果
  - 玩家被敌人攻击时，屏幕四边短暂闪红（在 UI CanvasLayer 上放 4 个 ColorRect 边框）
  - 持续时间 0.3 秒，从红色渐变到透明

---

### 3.8 集成与验证

- [ ] **3.8.1** 将 Imp 敌人放入测试房间
  - 至少 2 只 Imp，初始位置远离玩家（房间对角）

- [ ] **3.8.2** 将 Demon Soldier 放入测试房间
  - 1 只士兵，放在中央柱子附近

- [ ] **3.8.3** 端到端测试清单
  - 进入房间 → 敌人发现玩家 → 开始追击（CHASE 状态）
  - 敌人进入攻击距离 → 攻击（Imp 扔火球，士兵瞬发射击）
  - 火球命中玩家 → 屏幕闪红、玩家扣血
  - 火球命中墙壁 → 火球消失、无报错
  - 玩家射击敌人 → 敌人闪白、受击硬直
  - 敌人血量归零 → 死亡动画 → 尸体消失
  - 所有敌人死亡 → 控制台打印 "All Clear"
  - 切换武器射击敌人 → 霰弹枪多弹丸均有伤害判定
  - 从远距离狙击 → 超出 sight_range 的敌人不反应
  - 用柱子当掩体 → 射线被墙挡住，敌人丢失视野

---

### Phase 3 新增文件清单

```
scripts/
  enemy/
    enemy.gd             # Enemy 基类（状态机、追击、受击、死亡）
    enemy_data.gd         # EnemyData Resource 配置文件
    imp.gd                # 小恶魔 Imp（火球投射物 + 近战爪击）
    demon_soldier.gd      # 恶魔士兵（hitscan 远程 + 停顿射击）
    projectile.gd         # 投射物基类（飞行、碰撞、伤害）
    enemy_manager.gd      # 敌人管理器（追踪存活、all clear 检测）
assets/
  enemies/
    imp.tres              # Imp 配置数据
    demon_soldier.tres    # Demon Soldier 配置数据
```

---

## 第四阶段：关卡管线连接（Phase 4）

> **目标**：从代码生成关卡转向 Godot 编辑器直接搭关卡。玩家/敌人改为 .tscn 场景文件，关卡几何体在编辑器中用 CSG 节点手动搭建，`main.gd` 启动时自动开启碰撞 + 定位出生点。
>
> **实际实现方式**：删除 `LevelData`/`LevelBuilder`/`GameModeManager` 等数据驱动代码，改为更务实的"编辑器所见即所得"方案。
>
> **不在此阶段**：关卡导出/保存工具（Phase 5）、纹理贴图（Phase 7）。

---

### 4.1 场景文件化 ✅

将原来纯代码创建的 Player 和敌人改为 `.tscn` 场景文件，可在编辑器中独立编辑和预览。

- [x] **4.1.1** Player 场景化
  - 创建 `scenes/player/player.tscn`：CharacterBody3D + Camera3D + CollisionShape3D + WeaponHolder/WeaponManager
  - `main.tscn` 中通过 `instance=ExtResource("player.tscn")` 引用
  - Player 节点的 `Damageable` 子节点由 `player_controller.gd._ready()` 自动创建（100HP, 100护甲）

- [x] **4.1.2** 敌人场景化
  - 创建 `scenes/enemies/imp.tscn` 和 `scenes/enemies/demon_soldier.tscn`
  - 每个 .tscn 引用对应脚本（`imp.gd` / `demon_soldier.gd`）+ 配置数据（`.tres`）
  - 编辑器中可直接拖入场景放置敌人

---

### 4.2 编辑器关卡搭建 ✅

直接在 Godot 3D 编辑器中用 CSG 节点搭建关卡几何体。

- [x] **4.2.1** CSG 几何体直接放置
  - 在 `main.tscn` 的 `Level` 节点下直接放置 `CSGBox3D` 作为地板/墙壁/柱子
  - 当前测试关卡：40×40m 大地板 + 手动放置的墙壁和柱子
  - 编辑器中可实时看到关卡外观，无需运行游戏

- [x] **4.2.2** 碰撞自动启用
  - `main.gd._enable_csg_collision(node)` 递归遍历 `Level` 下所有子节点
  - 对 `CSGBox3D`/`CSGPolygon3D`/`CSGCombiner3D` 自动设置 `use_collision = true`
  - 编辑器搭建时保留 `use_collision = false`（方便编辑），运行时自动开启

- [x] **4.2.3** PlayerStart 出生点
  - 在 `Level` 下放置一个 `Node3D` 节点，命名为 `PlayerStart`
  - `main.gd._load_level()` 遍历找名为 `PlayerStart` 的子节点，读取其 `global_position` 和 `global_rotation`
  - 传送玩家到该位置

- [x] **4.2.4** 灯光处理
  - 优先使用编辑器中已放置的灯光节点（`DirectionalLight3D` / `OmniLight3D`）
  - 如果没有任何灯光 → `main.gd._add_global_lights()` 自动创建默认方向光 + 补光
  - 不做 `light_level` 映射

---

### 4.3 关卡模板 ✅

- [x] **4.3.1** `scenes/level_template.tscn` 创建
  - 半透明参考地板（`CSGBox3D` 20×0.1×20m，标记 Y=0 地面高度）+ 编辑辅助灯光
  - 用于新建关卡时快速开始

---

### Phase 4 不再存在的文件

```
scripts/level/level_data.gd       ❌ 已删除（数据结构层不再使用）
scripts/level/level_builder.gd    ❌ 已删除（建造器不再使用）
scripts/editor/game_mode.gd       ❌ 已删除（PLAY/EDIT 模式切换不再使用）
```

---

## 第五阶段：关卡导出工具 + 数据结构重建（Phase 5）

> **目标**：重建 `LevelData` 数据结构 + 编写 `LevelExporter` 工具，将 Godot 编辑器搭建的 CSG 关卡扫描导出为 `.tres` 关卡文件。为后续的关卡分享、程序化生成、多关卡管理打基础。
>
> **背景**：Phase 4 删除了 `LevelData`/`LevelBuilder` 改用编辑器直接搭关卡。现在需要把"编辑器场景"→"数据文件"这条管线补回来，否则每张关卡都绑定在 .tscn 里无法独立管理。
>
> **不在此阶段**：编辑器 UI 面板（Phase 8）、纹理导出。

---

### 5.1 LevelData 数据结构重建（`scripts/level/level_data.gd`）

从零重建，比 Phase 1 版本更精简实用。

- [ ] **5.1.1** 创建 `LevelData` Resource 类
  - `class_name LevelData extends Resource`
  - `@export var level_name: String = "未命名"`
  - `@export var author: String = ""`
  - 数据结构：`sectors: Array[Sector]`、`things: Array[ThingDef]`（同 DOOM WAD 设计，但暂不做复杂扇区）

- [ ] **5.1.2** `Sector` 内部类（简化为 AABB 扇区）
  - `floor_height: float`、`ceiling_height: float`
  - `bounds: AABB` — 扇区包围盒（从 CSG 几何体自动计算）
  - `light_level: int`（0-255）
  - `walls: Array[WallDef]`

- [ ] **5.1.3** `WallDef` 内部类
  - `start: Vector2`、`end: Vector2`（XZ 平面 2D 线段）
  - `portal_to: int`（-1=实墙, >=0=通向其他扇区）

- [ ] **5.1.4** `ThingDef` 内部类
  - `type: enum { PLAYER_START, ENEMY, PICKUP, DECORATION }`
  - `position: Vector3`、`angle: float`、`subtype: StringName`

---

### 5.2 LevelExporter 导出工具（`scripts/editor/level_exporter.gd`）

扫描 `Level` 节点树，按命名约定识别几何体和实体，生成 `LevelData`。

- [ ] **5.2.1** 创建 `LevelExporter` 类
  - `static func export_from(node: Node3D) -> LevelData`
  - 遍历 `node` 的所有子节点（递归），按名称前缀分类

- [ ] **5.2.2** CSG 几何体识别
  - `Wall_*` → CSGBox3D → 提取为 `WallDef`（从 position + size + rotation 反算 2D 线段端点）
  - `Floor_*` / `Ceiling_*` → CSGBox3D → 提取 Y 位置作为 `floor_height` / `ceiling_height`
  - 没有前缀的 CSG 节点 → 忽略或归入最近扇区

- [ ] **5.2.3** 实体标记识别
  - `PlayerStart` → `ThingDef(PLAYER_START)`，读取 `global_position` + `global_rotation.y`
  - `Enemy_imp` / `Enemy_demon_soldier` → `ThingDef(ENEMY, subtype)`
  - `Pickup_health` / `Pickup_armor` / `Pickup_ammo` → `ThingDef(PICKUP, subtype)`
  - `Deco_*` → `ThingDef(DECORATION, subtype)`

- [ ] **5.2.4** 导出到 .tres 文件
  - `static func save_to_file(level_data: LevelData, path: String) -> void`
  - 使用 `ResourceSaver.save(level_data, path)`
  - 默认导出到 `assets/levels/` 目录

---

### 5.3 集成到 main.gd

- [ ] **5.3.1** 导出调用入口
  - 在 `main.gd` 中检测按键（如 Ctrl+E）触发导出
  - 调用 `LevelExporter.export_from(_level_root)` → `ResourceSaver.save()`
  - 导出后打印文件路径到控制台

- [ ] **5.3.2** 加载 .tres 关卡（替换编辑器关卡）
  - 修改 `_load_level()`：优先尝试加载 `res://assets/levels/test_room.tres`
  - 如果存在 → 用 `LevelBuilder.build()` 重建场景（Phase 5 不做，留到 Phase 8 多关卡系统）
  - 如果不存在 → 使用当前编辑器 CSG 关卡（现有逻辑）

---

### 5.4 修复 level_template.tscn

- [ ] **5.4.1** 移除对 `level_exporter.gd` 的引用
  - `level_template.tscn` 第 3 行引用了不存在的 `res://scripts/editor/level_exporter.gd`
  - 删除该 `ext_resource` 行——模板场景不需要脚本

- [ ] **5.4.2** 验证模板场景可用
  - 在编辑器中新建场景 → 继承 `level_template.tscn` → 应无报错

**工作流**：
```
Godot 3D 编辑器搭关卡（CSGBox3D + 标记节点）
  → 运行游戏 → serialize() 扫描场景树 → 生成 LevelData
  → ResourceSaver.save("关卡.tres")
  → 正常游玩时 load("关卡.tres") → LevelBuilder.build()
```

---

### 5.1 编辑器导出脚本（`scripts/editor/level_exporter.gd`）

在 `main.gd` 旁边新建一个导出工具类，把"扫描场景树 → 生成 LevelData"的逻辑封装起来。

- [ ] **5.1.1** 创建 `LevelExporter` 类（`extends RefCounted`）
  - 文件路径：`scripts/editor/level_exporter.gd`
  - `static func export_from_scene(scene_root: Node) -> LevelData` — 主入口
  - 扫描 `scene_root` 下所有子节点，按命名前缀分类

- [ ] **5.1.2** CSG 几何体 → 墙壁识别
  - 遍历所有 `CSGBox3D` 节点，匹配名称前缀：
    - `Wall_` 开头 → 提取 `position` 和 `size`，计算墙壁的起止点（2D 线段）和高度
    - `Portal_` 开头 → 同墙壁，但 `portal_to` 需要额外处理（手动在 metadata 中指定目标扇区）
  - 墙壁线段计算：CSGBox3D 位置在墙壁中心，`size.x` = 墙长，`size.z` = 墙厚
    - `wall_start = Vector2(center.x - size.x/2, center.z)`（取墙壁前表面）
    - `wall_end = Vector2(center.x + size.x/2, center.z)`

- [ ] **5.1.3** 扇区自动识别
  - 从 `Floor_` / `Ceiling_` 节点获取地板/天花板高度
  - 用 `OmniLight3D` 或自定义 Light 节点的 `light_energy` 推算扇区亮度
  - 简化方案：关卡只有一个大扇区（手动定义扇区范围），墙壁自动归入
  - 进阶方案（可选）：根据墙壁围成的封闭多边形自动划分扇区

- [ ] **5.1.4** 实体标记节点识别
  - 遍历所有 `Node3D` 节点（非 CSG）：
    - 名称 `PlayerStart` → `ThingDef(PLAYER_START)`
    - 名称 `Enemy_imp` / `Enemy_demon_soldier` → `ThingDef(ENEMY, subtype)`
    - 名称 `Pickup_*` → `ThingDef(PICKUP)`
    - 名称 `Deco_*` → `ThingDef(DECORATION, subtype)`
  - 提取 `global_position` 和 `rotation.y` 填入 `ThingDef`

---

### 5.2 导出工作流集成（`main.gd` 修改）

让游戏启动时检测关卡模式：如果 Level 节点下已有 CSG 几何体（编辑器搭的），就导出 `.tres` 再加载；如果没有就正常加载 `.tres`。

- [ ] **5.2.1** 编辑器关卡检测
  - 在 `main.gd._ready()` 中检查 `%Level` 下是否存在 `CSGBox3D` 子节点
  - 如果存在 → 认为这是"编辑器搭建模式" → 调用 `LevelExporter.export_from_scene()`
  - 如果不存在 → 正常流程：加载 `.tres` 或代码构建

- [ ] **5.2.2** 导出模式下的用户提示
  - 导出完成后在控制台打印：`已导出关卡：3 面墙, 1 出生点, 2 敌人 → 保存为 xxx.tres`
  - 导出成功后将关卡 `.tres` 保存到 `res://assets/levels/` 目录
  - 然后走正常加载管线：`load("xxx.tres") → LevelBuilder.build()`

- [ ] **5.2.3** 导出模式键位开关（可选）
  - 按 F5：仅导出（生成 `.tres` 但不游玩）
  - 按 F6：导出并立即游玩
  - 正常启动（无按键）：检测到编辑器几何体 → 自动导出 → 游玩

---

### 5.3 关卡模板场景（`scenes/level_template.tscn`）

提供一个预配置的关卡模板场景，包含基本灯光和参考网格，方便在 Godot 编辑器中直接开始搭关卡。

- [ ] **5.3.1** 创建模板场景
  - 新建 `scenes/level_template.tscn`
  - 根节点 `LevelRoot (Node3D)` + 方向光 + 补光
  - 参考平面（半透明灰色 plane，标记地面高度 Y=0）
  - 模板中不放任何墙壁/实体——让用户自己搭

- [ ] **5.3.2** 模板使用说明
  - 在编辑器中打开模板 → 另存为新关卡名
  - 用 CSGBox3D 搭墙壁（命名 `Wall_*`）、地板（`Floor_*`）、天花板（`Ceiling_*`）
  - 用 Node3D 放置实体标记（命名 `Enemy_imp`、`PlayerStart`）
  - 运行游戏 → 自动导出 `.tres` → 立刻可玩

---

### 5.4 验证与测试

- [ ] **5.4.1** 导出测试——简单方房间
  - 在 Godot 编辑器中搭一个 10×10m 方房间（4 面 `Wall_*` + 1 个 `Floor_` + 1 个 `Ceiling_`）
  - 放 1 个 `PlayerStart` + 1 个 `Enemy_imp`
  - 运行游戏 → 检查控制台输出 → 确认 `.tres` 文件生成
  - 验证：生成的 `.tres` 包含 1 扇区、4 面墙、1 出生点、1 敌人

- [ ] **5.4.2** 导出测试——多扇区连通空间
  - 搭两个相邻房间（中间用 `Portal_` 标记门洞）
  - 运行游戏 → 检查生成的 `.tres` 包含 2 扇区，Port 墙 `portal_to` 正确指向相邻扇区
  - 验证：玩家可以穿过门洞在两个房间间移动
  - 验证：敌人可以跨扇区追击玩家

- [ ] **5.4.3** 导出→游玩完整流程测试
  - 搭关卡 → 运行 → 自动导出 `.tres`
  - 第二次运行（Level 下无 CSG 几何体）→ 走正常加载管线 → 加载刚导出的 `.tres`
  - 验证：两个流程生成的 3D 场景外观一致
  - 射击验证：子弹能命中墙壁和敌人
  - 删除导出的 `.tres` → 运行 → 回退到代码构建的测试关卡（fallback 机制）

---

### 5.5 编辑器增强（可选优化）

这些任务不是必需的，但能大大提升编辑器搭关卡的体验。

- [ ] **5.5.1** 编辑器 Inspector 辅助插件（`@tool` 脚本）
  - 在 Godot 编辑器的 Inspector 面板中为关卡节点增加自定义控件
  - 例如：选中 `Enemy_imp` 节点 → 显示敌人类型下拉框、朝向角度滑块
  - 这是 Godot 编辑器插件开发，比写内置编辑器简单

- [ ] **5.5.2** 关卡缩略图自动生成
  - 导出时从 EditorCamera 角度拍一张俯视截图
  - 保存为 `关卡名_thumb.png`，用于关卡选择菜单

---

### Phase 5 新增文件清单

```
scripts/
  editor/
    level_exporter.gd      # LevelExporter 导出工具类（扫描场景树 → LevelData）
scenes/
  level_template.tscn      # 关卡模板场景（预配置灯光 + 参考平面）
```

### Phase 5 修改文件清单

```
scripts/main.gd             # 集成导出模式检测：CSG 几何体存在 → 导出 → 加载
scripts/level/level_data.gd  # 如果 WallDef 需要从 CSGBox3D 提取的新字段
```

---

## 第六阶段：UI/HUD + 菜单 + 拾取（Phase 6）

> **目标**：完善战斗 HUD（生命条、武器栏位）、建立菜单系统（主菜单/暂停/死亡画面）、实现拾取系统（血包/护甲/弹药）。让游戏"像个完整产品"。
>
> **不在此阶段**：音频（Phase 7）、贴图 UI 美化（Phase 7）、关卡选择菜单（需多关卡 Phase 8，此阶段只做框架）。
>
> **可复用资产**：已有 `PlayerStatus`（位置/状态/生命/击杀/武器名/弹药/换弹）、`DamageFlash`（全屏闪红）、`Crosshair`（命中标记）。

---

### 6.1 生命值 HUD 增强（`scripts/ui/player_status.gd` 修改）

当前已有 `生命: 100 / 100` 文字。改为更直观的**生命条 + 数字**组合。

- [ ] **6.1.1** 生命条（ProgressBar）
  - 用 `TextureProgressBar` 或自定义 `ColorRect` 拼出横向生命条
  - 宽 200px，高 16px，右上角生命文字上方
  - 颜色渐变：绿色(>70%) → 橙色(30-70%) → 红色(<30%) + 低血时闪烁
  - 使用 `_process` 中的 `_player_dmg.health / _player_dmg.max_health` 更新进度

- [ ] **6.1.2** 护甲值显示
  - 在生命条下方添加护甲数值 `护甲: 0`
  - 护甲值从 `_player_dmg` 的新属性 `armor: float` 读取
  - 蓝色调文字区分于生命值的绿色

- [ ] **6.1.3** 武器栏位指示器
  - 在右下角显示武器列表 `[1] 手枪  [2] 霰弹枪`
  - 当前装备的武器高亮（黄色/白色），未装备的灰色
  - 监听 `WeaponManager.weapon_changed` 信号更新高亮
  - 位置：右下角，弹药显示下方

---

### 6.2 护甲系统（`scripts/damage/damageable.gd` 修改）

护甲是 DOOM 核心机制——受伤时护甲先吸收部分伤害，再扣血。

- [ ] **6.2.1** `Damageable` 添加护甲属性
  - `var armor: float = 0.0` — 当前护甲值
  - `var max_armor: float = 100.0` — 最大护甲值
  - `signal armor_changed(current: float, max_val: float)` — 护甲变化信号

- [ ] **6.2.2** `take_damage()` 加入护甲减伤
  - 护甲吸收 50% 伤害（经典 DOOM 规则：蓝甲 50%，绿甲 33%）
  - 例：受到 20 伤 → 护甲 -10、血量 -10
  - 护甲不足时：剩余伤害全扣血量
  - 护甲归零时保留 0，不变成负数

---

### 6.3 菜单系统（新建文件）

- [ ] **6.3.1** 主菜单（`scripts/ui/main_menu.gd`）
  - 在 `main.tscn` 中新增一个 `MainMenu` CanvasLayer 节点，默认显示
  - 背景：纯黑 + 游戏标题 "DOOM-LIKE"（大字，红色/橙色）
  - 按钮列表（垂直居中）：开始游戏、设置、退出
  - "开始游戏" → 隐藏菜单 CanvasLayer、捕获鼠标、开始游戏循环
  - "退出" → `get_tree().quit()`
  - 初始状态：玩家不能移动/射击（`Input.mouse_mode = MOUSE_MODE_VISIBLE`，不处理射击输入）

- [ ] **6.3.2** 暂停菜单（`scripts/ui/pause_menu.gd`）
  - 新的 `PauseMenu` CanvasLayer，默认隐藏
  - 按 Esc 时：如果鼠标已捕获 → 显示暂停菜单 + `get_tree().paused = true`
  - 按钮：继续、返回主菜单
  - "继续" → 隐藏暂停、`get_tree().paused = false`、重新捕获鼠标
  - "返回主菜单" → `get_tree().paused = false`、切换回 MainMenu 显示
  - `player_controller.gd` 中的 Esc 逻辑改为发射信号，由 main.gd 协调

- [ ] **6.3.3** 死亡画面
  - 玩家死亡时（`Damageable.died` 信号）→ 显示死亡覆盖层
  - 文字 "你死了"（红色大字居中）+ "按 R 重新开始"（小字）
  - 按 R → 重新加载当前场景（`get_tree().reload_current_scene()`）
  - 期间禁用玩家移动/射击

- [ ] **6.3.4** 设置菜单（简化版）
  - 在暂停菜单或主菜单中加"设置"按钮
  - 可调参数：鼠标灵敏度（滑块）、Y轴反转（复选框）、音量（滑块，预留给 Phase 7）
  - 值保存到 `ConfigFile` 或直接改 `player_controller` 的 `@export` 变量
  - "返回"按钮回到上级菜单

---

### 6.4 拾取系统（新建文件）

- [ ] **6.4.1** `Pickup` 基类（`scripts/pickup/pickup.gd`）
  - `extends Area3D`
  - `signal picked_up(by: Node3D)` — 被拾取时发射
  - `@export var pickup_name: String = "物品"` — 拾取提示用的名字
  - `@export var respawn_time: float = 0.0` — 0=不重生，>0=秒后重生
  - `body_entered` 检测到 Player → 调用 `_on_pickup(by)` → `queue_free()`（或重生计时）
  - 外观：`CSGSphere3D` 或 `CSGBox3D` + 发光材质，悬浮旋转动画（`_process` 中绕 Y 轴旋转）

- [ ] **6.4.2** 血包拾取（`scripts/pickup/health_pickup.gd`）
  - `extends Pickup`
  - `@export var heal_amount: float = 25.0` — 小血包 25、中 50、大 100
  - `_on_pickup()` → 获取 Player 的 `Damageable`，`health = min(health + heal_amount, max_health)`
  - 外观：红色发光球体

- [ ] **6.4.3** 护甲拾取（`scripts/pickup/armor_pickup.gd`）
  - `extends Pickup`
  - `@export var armor_amount: float = 100.0`
  - `_on_pickup()` → 设置 `Damageable.armor = armor_amount`
  - 外观：蓝色发光球体

- [ ] **6.4.4** 弹药拾取（`scripts/pickup/ammo_pickup.gd`）
  - `extends Pickup`
  - `@export var ammo_amount: int = 10` — 补充备弹数量
  - `_on_pickup()` → 获取当前武器的 `_current_reserve`，`min(reserve + ammo, max_reserve)`
  - 外观：黄色发光盒子

- [ ] **6.4.5** 武器拾取（`scripts/pickup/weapon_pickup.gd`）
  - `extends Pickup`
  - `@export var weapon_data_path: String` — 武器 .tres 路径
  - 首次获得：向 `WeaponManager` 注册新武器
  - 已拥有：补充弹药（同弹药拾取）
  - 外观：对应武器颜色的大号发光盒子

- [ ] **6.4.6** 拾取通知 HUD
  - 在 `PlayerStatus` 中添加拾取提示标签（屏幕中央偏上）
  - 捡到物品时浮出物品名称 + 淡入淡出动画（约 1.5 秒后消失）
  - 用 Tweener 做：文字从下方浮上 + 透明度 1→0
  - 连续拾取多个时，新通知替换旧通知（不堆叠）

---

### 6.5 集成与验证

- [ ] **6.5.1** 在测试关卡中放置拾取物
  - 2 个血包（小 + 中）、1 个护甲、2 个弹药盒
  - 分散放在房间角落和柱子旁

- [ ] **6.5.2** 端到端测试清单
  - 启动游戏 → 显示主菜单 → 点"开始游戏" → 进入游戏
  - 主菜单"退出"按钮 → 退出游戏
  - 游戏中按 Esc → 暂停菜单 → "继续"恢复游戏
  - 暂停菜单"返回主菜单" → 回到主菜单
  - 玩家血量 < 30% → 生命条变红闪烁
  - 走进血包 → 血量恢复、屏幕浮出 "+25 生命"
  - 走进护甲 → 护甲数值更新、浮出"护甲"
  - 走进弹药盒 → 备弹 +10、浮出"+10 弹药"
  - 敌人攻击带护甲的玩家 → 护甲先扣（50%吸收）
  - 玩家死亡 → 死亡画面 → 按 R 重新开始

---

### Phase 6 新增/修改文件清单

```
新增:
  scripts/ui/
    main_menu.gd         # 主菜单
    pause_menu.gd         # 暂停菜单
    death_screen.gd       # 死亡画面
    settings_menu.gd      # 设置菜单
  scripts/pickup/
    pickup.gd             # Pickup 基类（Area3D）
    health_pickup.gd      # 血包
    armor_pickup.gd       # 护甲
    ammo_pickup.gd        # 弹药
    weapon_pickup.gd      # 武器拾取

修改:
  scripts/ui/player_status.gd     # 生命条 + 护甲 + 武器栏位 + 拾取通知
  scripts/damage/damageable.gd    # 护甲属性 + 减伤逻辑
  scripts/player/player_controller.gd  # Esc 改为发射信号（菜单管理）
  scenes/main.tscn                # 添加菜单 CanvasLayer + 拾取物节点
```

---

## 第七阶段：资源与音频（Phase 7）

### 7.1 纹理资源
- [ ] 地板纹理（石砖、金属板、血迹石砖）
- [ ] 墙壁纹理（混凝土、钢板、地狱石）
- [ ] 天空盒（或纯色天花板替代）
- [ ] UI 贴图（准星、数字字体、面板边框）

### 7.2 音频资源
- [ ] 手枪射击音效
- [ ] 霰弹枪射击音效
- [ ] 敌人发现玩家音效（咆哮）
- [ ] 敌人受伤/死亡音效
- [ ] 玩家受伤音效
- [ ] 拾取物品音效
- [ ] 背景音乐（BGM）
- [ ] 环境音效（风声、机械嗡嗡声）

### 7.3 音频管理器
- [ ] `AudioManager` 单例（Autoload）
- [ ] 音效播放接口（2D/3D 音效）
- [ ] BGM 播放/切换/淡入淡出
- [ ] 音量控制（主音量、音效、BGM 分轨）

---

## 第八阶段：打磨与发布（Phase 8）

### 8.1 视觉打磨
- [ ] 枪口闪光粒子特效
- [ ] 弹孔贴花（子弹击中墙壁留下痕迹）
- [ ] 敌人受伤粒子（血迹飞溅）
- [ ] 物品拾取粒子（光点飘起）
- [ ] 后处理效果（可选：色彩分级、泛光、颗粒感）

### 8.2 手感打磨
- [ ] 屏幕震动（射击时、爆炸时）
- [ ] 武器后坐力视觉反馈
- [ ] 头部晃动（移动时摄像机微摆）
- [ ] 落地震动

### 8.3 多关卡
- [ ] 设计 3-5 张完整关卡
- [ ] 关卡间过渡（完成条件 → 下一关）
- [ ] 难度选择（敌人数量/伤害倍率）

### 8.4 打包发布
- [ ] Windows 导出配置
- [ ] 图标和启动画面
- [ ] 性能优化（LOD、遮挡剔除）
- [ ] 最终测试与 Bug 修复

---

## 任务统计

| 阶段 | 主题 | 总任务 | 已完成 | 进度 |
|------|------|--------|--------|------|
| Phase 1 | 原型搭建 | 13 | 13 | 100% |
| Phase 2 | 武器与射击 | 24 | 24 | 100% |
| Phase 3 | 敌人系统 | 31 | 31 | 100% |
| Phase 4 | 关卡管线 | 7 | 7 | 100% |
| Phase 5 | 关卡导出+数据重建 | 12 | 0 | 0% |
| Phase 6 | UI/HUD+菜单+拾取 | 17 | 17 | 100% |
| Phase 7 | 资源与音频 | 16 | 0 | 0% |
| Phase 8 | 打磨与发布 | 14 | 0 | 0% |
| **总计** | | **134** | **92** | **69%** |

---

## 下一步建议

Phase 4 + Phase 6 已全部完成。当前进度：**134 个任务中完成 92 个（69%）**。

下一阶段：**Phase 5（关卡导出工具 + 数据结构重建）**——12 个原子化任务：

1. **5.1 LevelData 重建** — 从零重建数据结构（Sector/WallDef/ThingDef）
2. **5.2 LevelExporter 导出工具** — 扫描 CSG 节点树 → 生成 LevelData → 保存 .tres
3. **5.3 main.gd 集成** — Ctrl+E 触发导出
4. **5.4 修复模板** — level_template.tscn 已修复（移除损坏引用）

**当前关卡搭建方式**：在 Godot 编辑器中直接放 CSG 节点 + 拖入敌人 .tscn，`main.gd` 启动时自动开碰撞 + 找 PlayerStart。Phase 5 补上"导出为 .tres 文件"这条管线。
- `LevelBuilder.build()` 完整管线：数据 → 3D 场景
- `LevelBuilder.serialize()` 反向管线：3D 场景 → 数据
- Godot 编辑器自带：3D 正交/透视视图、选择/移动/旋转/缩放、网格吸附、撤销/重做


