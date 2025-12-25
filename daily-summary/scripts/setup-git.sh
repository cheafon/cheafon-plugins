#!/bin/bash
#
# setup-git.sh - 配置工作日志的 Git 仓库
#
# 用法: ./setup-git.sh
#
# 此脚本会:
# 1. 引导用户输入 Git 仓库路径
# 2. 测试仓库的推送权限
# 3. 保存配置到 ~/.claude/daily-summary.local.md

set -e

CONFIG_FILE="$HOME/.claude/daily-summary.local.md"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 注意：所有日志输出都使用 >&2 重定向到 stderr，避免污染函数返回值
echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# 检查是否已有配置
check_existing_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        echo_warn "发现已有配置文件: $CONFIG_FILE"
        read -p "是否覆盖? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo_info "保留现有配置，退出"
            exit 0
        fi
    fi
}

# 获取用户输入
get_repo_path() {
    echo "" >&2
    echo_info "请输入工作日志 Git 仓库的本地路径"
    echo_info "示例: ~/worklogs 或 /home/user/worklogs"
    echo "" >&2
    read -p "仓库路径: " repo_path

    # 展开 ~ 符号
    repo_path="${repo_path/#\~/$HOME}"

    # 检查路径是否存在
    if [[ ! -d "$repo_path" ]]; then
        echo_warn "目录不存在: $repo_path"
        read -p "是否创建? (Y/n): " create_dir
        if [[ "$create_dir" =~ ^[Nn]$ ]]; then
            echo_error "需要有效的目录路径"
            exit 1
        fi
        mkdir -p "$repo_path"
        echo_success "已创建目录: $repo_path"
    fi

    # 检查是否是 Git 仓库
    if [[ ! -d "$repo_path/.git" ]]; then
        echo_warn "目录不是 Git 仓库: $repo_path"
        read -p "是否初始化 Git 仓库? (Y/n): " init_git
        if [[ "$init_git" =~ ^[Nn]$ ]]; then
            echo_error "需要 Git 仓库"
            exit 1
        fi
        (cd "$repo_path" && git init)
        echo_success "已初始化 Git 仓库"
    fi

    # 只有这一行输出到 stdout 作为返回值
    echo "$repo_path"
}

# 获取远程仓库信息
get_remote_info() {
    local repo_path="$1"
    cd "$repo_path"

    # 列出现有远程
    local remotes=$(git remote -v 2>/dev/null | grep push | awk '{print $1}' | sort -u)

    if [[ -z "$remotes" ]]; then
        echo_warn "未找到远程仓库"
        echo_info "请输入远程仓库 URL (例如: git@github.com:user/worklogs.git)"
        read -p "远程 URL: " remote_url

        if [[ -z "$remote_url" ]]; then
            echo_error "需要远程仓库 URL"
            exit 1
        fi

        git remote add origin "$remote_url"
        echo_success "已添加远程仓库: origin -> $remote_url"
        echo "origin"
    else
        echo_info "发现远程仓库:" >&2
        git remote -v | grep push >&2
        echo "" >&2

        if [[ $(echo "$remotes" | wc -l) -eq 1 ]]; then
            echo "$remotes"
        else
            read -p "请选择要使用的远程 (默认 origin): " selected_remote
            echo "${selected_remote:-origin}"
        fi
    fi
}

# 获取分支信息
get_branch_info() {
    local repo_path="$1"
    cd "$repo_path"

    # 获取当前分支
    local current_branch=$(git branch --show-current 2>/dev/null)

    if [[ -z "$current_branch" ]]; then
        # 可能是新仓库，还没有提交
        echo_info "新仓库，将使用默认分支 'main'"
        echo "main"
    else
        echo_info "当前分支: $current_branch"
        read -p "使用此分支? (Y/n): " use_current
        if [[ "$use_current" =~ ^[Nn]$ ]]; then
            read -p "请输入分支名: " branch_name
            echo "${branch_name:-main}"
        else
            echo "$current_branch"
        fi
    fi
}

# 测试 Git 推送权限
test_git_push() {
    local repo_path="$1"
    local remote="$2"
    local branch="$3"

    echo "" >&2
    echo_info "正在测试 Git 推送权限..."

    cd "$repo_path"

    # 创建测试文件
    local test_file=".daily-summary-test"
    echo "# Test file - $(date)" > "$test_file"

    # 尝试添加
    git add "$test_file" 2>/dev/null || true

    # 检查是否有变更需要提交
    if ! git diff --cached --quiet 2>/dev/null; then
        # 有变更，尝试提交
        git commit -m "test: daily-summary setup verification" >/dev/null 2>&1 || {
            echo_error "Git commit 失败"
            rm -f "$test_file"
            return 1
        }

        # 测试推送
        echo_info "尝试推送到 $remote/$branch ..."

        if git push -u "$remote" "$branch" 2>&1; then
            echo_success "推送测试成功!"

            # 清理测试提交 (可选)
            read -p "是否删除测试提交? (Y/n): " cleanup
            if [[ ! "$cleanup" =~ ^[Nn]$ ]]; then
                git rm "$test_file" >/dev/null 2>&1
                git commit -m "chore: cleanup setup test" >/dev/null 2>&1
                git push >/dev/null 2>&1
                echo_success "已清理测试文件"
            fi

            return 0
        else
            echo_error "推送失败! 请检查:"
            echo "  1. SSH 密钥是否已配置" >&2
            echo "  2. 远程仓库 URL 是否正确" >&2
            echo "  3. 是否有推送权限" >&2

            # 回滚测试提交
            git reset --soft HEAD~1 >/dev/null 2>&1
            rm -f "$test_file"
            return 1
        fi
    else
        echo_info "没有变更需要提交，跳过推送测试"
        rm -f "$test_file"
        return 0
    fi
}

# 保存配置
save_config() {
    local repo_path="$1"
    local remote="$2"
    local branch="$3"

    mkdir -p "$(dirname "$CONFIG_FILE")"

    cat > "$CONFIG_FILE" << EOF
---
git_repo: $repo_path
git_remote: $remote
git_branch: $branch
---

# Daily Summary 配置

此文件存储工作日志的 Git 仓库配置。

## 配置说明

- **git_repo**: 本地 Git 仓库路径
- **git_remote**: 远程仓库名称 (通常是 origin)
- **git_branch**: 推送的分支名称

## 重新配置

如需修改配置，可以:
1. 直接编辑此文件的 YAML 部分
2. 运行 \`\${CLAUDE_PLUGIN_ROOT}/scripts/setup-git.sh\` 重新配置
EOF

    echo_success "配置已保存到: $CONFIG_FILE"
}

# 主流程
main() {
    echo ""
    echo "=========================================="
    echo "   Daily Summary - Git 仓库配置向导"
    echo "=========================================="
    echo ""

    check_existing_config

    # 获取仓库路径
    repo_path=$(get_repo_path)
    echo_info "使用仓库: $repo_path"

    # 获取远程信息
    remote=$(get_remote_info "$repo_path")
    echo_info "使用远程: $remote"

    # 获取分支信息
    branch=$(get_branch_info "$repo_path")
    echo_info "使用分支: $branch"

    # 测试推送权限
    if test_git_push "$repo_path" "$remote" "$branch"; then
        # 保存配置
        save_config "$repo_path" "$remote" "$branch"

        echo ""
        echo "=========================================="
        echo_success "配置完成!"
        echo ""
        echo "现在可以使用 /daily-summary 命令生成工作日志了"
        echo "=========================================="
    else
        echo ""
        echo_error "配置未完成，请解决推送问题后重试"
        exit 1
    fi
}

main "$@"
