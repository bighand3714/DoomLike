# Player 3D 角色模型方案 (方案三：MeshInstance3D + 基础网格)

## 目标

用 Godot 内置基础网格（BoxMesh / CylinderMesh / SphereMesh / PrismMesh）搭建
1.5m 兽耳灰发 JK 主角形象。构成主义风格 —— 几何块面、棱角分明、
低多边形美学，完全契合项目现有 CSG 视觉语言。

## 为什么选方案三而非 CSG

- **骨骼动画留后路**：MeshInstance3D 可绑定 Skeleton3D，后续可做手臂动画
- **性能零开销**：静态网格无运行时布尔运算
- **可替换**：后续从 Blender 导入 .glb 模型时节点结构不变，只换 mesh
- **轻量**：tscn 文件不臃肿

## 角色设定

| 属性 | 值 |
|------|-----|
| 身高 | 1.5m（娇小 JK 比例） |
| 头身比 | ~5.5头身（略偏 Q 版，适合构成主义简化） |
| 发型 | 灰色短发，后颈清爽，两侧略遮耳 |
| 兽耳 | 灰色三角形猫耳/狼耳，竖于头顶 |
| 服装 | JK 水手服上衣 + 百褶裙 + 红色领巾 |
| 鞋 | 黑色及膝袜 + 乐福鞋 |

## 构成主义风格要义

- **块面化**：所有曲面用 6-8 边棱柱替代
- **平直切割**：不追求流线，刻意保留硬边
- **纯色块 + 少量分割线**：不用渐变，用几何色块区分部位
- **领巾作为唯一动态元素**：红色三角面片，视觉焦点

## 身体比例计算 (1.5m 总高)

```
头顶 ~ 1.50m     ← 耳尖 +0.12m
眼高 ~ 1.36m     (14cm 头顶到眼)
下巴 ~ 1.22m     (14cm 头高)
肩   ~ 1.18m
胸   ~ 1.08m
腰   ~ 0.95m
髋   ~ 0.82m
指尖 ~ 0.48m     (臂展 ~1.4m)
膝   ~ 0.45m
踝   ~ 0.08m
足底 ~ 0.00m
```

## 节点层级结构

```
PlayerModel (Node3D)                          ← 挂在 Player 节点下，作为视觉子节点
├── Body (MeshInstance3D + BoxMesh)            ← 躯干 0.32×0.38×0.55m, 灰蓝/藏青水手服
├── Pelvis (MeshInstance3D + BoxMesh)          ← 骨盆 0.28×0.18×0.12m, 裙子深蓝
├── Skirt (MeshInstance3D + CylinderMesh)      ← 百褶裙 6边棱柱, 半径0.22, 高0.2m
│
├── Neck (MeshInstance3D + CylinderMesh)       ← 颈 6边棱柱, 半径0.06, 高0.08m, 肤色
│
├── Head (Node3D)                              ← 头部组, 位置 (0, 1.36, 0)
│   ├── Skull (MeshInstance3D + BoxMesh)       ← 头骨主体 0.18×0.22×0.18m
│   ├── Jaw (MeshInstance3D + BoxMesh)         ← 下颌 0.16×0.08×0.12m, 略前移
│   ├── LeftEar (MeshInstance3D + PrismMesh)   ← 左兽耳, 三角形锥体
│   ├── RightEar (MeshInstance3D + PrismMesh)  ← 右兽耳
│   ├── HairBack (MeshInstance3D + BoxMesh)    ← 后发 0.20×0.06×0.12m
│   ├── HairLeft (MeshInstance3D + BoxMesh)    ← 左侧发
│   ├── HairRight (MeshInstance3D + BoxMesh)   ← 右侧发
│   └── Bangs (MeshInstance3D + BoxMesh)       ← 刘海 0.20×0.03×0.06m
│
├── LeftArm (Node3D)                           ← 位置 (0.18, 1.12, 0)
│   ├── LeftUpperArm (MeshInstance3D + BoxMesh) ← 上臂 0.09×0.24×0.09m
│   ├── LeftForearm (MeshInstance3D + BoxMesh)  ← 前臂 0.08×0.22×0.08m
│   └── LeftHand (MeshInstance3D + BoxMesh)     ← 手 0.07×0.10×0.04m
│
├── RightArm (Node3D)                          ← 位置 (-0.18, 1.12, 0)
│   ├── RightUpperArm (MeshInstance3D + BoxMesh)
│   ├── RightForearm (MeshInstance3D + BoxMesh)
│   └── RightHand (MeshInstance3D + BoxMesh)
│
├── LeftLeg (Node3D)                           ← 位置 (0.09, 0.75, 0)
│   ├── LeftUpperLeg (MeshInstance3D + BoxMesh) ← 大腿 0.12×0.32×0.12m
│   ├── LeftLowerLeg (MeshInstance3D + BoxMesh) ← 小腿 0.10×0.30×0.10m
│   └── LeftFoot (MeshInstance3D + BoxMesh)     ← 脚 0.10×0.06×0.16m
│
├── RightLeg (Node3D)                          ← 位置 (-0.09, 0.75, 0)
│   ├── RightUpperLeg (MeshInstance3D + BoxMesh)
│   ├── RightLowerLeg (MeshInstance3D + BoxMesh)
│   └── RightFoot (MeshInstance3D + BoxMesh)
│
├── Scarf (Node3D)                             ← 领巾组
│   ├── ScarfKnot (MeshInstance3D + BoxMesh)    ← 领结 0.06×0.06×0.04m
│   ├── ScarfLeft (MeshInstance3D + BoxMesh)    ← 左飘带 0.04×0.22×0.01m, 旋转-15°
│   └── ScarfRight (MeshInstance3D + BoxMesh)   ← 右飘带 0.04×0.22×0.01m, 旋转+15°
│
└── Tail (MeshInstance3D + PrismMesh)          ← 可选兽尾, 三角锥
```

