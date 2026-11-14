# opencode-config

### 介绍
configure for opencode V2

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
git clone https://gitee.com/keeferwu/opencode-config ~/.opencode
# 交互式安装器: 先检测 nodejs/npm/opencode/jq 等依赖并同步默认配置, 再从组件列表中选择安装
./install.sh
# 仅查看组件列表与当前安装状态(不安装)
./install.sh --list
# 只检查并安装基础依赖
./install.sh --env
# 查看全部可安装的增强应用
./install.sh --help
# 参数模式: 直接安装指定组件, 可组合
./install.sh --omo-slim --rtk
```

每次运行安装器都会先执行: 检测基础依赖(缺失时询问安装) + 同步默认配置(把 `tui.json`、`opencode.jsonc`、`dcp.jsonc`、`agents`、`commands`、`rules`、`skills`、`codebase_memory` 同步到 `~/.config/opencode` 并安装全局 skills), 这部分不属于组件列表。`--list`、`--help`、`--env` 只做查看/依赖检查, 不执行配置同步。

交互式安装器操作方式

|输入|说明|
| ------------------ | ------------ |
|1 3|输入编号(空格分隔多个)后回车, 按顺序安装对应组件|
|a|安装列表中所有未安装的组件|
|l|刷新依赖检测与安装状态列表|
|q 或直接回车|退出安装器|

列表项前的 `✓ 已安装` / `· 未安装` 表示该组件当前状态, 每个组件安装完成后会回到列表, 可继续安装其他组件。

### 项目工具选择

|你的需求| 推荐 | 可选 |
| ------------------ | ------------ | ------------ |
|模型较弱 | superpowers | |
|新项目开发 | spec-kit + ponytail(lite) | |
|旧项目新功能 | openspec + ponytail(full) | oh-my-opencode-slim |
|旧项目修bug | ponytail(lite) | oh-my-opencode-slim |
|旧项目重构 | ponytail(lite) | oh-my-opencode-slim |
|旧项目优化 | ponytail(full) | oh-my-opencode-slim |

### 工具冲突

|工具| 冲突对象 |
| ------------------ | ------------ |
|openspec | spec-kit, superpowers |
|spec-kit | oh-my-opencode-slim, openspec, superpowers |
|superpowers | oh-my-opencode-slim, spec-kit, openspec, ponytail |
|codegraph | codebase-memory-mcp |
