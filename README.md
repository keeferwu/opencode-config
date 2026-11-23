# opencode-config

opencode V2 的个人配置与增强组件安装器。仓库本身就是 `~/.config/opencode` 的内容源: 一份 TUI 外观配置、agents/commands/rules/skills, 外加一个可选组件的安装脚本。

## 快速开始

```bash
git clone https://gitee.com/keeferwu/opencode-config ~/.opencode
cd ~/.opencode

./install.sh                 # 交互式: 检测依赖 → 同步默认配置 → 从列表里选组件
./install.sh --list          # 只看组件列表与当前安装状态, 不安装
./install.sh --env           # 只检查并安装基础依赖
./install.sh --help          # 查看全部参数
./install.sh --omo-slim --rtk   # 参数模式: 直接装指定组件, 可组合多个
```

## 安装器做了什么

每次运行 `./install.sh` 都会先做这两步, 它们不属于组件列表:

**1. 依赖检测** —— 缺失时询问是否安装
`jq` `curl` `git` `rsync` `tar` `python3` `pip` `nodejs` `npm` `bun` `opencode`

**2. 同步默认配置** 到 `~/.config/opencode`, 并把全局 skills 装到 `~/.agents/skills`

| 内容 | 说明 |
| --- | --- |
| `cli.json` | TUI 主题、滚动、快捷键 |
| `opencode.jsonc` | 主配置(provider/MCP/插件) |
| `agents` `commands` `rules` `skills` | 自定义 agent、命令、规则、技能 |
| `codebase_memory` | codebase-memory 相关的 agents/skills/plugins |

仓库位于 `~/.opencode` 时, `cli.json`、`rules`、`codebase_memory` 会用软链接代替拷贝, 改动即时生效。

同时会往 `~/.env` 写入几条环境变量(已存在则跳过): `EDITOR=vim`、`OPENCODE_DISABLE_CLAUDE_CODE=true`(不加载 `.claude` 配置)、`OPENCODE_DISABLE_EXTERNAL_SKILLS=false`(启用 `.agents/skills`)。

`--list`、`--help`、`--env` 只做查看/依赖检查, 不执行配置同步。

## 可安装组件

`./install.sh --list` 会打印下面这些组件, 并标注当前状态(`✓ 已安装` / `· 未安装`)与版本号。

|编号| 参数 | 组件 | 说明 |
| --- | ------------------ | ------------ | ------------ |
|1|`--rtk`|rtk|压缩命令输出, 节省 token|
|2|`--codegraph`|codegraph|代码图谱(适合单一代码库, 查询调用链与依赖)|
|3|`--codebase-memory`|codebase-memory|代码图谱(适合多语言混合代码库, 整理依赖关系)|
|4|`--omo-slim`|oh-my-opencode-slim|多模型 agent 编排插件|
|5|`--omniroute`|omniroute|LLM 网关统一管理 APIKEY|
|6|`--ocr`|open-code-review|代码质量评审|
|7|`--openspec`|openspec|规范驱动开发(旧项目:提案/规范/归档)|
|8|`--speckit`|speckit|规范驱动开发(新项目:规格→计划→任务→实现)|
|9|`--officecli`|officecli|处理 docx/xlsx/pptx|
|10|`--caveman`|caveman|压缩上下文内容, 节省 token|
|11|`--graphify`|graphify|绘制代码知识图谱(包含项目文档和资料)|
|12|`--drawio`|drawio|绘制图表 (desktop + skill)|
|13|`--cua`|cua-driver|后台驱动桌面应用|
|14|`--agentmemory`|agentmemory|agent 记忆|
|15|`--archify-skill`|archify-skill|绘制架构/流程/时序图 skill|
|16|`--book-to-skill`|book-to-skill|书籍/文档转 skill|
|17|`--browser-skill`|browser-skill|接管已登录浏览器的自动化 skill|
|18|`--plannotator`|plannotator|plan/代码评审 UI, 浏览器里标注|

几个需要动手的地方:

