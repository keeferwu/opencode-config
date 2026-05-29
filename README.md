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
# 拷贝全局配置到 ~/.config/opencode
# 安装skills 到 ~/.agents/skills
./install.sh

# 查看可安装的增强应用
./install.sh --help
```

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
|新项目开发 | comet |
|强制规范流程 + TDD | Superpowers|
|学习我的代码风格 + 审批 | OAC|
|快速原型 | AGENTS.md|
|多 agent 并行 | Oh My OpenCode|


