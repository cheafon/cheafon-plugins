---
name: daily-summary
description: 生成当日工作总结，包含知识沉淀与导师建议
argument-hint: "[引导方向，如：重点关注 TypeScript]"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Task"]
---

# Daily Summary 命令

生成当日工作总结并提交到 Git 仓库。

## 执行流程

### 1. 检查配置

首先检查配置文件是否存在：

```bash
cat ~/.claude/daily-summary.local.md
```

如果配置文件不存在，提示用户：

> ⚠️ 未找到 Git 仓库配置。请先运行以下命令进行配置：
>
> ```bash
> bash ${CLAUDE_PLUGIN_ROOT}/scripts/setup-git.sh
> ```

然后停止执行，等待用户完成配置。

### 2. 检查已有总结（增量更新）

从配置文件解析仓库路径，检查是否已有今日总结：

```bash
# 解析配置获取仓库路径
GIT_REPO=$(grep "^git_repo:" ~/.claude/daily-summary.local.md | sed 's/^git_repo:[[:space:]]*//' | sed "s|~|$HOME|")

# 检查今日文件是否存在
TODAY=$(date +%Y-%m-%d)
EXISTING_FILE="$GIT_REPO/$TODAY.md"

if [ -f "$EXISTING_FILE" ]; then
    echo "发现已有今日总结，将进行增量更新"
    cat "$EXISTING_FILE"  # 读取已有内容
fi
```

如果已有总结：
- 读取已有内容，传递给 agent 进行**智能增量更新**
- agent 会合并新旧内容，避免重复，保持结构完整

如果没有已有总结：
- 正常生成新的总结

### 3. 解析对话记录

运行解析脚本获取当天的对话数据：

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/scripts/parse-conversations.py
```

脚本输出 JSON 格式的对话数据。

### 4. 检查数据量

查看解析结果：
- 如果 `total_summaries` 和 `total_conversations` 都为 0，提示用户今天没有对话记录
- 如果数据量过大（conversations > 100），考虑分批处理

### 5. 调用 summary-generator Agent

使用 Task 工具调用 `summary-generator` agent：

**Prompt 模板（新建模式）**：

```
请根据以下对话数据生成今日工作总结。

## 对话数据

{conversations_data_json}

## 引导方向

{如果用户提供了引导参数，在这里说明；否则写"无特定引导，全面总结"}

## 输出要求

1. 按照 agent 的输出格式生成 Markdown
2. 将结果写入 /tmp/daily-summary/YYYY-MM-DD.md（使用今天的日期）
3. 确保目录存在：mkdir -p /tmp/daily-summary
```

**Prompt 模板（增量更新模式）**：

```
请对今日工作总结进行增量更新。

## 已有总结内容

{existing_summary_content}

## 新增对话数据

{conversations_data_json}

## 引导方向

{如果用户提供了引导参数，在这里说明；否则写"无特定引导，全面总结"}

## 更新要求

1. **智能合并**：将新内容与已有内容合并，避免重复
2. **保持结构**：保持 Markdown 结构不变
3. **累积知识**：新学到的知识追加到对应章节
4. **更新导师点评**：根据全天工作重新生成导师点评和下一步行动
5. 将结果写入 /tmp/daily-summary/YYYY-MM-DD.md（覆盖）
```

### 6. 提交到 Git

总结生成后，运行提交脚本：

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/git-commit.sh /tmp/daily-summary/YYYY-MM-DD.md
```

### 7. 清理并报告

- 显示生成的总结内容（或摘要）
- 报告提交状态
- 可选：清理临时文件

## 参数处理

- **无参数**：全面总结当天所有对话
- **有参数**：作为引导方向传递给 agent，聚焦总结

示例：
- `/daily-summary` → 全面总结
- `/daily-summary TypeScript 类型系统` → 聚焦 TypeScript 相关内容
- `/daily-summary 今天遇到的 bug` → 聚焦问题与解决

## 错误处理

| 情况 | 处理方式 |
|------|---------|
| 配置文件不存在 | 提示运行 setup-git.sh |
| 无对话记录 | 提示今天没有对话，无需总结 |
| Git 推送失败 | 显示错误，建议检查网络或权限 |
| Agent 执行失败 | 显示错误，建议重试 |

## 输出示例

```
✅ 配置检查通过
📖 正在解析对话记录...
   - 发现 5 个项目的对话
   - 共 23 条摘要，47 条对话

🤖 正在生成总结...
   [调用 summary-generator agent]

📝 总结已生成: /tmp/daily-summary/2025-12-24.md

📤 正在提交到 Git...
   - 仓库: ~/worklogs
   - 分支: main
   ✅ 推送成功!

🎉 完成！今日总结已保存。
```