## 网格选型指南

| 部位 | 网格类型 | 理由 |
|------|----------|------|
| 躯干/四肢 | **BoxMesh** | 构成主义核心，棱角分明 |
| 头部主体 | **BoxMesh** | 切面感，非圆球 |
| 颈部/裙子 | **CylinderMesh** (6 sides) | 六边形棱柱，比圆柱硬朗 |
| 兽耳/尾巴 | **PrismMesh** | 天然三角形锥体，契合兽耳 |
| 领巾飘带 | **BoxMesh** (压扁) | 薄片方块，旋转做飘动感 |

## 材质配色方案

| 部位 | 颜色 | 说明 |
|------|------|------|
| 头发（主体） | `#B0B8C8` 灰银 | StandardMaterial3D, albedo |
| 头发（暗面） | `#8A909E` 深灰 | 后发/内层 |
| 皮肤 | `#F5DCC8` 浅肤色 | 脸/颈/手 |
| 水手服上衣 | `#2C3E6B` 藏青 | 衣身主体 |
| 衣领/袖口条纹 | `#FFFFFF` 白色 | 两道白线 |
| 百褶裙 | `#1A2744` 深蓝 | 裙子 |
| 领巾 | `#D4343E` 朱红 | **视觉焦点** |
| 兽耳内侧 | `#F0C8C0` 粉肤色 | 耳内 |
| 袜子 | `#1A1A1A` 暗黑 | 及膝袜 |
| 鞋 | `#2E1A0E` 深棕 | 乐福鞋 |

## 文件规划

```
scenes/player/
  player_model.tscn       ← 新建，角色模型子场景（所有 MeshInstance3D 在此）
  player.tscn              ← 现有，添加 PlayerModel 实例作为子节点

assets/materials/
  player_body.tres         ← 藏青水手服
  player_skin.tres         ← 肤色
  player_hair.tres         ← 灰银发色
  player_hair_dark.tres    ← 深灰发色
  player_skirt.tres        ← 深蓝裙子
  player_scarf.tres        ← 朱红领巾
  player_ear_inner.tres    ← 耳内粉
  player_socks.tres        ← 暗黑袜子
  player_shoes.tres        ← 深棕鞋子
```

## 实现步骤

### Step 1：创建材质资源 (10 min)

用 Godot MCP 的 `create_resource` 创建 9 个 StandardMaterial3D .tres 文件，
设置 albedo_color 为对应颜色。

### Step 2：搭建角色模型子场景 (30 min)

用 `create_scene` + `create_node` + `batch_scene_node_edits` 按层级表逐步搭建：
1. 创建 PlayerModel 根节点 (Node3D)
2. 躯干 + 骨盆 + 裙子
3. 头颈 + 脸部块面 + 兽耳 + 发型块面
4. 四肢（左右臂/腿/手脚）
5. 领巾组（结 + 两条飘带）
6. 调整各节点 transform 使其拼接成完整角色

### Step 3：挂载到 Player (5 min)

在 player.tscn 中添加 PlayerModel 实例，置于 Camera3D 层级之下
（位置约在 Player 原点上方 0.9m，作为玩家自身的视觉锚点）。

### Step 4：创建 FirstPersonArms 子集 (10 min)

提取手臂/手部网格，挂在 WeaponHolder 下作为第一人称手臂。
FPS 视角下只看到手臂和武器，看不到身体其余部分。

### Step 5：运行时隐藏自身模型 (5 min)

在 `player_controller.gd` 的 `_ready()` 中，对 PlayerModel 做
`set_layer_mask` 或 `visible = false`（FPS 不需要看到自己全身，
但保留用于阴影投射/多人模式/编辑器预览）。

## 边界情况与注意事项

- **FPS 视角冲突**：默认隐藏 PlayerModel，仅保留第一人称手臂
- **阴影投射**：PlayerModel 设 `cast_shadow = SHADOW_CASTING_SETTING_ON`（仅阴影，不渲染本体）
- **碰撞体已在 Player 上**：PlayerModel 不需要额外碰撞
- **构成主义一致性**：所有 CylinderMesh sides=6，保持六边形棱柱统一
- **兽耳位置**：耳根部在头顶 (0, 1.43, 0) 左右偏移 ±0.06m
- **领巾层级**：挂在 Neck 下方，跟随身体旋转

## 待定事项（需确认后执行）

1. 是否需要兽尾？如果需要，是什么形状（猫尾/狼尾）？
2. 第一人称手臂是否现在就做，还是等后续武器动画阶段？
3. 是否接受这种纯几何拼接的外观？构成主义下不会有柔和曲线。
