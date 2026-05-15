# 多 Agent 工作流规则

## Git 分支策略

```
master          ← 稳定，仅通过集成 PR 更新
  ├── agent-core/feature-name
  ├── agent-player/feature-name
  ├── agent-weapons/feature-name
  ├── agent-enemies/feature-name
  ├── agent-level/feature-name
  ├── agent-ui/feature-name
  └── integration/YYYY-MM-DD   ← 合并所有 agent 分支
```

## 变更顺序

1. **接口变更先行**：GameBus 信号、公共方法签名变更必须最先提交
2. **枚举追加在后**：新增 enum 值放在末尾，不重排顺序
3. **消费者跟进**：接口变更后，所有依赖模块在各自分支跟进

## 冲突热点解决

| 冲突类型 | 解决方式 |
|---------|---------|
| GameBus 信号新增 | Agent-Core 审核 → 合并 → 其他 agent rebase |
| WeaponData.DamageType 新增值 | Agent-Weapons 通知所有 agent → 追加在末尾 |
| Enemy 基类方法签名变更 | 全 team 讨论 → Agent-Enemies 实施 |
| .tscn 文件冲突 | 先到先得；后提交者 rebase 解决 |

## 验证清单

每个 agent 提交 PR 前必须：

- [ ] 项目能正常启动到主菜单
- [ ] 修改的模块功能在游戏中可测试
- [ ] 无新增的 `get_tree().root.get_node_or_null("Main")` 硬编码路径
- [ ] 无访问其他模块私有变量 (以 `_` 开头)
- [ ] 新增公共 API 已更新对应的 `docs/module_interfaces/*.md`
- [ ] 如修改 GameBus 信号，已更新 `docs/module_interfaces/GAMEBUS.md`

## 通信规则

- 模块间永远通过 GameBus 信号或已定义的公共 API 通信
- 禁止 `get_node("../../OtherModule")` 跨模块节点查找
- 禁止通过 `get("_private_var")` 字符串访问私有成员
- `preload()` 其他模块的 .gd 文件时，只能使用其 class_name，不能直接操作其内部状态
