#!/bin/bash
  # 验证 Write/Edit 工具只能写入配置的 output_repo 目录或 config.local.md 文件
  #
  # 允许写入的路径：
  # 1. 配置文件中 output_repo 指定的目录及其子目录
  # 2. 插件根目录下的 config.local.md 文件（用户配置文件）
  # 其他路径一律阻止

  set -e

  # 读取工具输入
  input=$(cat)
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

  # 如果没有 file_path，跳过检查
  if [ -z "$file_path" ]; then
    exit 0
  fi

  # 展开 ~ 为 $HOME
  file_path="${file_path/#\~/$HOME}"

  # 获取绝对路径
  if [[ "$file_path" != /* ]]; then
    cwd=$(echo "$input" | jq -r '.cwd // empty')
    if [ -n "$cwd" ]; then
      file_path="$cwd/$file_path"
    fi
  fi

  # 规范化路径（解析 .. 和 .）
  file_path=$(realpath -m "$file_path" 2>/dev/null || echo "$file_path")

  # 允许写入插件根目录下的 config.local.md 文件
  config_local_md="${CLAUDE_PLUGIN_ROOT}/config.local.md"
  config_local_md=$(realpath -m "$config_local_md" 2>/dev/null || echo "$config_local_md")

  if [[ "$file_path" == "$config_local_md" ]]; then
    # 允许写入 config.local.md
    exit 0
  fi

  # 读取配置文件获取 output_repo
  config_file="${CLAUDE_PLUGIN_ROOT}/config.local.md"

  if [ ! -f "$config_file" ]; then
    echo "错误：配置文件不存在: $config_file" >&2
    echo "请先创建配置文件，参考 config.local.md.example" >&2
    exit 2
  fi

  # 从 YAML frontmatter 提取 output_repo
  output_repo=$(sed -n '/^---$/,/^---$/p' "$config_file" | grep -E '^output_repo:' | sed 's/^output_repo:[[:space:]]*//' | sed 's/[[:space:]]*#.*//')

  if [ -z "$output_repo" ]; then
    echo "错误：配置文件中未设置 output_repo" >&2
    exit 2
  fi

  # 展开 ~ 为 $HOME
  output_repo="${output_repo/#\~/$HOME}"

  # 规范化 output_repo 路径
  output_repo=$(realpath -m "$output_repo" 2>/dev/null || echo "$output_repo")

  # 检查文件路径是否在允许的目录下
  if [[ "$file_path" == "$output_repo"* ]]; then
    # 允许写入 output_repo 目录
    exit 0
  else
    echo "禁止写入: $file_path" >&2
    echo "此插件只允许写入:" >&2
    echo "  1. 配置文件: $config_local_md" >&2
    echo "  2. 输出目录: $output_repo" >&2
    exit 2
  fi