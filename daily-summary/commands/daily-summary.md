---
name: daily-summary
description: 生成当天 Claude 对话的智能总结，包含助理视角和导师视角的双重分析
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "TodoWrite"]
---

# Daily Summary Command

执行每日对话总结流程。读取当天所有 Claude 对话，生成双视角总结，并自动提交到 Git 仓库。

## 执行步骤

### Step 1: 读取配置

首先读取 daily-summary 插件目录下的配置文件 `config.local.md`：

```bash
# 配置文件位置：daily-summary 插件根目录下
# ${CLAUDE_PLUGIN_ROOT} 会自动替换为当前插件（daily-summary）的安装路径
cat ${CLAUDE_PLUGIN_ROOT}/config.local.md
```

从 YAML frontmatter 中提取：
- `conversation_dir`: 对话目录（默认 `~/.claude/projects`）
- `output_repo`: 输出仓库目录（必填）

**如果配置文件不存在或 `output_repo` 未设置，永远不要继续执行！提示用户先在插件目录创建 `config.local.md` 配置文件或者询问用户是否需要帮助配置。**

### Step 2: 扫描当天对话

获取今天的日期（格式 YYYY-MM-DD），然后：

1. 列出 `conversation_dir` 下所有项目目录
2. 对每个项目目录，使用 `find` 或 `ls -la` 查找今天修改的 `.jsonl` 文件
3. 收集所有今天的对话文件路径

判断文件是否为当天的方法：
```bash
# 查找今天修改的文件
find ~/.claude/projects -name "*.jsonl" -mtime 0
```

### Step 3: 读取对话内容

对于找到的每个 `.jsonl` 文件：

1. 读取文件内容（每行是一个 JSON 对象）
2. 筛选 `type: "user"` 和 `type: "assistant"` 的消息
3. 提取 `message.content` 字段作为对话内容
4. 记录来源项目（从目录路径提取）

**对话 JSONL 结构**：
```json
{"type":"user","message":{"role":"user","content":"用户消息"},...}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"回复内容"}]},...}
```

**注意**：
- 文件可能较大，优先读取最近的对话（文件末尾）
- assistant 的 content 是数组，需要提取 `text` 字段
- 忽略 `type` 为其他值的行（如 queue-operation）

### Step 4: 生成总结

基于收集的对话内容，生成 Markdown 格式的总结：

```markdown
# 每日总结 - YYYY-MM-DD

## 助理视角

根据今天的对话，从助理角度总结：

### [主题名称 1]
- **学到的知识**：...
- **遇到的问题**：...
- **解决方法**：...

### [主题名称 2]
...

## 导师视角

从导师角度提供建议：

### 后续指导
- [具体建议 1]
- [具体建议 2]

### 重点关注
- [需要重点关注的事项]
- [值得深入学习的方向]

---
*生成时间：YYYY-MM-DD HH:MM:SS*
*涵盖项目：project1, project2, ...*
```

**总结要点**：
- 助理视角：客观记录今天学到什么、遇到什么问题、如何解决
- 导师视角：站在指导者角度，提出职业发展建议和重点关注事项
- 按主题分类，而非按项目分类
- 提取有价值的知识点，过滤掉琐碎内容

### Step 5: 增量更新

检查输出仓库中是否已存在当天的总结文件：

```bash
# 检查文件是否存在
ls output_repo/daily-summary-YYYY-MM-DD.md
```

**如果文件已存在**：
1. 读取现有文件内容
2. 对比新总结和已有内容
3. 智能合并：
   - 新增主题：追加到对应 section
   - 已有主题的新内容：追加到该主题下
   - 需要更新的内容：直接更新
   - 保留原有内容的完整性
4. 更新生成时间戳

**如果文件不存在**：
- 直接创建新文件

### Step 6: 写入并提交

1. 将总结内容写入 `output_repo/daily-summary-YYYY-MM-DD.md`
2. 在输出仓库目录执行 Git 操作：

```bash
cd output_repo
git add daily-summary-YYYY-MM-DD.md
git commit -m "docs: 更新 YYYY-MM-DD 每日总结"
git push
```

3. 输出执行结果：成功或失败原因

## 执行流程总结

使用 TodoWrite 跟踪以下步骤：
1. 读取配置文件
2. 扫描当天对话文件
3. 读取并解析对话内容
4. 生成双视角总结
5. 检查并增量更新已有文件
6. 写入总结文件
7. Git 提交并推送

## 错误处理

- 配置文件缺失：提示用户创建
- 无当天对话：提示无内容可总结
- Git 操作失败：显示错误信息，保留本地文件
- 对话文件过大：只读取最近 N 条对话

## 示例输出

```
[开始每日总结流程]
✓ 读取配置：output_repo = ~/Documents/daily-summaries
✓ 扫描到 5 个今日对话文件
✓ 解析对话内容完成
✓ 生成总结：3 个主题
✓ 写入文件：daily-summary-2025-12-26.md
✓ Git 提交并推送成功

总结已生成：~/Documents/daily-summaries/daily-summary-2025-12-26.md
```
