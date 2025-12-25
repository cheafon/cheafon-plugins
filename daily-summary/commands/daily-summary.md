---
name: daily-summary
description: 生成当日工作总结，包含知识沉淀与导师建议
argument-hint: "[引导方向，如：重点关注 TypeScript]"
allowed-tools: ["Read", "Bash", "Task"]
---

# Daily Summary 命令

生成当日工作总结并提交到 Git 仓库。

## 执行流程

你必须按顺序执行以下步骤。每一步都要实际调用工具，不要跳过。

### Step 1: 读取配置

使用 Read 工具读取配置文件：

```
Read: ~/.claude/daily-summary.local.md
```

配置文件格式：
```yaml
---
git_repo: ~/path/to/worklogs
git_remote: origin
git_branch: main
---
```

**如果配置文件不存在**，告诉用户需要先创建配置：

> 请创建配置文件 `~/.claude/daily-summary.local.md`：
> ```yaml
> ---
> git_repo: ~/worklogs
> git_remote: origin
> git_branch: main
> ---
> ```

然后停止执行。

### Step 2: 准备参数

从配置中提取：
- `GIT_REPO`: git_repo 的值（展开 `~` 为完整路径）
- `GIT_REMOTE`: git_remote 的值（默认 `origin`）
- `GIT_BRANCH`: git_branch 的值（默认 `main`）

计算日期和目标文件：
- `TODAY`: 今天的日期 (YYYY-MM-DD 格式)
- `TARGET_FILE`: `$GIT_REPO/$TODAY.md`

### Step 3: 检查已有总结

使用 Read 工具检查 `TARGET_FILE` 是否存在：

```
Read: $TARGET_FILE
```

- 如果文件存在，记录内容作为 `EXISTING_CONTENT`（增量更新模式）
- 如果文件不存在，`EXISTING_CONTENT` 为空（新建模式）

### Step 4: 调用 Agent 生成总结

使用 Task 工具调用 `summary-generator` agent。

**Prompt 模板**（将变量替换为实际值）：

```
请生成今日工作总结。

## 参数

- target_file: [TARGET_FILE 的完整路径]
- target_date: [TODAY]
- existing_content: [EXISTING_CONTENT 或 "无"]
- guidance: [用户提供的引导参数，或 "无特定引导"]

## 要求

1. 使用 Glob 查找 ~/.claude/projects/**/*.jsonl
2. 使用 Read 读取 JSONL 文件，筛选今天的对话
3. 生成总结内容
4. **使用 Write 工具写入 target_file**

完成后确认文件已写入。
```

等待 agent 完成。

### Step 5: Git 提交和推送

Agent 完成后，使用 Bash 工具执行 git 操作：

```bash
cd $GIT_REPO && \
git add $TODAY.md && \
git diff --cached --quiet || git commit -m "docs: 工作日志 $TODAY" && \
git push $GIT_REMOTE $GIT_BRANCH
```

说明：
- `git diff --cached --quiet` 检查是否有变更
- 如果有变更才执行 commit
- 自动推送到远程

### Step 6: 报告结果

输出执行结果：

**成功时**：
```
✅ 每日总结完成

| 项目     | 状态                   |
|----------|------------------------|
| 总结生成 | ✓ 成功                 |
| Git 提交 | ✓ 已提交               |
| Git 推送 | ✓ 已推送到 $GIT_REMOTE/$GIT_BRANCH |

文件路径: $TARGET_FILE
```

**失败时**：
报告具体哪一步失败，以及错误信息。

## 参数说明

- **无参数**：全面总结当天所有对话
- **有参数**：作为引导方向，聚焦特定主题

示例：
- `/daily-summary` → 全面总结
- `/daily-summary TypeScript 类型系统` → 聚焦 TypeScript 相关内容

## 错误处理

| 情况 | 处理方式 |
|------|---------|
| 配置文件不存在 | 提示创建配置文件 |
| 无对话记录 | 提示今天没有对话 |
| Agent 执行失败 | 显示错误，建议重试 |
| Git 推送失败 | 显示错误，建议检查网络 |
