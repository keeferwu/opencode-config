# opencode-config

### 介绍
configure for opencode

### Install codegraph
npx @colbymchenry/codegraph        # zero-install, or:
sudo npm install -g @colbymchenry/codegraph

### Install skills

|Command|Description|
| ------------------ | ------------ |
|npx skills add [skills]|Add skills to agents|
|npx skills list|List installed skills (alias: ls)|
|npx skills find [query]|Search for skills interactively or by keyword|
|npx skills remove [skills]|Remove installed skills from agents|
|npx skills check|Check for available skill updates|
|npx skills update|Update all installed skills to latest versions|
|npx skills init [name]|Create a new SKILL.md template|

### 使用说明

```
# 拷贝全局配置(superpowers) 到 ~/.config/opencode
# 安装skills 到 ~/.agents/skills
./install.sh

# 更新.opencode (OpenAgentsControl developer)
./install.sh --update

# 安装markitdown (docker)
./install.sh --markitdown

# 安装drawio
./install.sh --drawio

# 安装developer 到指定项目的目录，默认为~/.opencode
./install.sh --oac <project_dir>
```

### 工具选择

|你的需求| 推荐 |
| ------------------ | ------------ |
|强制规范流程 + TDD | Superpowers|
|学习我的代码风格 + 审批 | OAC|
|快速原型 | AGENTS.md|
|多 agent 并行 | Oh My OpenCode|


