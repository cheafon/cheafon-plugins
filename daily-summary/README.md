# Daily Summary 每日对话总结

自动读取当天 Claude Code 对话记录，生成双视角总结并自动提交到 Git 仓库。

## 目录结构
DEV-MARK:这个文件夹

## 功能

- **智能读取**：自动扫描 `~/.claude/projects`（可以自定义，我的是linux系统，默认的目录就是这个） 下当天的所有对话
- **双视角总结**：
  - 助理视角：学到的知识、遇到的问题、解决方法（按主题分类）
  - 导师视角：后续指导建议、重点关注事项
- **增量更新**：如果当天已有总结，智能合并新内容
- **自动提交**：写入完成后自动 commit 并 push 到远程仓库

## 配置

在插件目录下创建 `config.local.md` 配置文件：

```bash
# 复制模板
cp config.local.md.example config.local.md

# 编辑配置
vim config.local.md
```

配置内容：
```markdown
---
conversation_dir: ~/.claude/projects  这个是你的claude的对话日志文件夹，linux默认是在`~/.claude/projects`
output_repo: ~/project/daily-summaries  你的保存日志的仓库，目前的逻辑是把总结报告直接提交到本地的仓库然后push，所以你需要有一个已经配置了remote的本地仓库，只需要提供这个目录即可
---
```

> 注意：`config.local.md` 已在 `.gitignore` 中忽略，不会被提交到 git

### 配置项说明

| 字段 | 说明 | 默认值 |
|------|------|--------|
| `conversation_dir` | Claude 对话存储目录 | `~/.claude/projects` |
| `output_repo` | 总结文档输出的 Git 仓库目录 | 必填 |

## 使用方法

```bash
# 在任意项目中执行
/daily-summary
```

## 输出格式

生成的文件命名：`daily-summary-YYYY-MM-DD.md`

```markdown
# 每日总结 - YYYY-MM-DD

## 助理视角

### 主题一：xxx
- 学到的知识点
- 遇到的问题
- 解决方法

### 主题二：xxx
...

## 导师视角

### 后续指导
- 建议 1
- 建议 2

### 重点关注
- 关注点 1
- 关注点 2
```

## 安装

```bash
# 添加到 Claude Code 插件目录
claude plugin install cheafon-plugins/daily-summary
```
