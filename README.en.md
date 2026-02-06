# OpenCode Config - OpenAgents Control

OpenAgents Control (OAC) is a configuration system designed to control AI agent behavior, helping teams establish reproducible and controllable AI development workflows. Through pattern definition, context management, and fine-grained permission controls, teams can enforce unified AI development standards.

## Core Features

### 🤖 Intelligent Agent Framework

The system provides a multi-layered agent architecture to meet diverse development scenarios:

- **OpenAgent** - General-purpose agent entry, ideal for daily development tasks  
- **OpenCoder** - Professional development agent focused on production-grade code development  
- **BuildAgent** - Build agent handling project compilation and deployment  
- **CoderAgent** - Coding agent focused on specific code implementation  
- **TestEngineer** - Testing agent responsible for writing test cases  
- **CodeReviewer** - Code review agent ensuring code quality  

### 📚 Context System (MVI Principle)

A context management system based on the **Minimal Viable Information (MVI)** principle, ensuring agents receive only essential information to improve response efficiency and reduce token consumption.

**Core Advantages:**
- Minimized information transfer to prevent context bloat  
- Functionally structured organization  
- Efficient navigation and reference mechanisms  
- Automated knowledge extraction and organization  

**Organization Modes:**
- **Function-Oriented** - Context tailored to specific repositories  
- **Concern-Oriented** - Context aligned with development workflows  
- **Hybrid Mode** - Combines both advantages  

### ⚡ Command System

Built-in productivity commands simplify routine development tasks:

| Command | Function |
|---------|----------|
| `/add-context` | Add and manage project context |
| `/analyze-patterns` | Analyze code patterns |
| `/clean` | Clean up code quality |
| `/commit` | Generate standardized commit messages |
| `/context` | Context management operations |
| `/optimize` | Perform code optimization analysis |
| `/test` | Run test pipelines |
| `/validate-repo` | Validate repository configuration |

### 🛠️ Professional Skill Modules

#### Document Processing
- **PDF Skill** - Create, edit, extract, and process PDF forms  
- **DOCX Skill** - Create and edit Word documents  
- **PPTX Skill** - Create PowerPoint presentations  
- **XLSX Skill** - Process Excel spreadsheets  

#### Development Tools
- **Context7** - Retrieve latest documentation and API references  
- **MCP Builder** - MCP server development framework  
- **Skill Creator** - Tool for creating custom skills  
- **Task Management** - Task tracking and management  

### 🔧 Sub-Agent System

The system supports automated delegation to specialized sub-agents:

| Sub-Agent | Purpose |
|-----------|---------|
| ContextScout | Discover and analyze project context |
| ExternalScout | Retrieve external library documentation |
| TaskManager | Decompose and manage tasks |
| FrontendSpecialist | Frontend design and implementation |
| DevOpsSpecialist | Operations and deployment |
| DocWriter | Document authoring |

## Quick Start

### 1. Installation

```bash
# Clone the repository
git clone https://gitee.com/keeferwu/opencode-config.git
cd opencode-config

# Run the installation script
./install.sh
```

### 2. Configure Agents

Select the appropriate agent based on your needs to begin development. The system automatically loads relevant context and configurations.

### 3. Use the Context System

Add pattern definitions for your project:

```bash
# Add project context
/context add
```

### 4. Run Commands

Use built-in commands to enhance development efficiency:

```bash
# Clean code
/clean

# Optimize code
/optimize

# Validate repository configuration
/validate-repo
```

## Project Structure

```
opencode-config/
├── .opencode/                    # Core configuration
│   ├── agent/                     # Agent definitions
│   │   ├── core/                 # Core agents
│   │   └── subagents/            # Sub-agents
│   │       ├── code/              # Code-related
│   │       ├── core/              # System core
│   │       ├── development/       # Development aids
│   │       └── system-builder/    # System builder
│   ├── command/                   # Command definitions
│   ├── context/                   # Context system
│   │   ├── core/                 # Core context
│   │   ├── development/          # Development context
│   │   ├── openagents-repo/      # Agent repository context
│   │   ├── project-intelligence/ # Project intelligence
│   │   └── ui/                    # UI context
│   └── skill/                     # Skill modules
│       ├── context7/              # Document retrieval
│       ├── task-management/       # Task management
│       └── ...
├── global/                        # Global configuration
│   ├── agents/                    # Global agents
│   ├── commands/                  # Global commands
│   ├── opencode.json/            # Global configuration
│   ├── rules/                     # Global rules
│   └── skills/                    # Global skills
│       ├── docx/                  # DOCX processing
│       ├── pdf/                   # PDF processing
│       ├── pptx/                  # PPTX processing
│       ├── mcp-builder/           # MCP development
│       └── ...
└── install.sh                     # Installation script
```

## Use Cases

### ✅ Recommended For

- Need for unified AI development standards and workflows  
- Team collaboration requiring shared context  
- Need for fine-grained control over AI agent behavior  
- Handling multiple document formats  
- Building custom AI workflows  

### ⚠️ Not Required For

- Simple single-task scripts  
- Projects with no need for context management  

## Workflow Examples

### Basic Development Workflow

```
1. Initialize project context
   → /add-context
   
2. Delegate tasks to agents
   → Use OpenAgent or OpenCoder
   
3. Code implementation
   → CoderAgent automatically delegates sub-agents
   
4. Testing and validation
   → TestEngineer writes tests
   
5. Code review
   → CodeReviewer checks quality
   
6. Commit code
   → /commit generates standardized commit messages
```

### Team Collaboration Mode

```
Team Lead:
1. Add project standards and patterns
   → /add-context to define team norms
   
2. Commit to repository
   → All members automatically inherit standards

Team Members:
1. Clone the project
   → Automatically receive context and standards
   
2. Begin development
   → Use unified agent configurations
```

## Advanced Configuration

### Model Configuration (Optional)

```yaml
model: anthropic/claude-sonnet-4-5  # Modify as needed
```

### Custom Context

The system supports adding and customizing context based on project requirements:

- **Project Intelligence** - Business domain, tech stack, decision logs  
- **Development Standards** - Code style, security requirements, testing criteria  
- **Workflows** - Task decomposition, code review, release procedures  

## Documentation Resources

- **Context System Guide** - Learn about MVI principles and context organization  
- **Agent Development Guide** - Create and configure custom agents  
- **Skill Development Guide** - Build custom skill modules  
- **Command Reference** - Complete list of commands and usage instructions  

## License

This project is licensed under the terms specified in the LICENSE file within the repository.

## Contribution Guidelines

Contributions of code, documentation, and feedback are welcome. Please refer to the contribution guide in the project for detailed procedures.

## Contact

- Project URL: https://gitee.com/keeferwu/opencode-config  
- Issues & Feedback: Submit via Gitee Issues