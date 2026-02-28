# opencode-config

### 介绍
configure for opencode

### 使用说明

```
# 拷贝全局配置opencode 到 ~/.config/opencode
./install.sh

# 更新.opencode (OpenAgentsControl developer)
./install.sh --update

# 安装developer 到指定项目的目录，默认为~/.opencode
./install.sh --oac <project_dir>

# 安装superpowers到指定项目的目录
./install.sh --superpowers <_project_dir>
```

### 工具选择

|你的需求| 推荐 |
| ------------------ | ------------ |
|强制规范流程 + TDD | Superpowers|
|学习我的代码风格 + 审批 | OAC|
|快速原型 | AGENTS.md|
|多 agent 并行 | Oh My OpenCode|


