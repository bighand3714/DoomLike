# DoomLike 项目路线图 — 原子化任务拆解

> **当前进度：第一阶段（原型搭建）** — 核心移动已完成，其余系统待实现。

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

### 3.1 敌人基类
- [ ] `Enemy` CharacterBody3D 基类
- [ ] 敌人状态枚举（`IDLE`, `PATROL`, `CHASE`, `ATTACK`, `PAIN`, `DEATH`）
- [ ] 状态机框架（`_process_state()` 分发）
- [ ] 生命值 + `Damageable` 接口
- [ ] 受击反应（闪白、击退、疼痛动画）
- [ ] 死亡动画 + 尸体残留

### 3.2 敌人 AI：小恶魔（Imp）
- [ ] 看见玩家时进入 CHASE 状态（视线检测 `RayCast3D`）
- [ ] 在一定距离内进入 ATTACK 状态（投掷火球）
- [ ] 巡逻路径点系统（PATROL 状态随机漫游）
- [ ] 失去玩家视野后搜索/返回巡逻
- [ ] 火球投射物（飞行、碰撞、伤害）

### 3.3 敌人 AI：恶魔士兵（Demon Soldier）
- [ ] 与 Imp 共享基类，调整参数
- [ ] 远程射击攻击（hitscan，非投射物）
- [ ] 掩体利用（移动中短暂停留射击）

### 3.4 投射物系统
- [ ] `Projectile` Area3D 基类（速度、伤害、生命周期）
- [ ] 投射物碰撞检测（击中玩家/墙壁/地面）
- [ ] 投射物特效占位（粒子/闪光）

---

## 第四阶段：关卡管线连接（Phase 4）

### 4.1 LevelData ↔ 3D 场景转换
- [ ] `LevelBuilder._build_sector()` 实现——从 WallDef 数组生成墙壁几何体
- [ ] 墙壁几何体生成（用 CSGPolygon3D 或自定义 Mesh）
- [ ] 地板/天花板生成（CSGBox3D 或 PlaneMesh）
- [ ] 扇区 Portal 处理（相邻扇区间的开口）
- [ ] `LevelBuilder._place_thing()` 实现——生成敌人/物品/玩家出生点
- [ ] 光照从 `light_level` 映射到实际灯光节点

### 4.2 场景 → LevelData 反向序列化
- [ ] `LevelBuilder.serialize()` 实现——遍历节点提取数据
- [ ] 扇区识别（检测封闭多边形）
- [ ] 墙壁参数提取（位置、纹理、Portal 关系）
- [ ] 实体识别与分类

### 4.3 main.gd 重构
- [ ] 移除硬编码 `_build_test_room()`
- [ ] 改为加载 `.tres` 关卡文件 → `LevelBuilder.build()` 流程
- [ ] 创建第一张正式关卡数据文件（`test_room.tres`）
- [ ] 关卡加载/卸载流程（切换关卡）

---

## 第五阶段：地图编辑器（Phase 5）

### 5.1 编辑器基础框架
- [ ] 将 `GameModeManager` 挂载到场景树
- [ ] Tab 键切换 PLAY / EDIT 模式
- [ ] EDIT 模式下释放鼠标、切换为自由视角（fly cam）
- [ ] PLAY 模式下恢复 FPS 控制和准星

### 5.2 编辑器 UI 面板
- [ ] 编辑器主面板（侧边栏/底部栏）
- [ ] 工具选择（放置墙壁、放置实体、选择/移动、删除）
- [ ] 扇区列表面板（选中/高亮/编辑属性）
- [ ] 实体属性面板（类型、位置、子类型）
- [ ] 关卡属性面板（名称、作者、BGM）

### 5.3 编辑器核心操作
- [ ] 放置墙壁（点击两点创建一面墙）
- [ ] 墙壁编辑（移动端点、修改纹理/Portal 属性）
- [ ] 放置实体（从调色板拖拽到地面）
- [ ] 选择/移动/旋转/删除工具
- [ ] 撤销/重做系统（命令模式）

### 5.4 关卡文件管理
- [ ] 新建关卡（生成空白 `.tres`）
- [ ] 保存关卡（`ResourceSaver.save()`）
- [ ] 加载关卡（`ResourceLoader.load()`）
- [ ] 关卡文件列表/浏览器

---

## 第六阶段：UI/HUD 系统（Phase 6）

### 6.1 HUD
- [ ] 生命值显示（数值 + 头像，DOOM 经典底栏风格）
- [ ] 护甲值显示
- [ ] 当前武器 + 弹药显示（弹匣/备弹）
- [ ] 武器栏位指示器（高亮当前武器）
- [ ] 受伤效果（屏幕闪红）
- [ ] 拾取提示（物品名称浮现）

### 6.2 菜单系统
- [ ] 主菜单（开始游戏、关卡选择、设置、退出）
- [ ] 暂停菜单（继续、重新开始、返回主菜单）
- [ ] 设置菜单（鼠标灵敏度、Y轴反转、音量、画面）
- [ ] 关卡完成/死亡画面

### 6.3 拾取系统
- [ ] `Pickup` Area3D 基类
- [ ] 拾取触发检测（玩家走进区域）
- [ ] 弹药拾取（各武器弹药类型）
- [ ] 血包（小/中/大）
- [ ] 护甲（小/大）
- [ ] 武器拾取（首次获得武器）

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
| Phase 3 | 敌人系统 | 9 | 0 | 0% |
| Phase 4 | 关卡管线 | 9 | 0 | 0% |
| Phase 5 | 地图编辑器 | 15 | 0 | 0% |
| Phase 6 | UI/HUD | 16 | 0 | 0% |
| Phase 7 | 资源与音频 | 16 | 0 | 0% |
| Phase 8 | 打磨与发布 | 14 | 0 | 0% |
| **总计** | | **116** | **37** | **32%** |

---

## 下一步建议

Phase 2 已全部完成。当前进度：**116 个任务中完成 37 个（32%）**。

下一阶段：**Phase 3（敌人系统）**——添加敌人 AI 和投射物系统，实现"能开枪 + 有敌人可打"的完整战斗循环。
