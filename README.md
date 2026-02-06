

# OpenCode Config - OpenAgents Control

OpenAgents Control (OAC) 是一个用于控制 AI 代理行为的配置系统，帮助团队实现可重复、可控的 AI 开发工作流程。通过模式定义、上下文管理和精细的权限控制，团队可以建立统一的 AI 开发标准。

## 核心特性

### 🤖 智能代理框架

系统提供多层次的代理架构，满足不同开发场景的需求：

- **OpenAgent** - 通用代理入口，适合日常开发任务
- **OpenCoder** - 专业开发代理，专注于生产环境代码开发
- **BuildAgent** - 构建代理，处理项目编译和部署
- **CoderAgent** - 编码代理，专注于具体代码实现
- **TestEngineer** - 测试工程师，负责测试用例编写
- **CodeReviewer** - 代码审查代理，保证代码质量

### 📚 上下文系统 (MVI 原则)

基于 **Minimal Viable Information (MVI)** 的上下文管理系统，确保代理只获取必要信息，提高响应效率并降低 token 消耗。

**核心优势：**
- 最小化信息传递，避免上下文膨胀
- 基于功能的结构化组织
- 高效的导航和引用机制
- 自动知识提取和整理

**组织模式：**
- **功能导向** - 针对特定仓库的上下文
- **关注点导向** - 针对开发流程的上下文
- **混合模式** - 结合两种优势

### ⚡ 命令系统

内置丰富的生产力命令，简化日常开发工作：

| 命令 | 功能 |
|------|------|
| `/add-context` | 添加和管理项目上下文 |
| `/analyze-patterns` | 分析代码模式 |
| `/clean` | 代码质量清理 |
| `/commit` | 生成规范的提交信息 |
| `/context` | 上下文管理操作 |
| `/optimize` | 代码优化分析 |
| `/test` | 运行测试管道 |
| `/validate-repo` | 仓库配置验证 |

### 🛠️ 专业技能模块

#### 文档处理
- **PDF Skill** - PDF 创建、编辑、提取、表单处理
- **DOCX Skill** - Word 文档创建和编辑
- **PPTX Skill** - PowerPoint 演示文稿制作
- **XLSX Skill** - Excel 电子表格处理

#### 开发工具
- **Context7** - 获取最新文档和 API 参考
- **MCP Builder** - MCP 服务器开发框架
- **Skill Creator** - 自定义技能创建工具
- **Task Management** - 任务管理和跟踪

### 🔧 子代理系统

系统支持自动委派的专业子代理：

| 子代理 | 用途 |
|--------|------|
| ContextScout | 项目上下文发现和分析 |
| ExternalScout | 外部库文档获取 |
| TaskManager | 任务分解和管理 |
| FrontendSpecialist | 前端设计和实现 |
| DevOpsSpecialist | 运维和部署 |
| DocWriter | 文档编写 |

## 快速开始

### 1. 安装

```bash
# 克隆仓库
git clone https://gitee.com/keeferwu/opencode-config.git
cd opencode-config

# 运行安装脚本
./install.sh
```

### 2. 配置代理

根据需求选择合适的代理开始开发工作。系统会自动加载相关上下文和配置。

### 3. 使用上下文系统

为项目添加模式定义：

```bash
# 添加项目上下文
/context add
```

### 4. 运行命令

使用内置命令提升开发效率：

```bash
# 代码清理
/clean

# 代码优化
/optimize

# 验证仓库配置
/validate-repo
```

## 项目结构

```
opencode-config/
├── .opencode/                    # 核心配置
│   ├── agent/                     # 代理定义
│   │   ├── core/                 # 核心代理
│   │   └── subagents/            # 子代理
│   │       ├── code/              # 代码相关
│   │       ├── core/              # 系统核心
│   │       ├── development/       # 开发辅助
│   │       └── system-builder/    # 系统构建
│   ├── command/                   # 命令定义
│   ├── context/                   # 上下文系统
│   │   ├── core/                 # 核心上下文
│   │   ├── development/          # 开发上下文
│   │   ├── openagents-repo/      # 代理仓库上下文
│   │   ├── project-intelligence/ # 项目情报
│   │   └── ui/                    # UI 上下文
│   └── skill/                     # 技能模块
│       ├── context7/              # 文档获取
│       ├── task-management/       # 任务管理
│       └── ...
├── global/                        # 全局配置
│   ├── agents/                    # 全局代理
│   ├── commands/                  # 全局命令
│   ├── opencode.json/            # 全局配置
│   ├── rules/                     # 全局规则
│   └── skills/                    # 全局技能
│       ├── docx/                  # DOCX 处理
│       ├── pdf/                   # PDF 处理
│       ├── pptx/                  # PPTX 处理
│       ├── mcp-builder/           # MCP 开发
│       └── ...
└── install.sh                     # 安装脚本
```

## 适用场景

### ✅ 适合使用的情况

- 需要统一的 AI 开发标准和流程
- 团队协作开发，需要共享上下文
- 需要精细控制 AI 代理行为
- 需要处理多种文档格式
- 构建自定义 AI 工作流程

### ⚠️ 不需要的情况

- 简单的单一任务脚本
- 不需要上下文管理的简单项目

## 工作流程示例

### 基本开发流程

```
1. 初始化项目上下文
   → /add-context
   
2. 委派任务给代理
   → 使用 OpenAgent 或 OpenCoder
   
3. 代码实现
   → CoderAgent 自动委派子代理
   
4. 测试验证
   → TestEngineer 编写测试
   
5. 代码审查
   → CodeReviewer 检查质量
   
6. 提交代码
   → /commit 生成规范提交信息
```

### 团队协作模式

```
团队负责人：
1. 添加项目标准和模式
   → /add-context 定义团队规范
   
2. 提交到仓库
   → 所有成员自动继承标准

团队成员：
1. 克隆项目
   → 自动获取上下文和标准
   
2. 开始开发
   → 使用统一的代理配置
```

## 高级配置

### 模型配置（可选）

```yaml
model: anthropic/claude-sonnet-4-5  # 可根据需要修改
```

### 自定义上下文

系统支持根据项目需求添加和定制上下文：

- **项目情报** - 业务领域、技术栈、决策记录
- **开发标准** - 代码规范、安全要求、测试标准
- **工作流程** - 任务分解、代码审查、发布流程

## 文档资源

- **上下文系统指南** - 了解 MVI 原则和上下文组织
- **代理开发指南** - 创建和配置自定义代理
- **技能开发指南** - 开发自定义技能模块
- **命令参考** - 完整命令列表和使用说明

## 许可证

本项目遵循项目仓库中 LICENSE 文件规定的许可协议。

## 贡献指南

欢迎贡献代码、文档和反馈。请参考项目中的贡献指南了解详细流程。

## 联系方式

- 项目地址：https://gitee.com/keeferwu/opencode-config
- 问题反馈：请通过 Gitee Issues 提交