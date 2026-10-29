# opencode-config

### 介绍
configure for opencode

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
./install.sh --omo --rtk
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

### comet 使用说明
comet的只要功能是 自动安装 OpenSpec、Superpowers，一键配置开发环境
多阶段 Skill 入口，自动识别当前 Spec 阶段，核心流程自动触发，关键节点人工审核
comet init 会：
提示你选择 AI 平台（自动检测已有配置）
选择安装范围：项目级（当前目录）或全局（用户主目录）
选择 Comet 技能语言：English 或 中文
安装 OpenSpec 技能
安装 Superpowers 技能
将 Comet 技能（你选择的语言）部署到所选平台
在项目级安装时创建 docs/superpowers/specs/ 和 docs/superpowers/plans/ 工作目录

Comet 技能列表

|技能|说明|
| ------------------ | ------------ |
| /comet-opencode | 阶段 1：打开变更（提案、设计、任务分解）|
| /comet-design | 阶段 2：深度设计（头脑风暴、设计文档）|
| /comet-build | 阶段 3：规划与构建（实现计划、代码提交）|
| /comet-verify | 阶段 4：验证与完成（测试、验证报告）|
| /comet-archive | 阶段 5：归档（delta spec 同步、状态标注）|
| /comet-hotfix | 快捷路径：快速 bug 修复（跳过头脑风暴，不需要能力设计）|
| /comet-tweak | 快捷路径：小改动（文案调整、配置调整、文档或 Prompt 优化）|

### 工具选择

|你的需求| 推荐 |
| ------------------ | ------------ |
|新项目开发 | OMO (oh-my-openagent) native |
|旧项目维护 | opencode (oh-my-opencode-slim + superpowers) |
