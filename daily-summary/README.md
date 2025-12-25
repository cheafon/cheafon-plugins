# Daily Summary - AI 每日工作总结助理

一个 Claude Code 插件，自动总结当日对话记录，生成包含知识沉淀与导师建议的高质量工作总结。

## 功能特点

- **自动读取对话** - 直接从 `~/.claude/projects` 读取 JSONL 对话文件
- **双视角输出** - 智能助理（回顾）+ 成长导师（前瞻）
- **知识导向** - 按知识主题组织，而非机械地按项目/时间分类
- **增量更新** - 支持一天内多次运行，智能合并内容
- **Git 集成** - 自动提交并推送到配置的 Git 仓库

## 安装

插件已包含在 `cheafon-plugins` marketplace 中，启用后自动可用。

## 首次使用

### 1. 创建配置文件

创建 `~/.claude/daily-summary.local.md`：

```yaml
---
git_repo: ~/worklogs
git_remote: origin
git_branch: main
---

# Daily Summary 配置

工作总结仓库配置。
```

### 2. 准备 Git 仓库

确保 `git_repo` 指向的目录是一个已初始化的 Git 仓库：

```bash
mkdir -p ~/worklogs
cd ~/worklogs
git init
git remote add origin <your-remote-url>
```

### 3. 使用命令

```
/daily-summary                        # 全面总结当天对话
/daily-summary TypeScript 类型系统    # 聚焦特定主题
/daily-summary 今天遇到的 bug         # 聚焦问题与解决
```

## 输出格式

```markdown
# 每日总结 - 2025-12-25

> 一句话总结今天的主题/收获

## 今日学习收获
### [主题1]
- 要点描述
- 关键代码/命令示例

## 问题与解决
### [问题简述]
- **问题**：具体描述
- **解决**：解决方案
- **启发**：从中学到什么

## 关键洞察
- 值得长期记住的知识点或最佳实践

## 导师点评
对今天工作的整体评价，语气鼓励但客观

## 下一步行动
1. 具体可执行的下一步任务
2. 需要深入学习的领域
```

## 目录结构

```
daily-summary/
├── .claude-plugin/
│   └── plugin.json           # 插件清单
├── commands/
│   └── daily-summary.md      # 主命令
├── agents/
│   └── summary-generator.md  # 总结生成 Agent
└── README.md
```

## 配置说明

配置存储在 `~/.claude/daily-summary.local.md`：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| `git_repo` | 工作日志 Git 仓库路径 | 必填 |
| `git_remote` | Git 远程名称 | `origin` |
| `git_branch` | Git 分支名称 | `main` |

## 工作原理

```
/daily-summary [引导]
       │
       ▼
Command: 读取配置 (~/.claude/daily-summary.local.md)
       │
       ▼
Command: 检查已有总结（增量更新模式）
       │
       ▼
Task: 调用 summary-generator agent
       │
       ▼
Agent: Glob 查找 ~/.claude/projects/**/*.jsonl
Agent: Read 读取对话内容
Agent: 生成总结
Agent: Write 写入目标文件
       │
       ▼
Command: Bash 执行 git add/commit/push
       │
       ▼
完成
```

## 常见问题

### Q: 提示"配置文件不存在"？
创建 `~/.claude/daily-summary.local.md` 配置文件，参考上方配置说明。

### Q: Git 每次都要输入密码？
配置 credential helper：
```bash
git config --global credential.helper store
```

### Q: 如何修改 Git 仓库配置？
直接编辑 `~/.claude/daily-summary.local.md`。

### Q: 一天运行多次会重复吗？
不会。插件支持增量更新，会智能合并已有内容，避免重复。

## 版本历史

- **1.1.0** - 重构版本
  - 移除外部脚本依赖
  - Claude 直接读取 JSONL 文件
  - Agent 直接写入目标仓库
  - 简化工作流程

- **1.0.0** - 初始版本
  - `/daily-summary` 命令
  - 渐进式总结 Agent
  - Git 自动提交

## 许可证

MIT
