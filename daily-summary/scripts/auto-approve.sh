#!/bin/bash
# 自动批准 daily-summary 插件所需的权限请求
#
# 只批准安全的操作：
# - 读取 ~/.claude/projects 目录（对话文件）
# - 读取 output_repo 目录（总结文件）
# - 在 output_repo 目录执行 git 操作

set -e

# 读取权限请求输入
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# 读取配置获取允许的目录
config_file="${CLAUDE_PLUGIN_ROOT}/config.local.md"

# 默认允许的目录
conversation_dir="$HOME/.claude/projects"
output_repo=""

if [ -f "$config_file" ]; then
  # 从配置读取
  conv_dir=$(sed -n '/^---$/,/^---$/p' "$config_file" | grep -E '^conversation_dir:' | sed 's/^conversation_dir:[[:space:]]*//' | sed 's/[[:space:]]*#.*//')
  out_repo=$(sed -n '/^---$/,/^---$/p' "$config_file" | grep -E '^output_repo:' | sed 's/^output_repo:[[:space:]]*//' | sed 's/[[:space:]]*#.*//')

  if [ -n "$conv_dir" ]; then
    conversation_dir="${conv_dir/#\~/$HOME}"
  fi
  if [ -n "$out_repo" ]; then
    output_repo="${out_repo/#\~/$HOME}"
  fi
fi

# 根据工具类型检查
case "$tool_name" in
  Bash)
    command=$(echo "$input" | jq -r '.tool_input.command // empty')

    # 允许的命令模式：
    # - find/ls 在 conversation_dir 或 output_repo
    # - git 操作在 output_repo
    # - date 命令
    if echo "$command" | grep -qE "^(find|ls).*\.claude/projects" || \
       echo "$command" | grep -qE "^(find|ls).*$conversation_dir" || \
       echo "$command" | grep -qE "^date" || \
       ( [ -n "$output_repo" ] && echo "$command" | grep -qE "(cd.*$output_repo|git)" ); then
      echo '{"decision": "approve"}'
      exit 0
    fi
    ;;

  Read)
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
    file_path="${file_path/#\~/$HOME}"

    # 允许读取 conversation_dir 和 output_repo
    if [[ "$file_path" == *".claude/projects"* ]] || \
       [[ "$file_path" == "$conversation_dir"* ]] || \
       ( [ -n "$output_repo" ] && [[ "$file_path" == "$output_repo"* ]] ) || \
       [[ "$file_path" == *"config.local.md"* ]]; then
      echo '{"decision": "approve"}'
      exit 0
    fi
    ;;

  Glob|Grep)
    path=$(echo "$input" | jq -r '.tool_input.path // empty')
    path="${path/#\~/$HOME}"

    # 允许在 conversation_dir 和 output_repo 搜索
    if [[ "$path" == *".claude/projects"* ]] || \
       [[ "$path" == "$conversation_dir"* ]] || \
       ( [ -n "$output_repo" ] && [[ "$path" == "$output_repo"* ]] ); then
      echo '{"decision": "approve"}'
      exit 0
    fi
    ;;
esac

# 不匹配的请求，不做决策（让用户手动确认）
exit 0