- **oh-my-opencode-slim** 装完默认关闭(`OH_MY_OPENCODE_SLIM_DISABLE=1`), 要用就改成 `0`
- **codebase-memory** 装完还要按项目初始化, 见下方[说明](#codebase-memory-项目初始化)
- **graphify / speckit** 装完还需在项目里注册: `graphify install --platform opencode --project` / `specify init <new-project> --integration opencode`
- **codegraph** 装完在项目里执行: `codegraph install --target=opencode --location=local`
- **openspec** 装完在项目里执行: `openspec init --tools opencode`
- **ocr** 装完需要配供应商和模型: `ocr config provider` → `ocr config model` → `ocr llm test`
- **omniroute** 的 API key 等配置在 `/usr/lib/node_modules/omniroute/.env`
- **browser-skill** 还需手动装浏览器扩展并在弹窗里开启连接, 之后新开 opencode 会话才能发现该 skill

### codebase-memory 项目初始化

`install.sh --codebase-memory` 只装全局 CLI 和默认配置, 每个项目还要单独初始化。

1. 前置条件: 项目根有 `AGENTS.md` 或 `.opencode/AGENTS.md`, 否则命令不执行
2. 在项目里跑 `/codebase-memory`
3. 它会做四件事:
   - 在 `.opencode/opencode.json[c]` 加 `mcp.servers.codebase-memory-mcp`(`type: local`, 命令 `codebase-memory-mcp`)
   - 把 `~/.config/opencode/codebase_memory/{agents,plugins,skills}` 同步到项目 `.opencode/`
   - 扫项目文件生成 `.cbmignore`(排除构建产物/依赖缓存/二进制), 并报出保留与排除的数量
   - 等你确认 `.cbmignore` 后才建索引(限内存、降优先级后台跑)

## 项目插件与工具

`superpowers`、`ponytail`、`context-mode`、`graphify` 这类扩展按项目安装: 用 `/project-plugin` 命令把插件写进当前项目的 `.opencode/opencode.json[c]` 的 `plugins` 数组。

不要用 `opencode plugin add` 装项目插件 —— 它写的是全局配置(`~/.config/opencode`)。

|命令|作用|
| --- | --- |
|`/project-plugin`|列出当前项目已装插件与可用别名|
|`/project-plugin install ponytail`|安装插件到当前项目|
|`/project-plugin uninstall ponytail`|从当前项目移除|

|别名|解析为|装到项目的什么|
| --- | --- | --- |
|`ponytail`|`@dietrichgebert/ponytail`|`plugins` 数组|
|`superpowers`|`superpowers@git+https://github.com/obra/superpowers.git`|`plugins` 数组|
|`context-mode`|`context-mode`|`plugins` 数组|
|`graphify`|`graphify local plugin`|`.opencode/plugins/graphify.js` + skill|
|`codegraph`|codegraph 项目工具|`.codegraph/` 索引 + 本地 MCP 配置|
|`openspec`|OpenSpec 项目工具|`.agents/skills/openspec-*` + `openspec/`|
|`speckit`|Spec Kit 项目工具|`.specify/` + `.opencode/commands/speckit.*.md`|

后面三个(`codegraph`/`openspec`/`speckit`)需要先有对应 CLI, 由 `install.sh` 的 `--codegraph`、`--openspec`、`--speckit` 安装; 它们生成的项目数据不进 `plugins` 数组。插件装完若未生效, 运行 `/reload`。

## 项目工具选择

|你的需求| 推荐 | 可选 |
| ------------------ | ------------ | ------------ |
|模型较弱 | superpowers | |
|新项目开发 | speckit + ponytail(lite) | |
|旧项目新功能 | openspec + ponytail(full) | oh-my-opencode-slim |
|旧项目修bug | ponytail(lite) | oh-my-opencode-slim |
|旧项目重构 | ponytail(lite) | oh-my-opencode-slim |
|旧项目优化 | ponytail(full) | oh-my-opencode-slim |

## 工具冲突

|工具| 冲突对象(不可同时安装) |
| ------------------ | ------------ |
|openspec | speckit, superpowers |
|speckit | oh-my-opencode-slim, openspec, superpowers |
|superpowers | oh-my-opencode-slim, speckit, openspec, ponytail |
|codegraph | codebase-memory-mcp |
