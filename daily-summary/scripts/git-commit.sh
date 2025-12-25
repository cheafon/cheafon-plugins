#!/bin/bash
#
# git-commit.sh - 将工作日志提交到 Git 仓库
#
# 用法: ./git-commit.sh <markdown_file>
#
# 此脚本会:
# 1. 读取配置文件获取仓库信息
# 2. 复制工作日志到仓库
# 3. 执行 git add, commit, push

set -e

CONFIG_FILE="$HOME/.claude/daily-summary.local.md"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 带重试的 git push
git_push_with_retry() {
    local remote="$1"
    local branch="$2"
    local max_retries=3
    local retry_delay=3
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        echo_info "推送到远程... (尝试 $attempt/$max_retries)"

        if git push "$remote" "$branch" 2>&1; then
            echo_success "推送成功!"
            return 0
        fi

        if [[ $attempt -lt $max_retries ]]; then
            echo_warn "推送失败，${retry_delay}秒后重试..."
            sleep $retry_delay
            # 指数退避：每次重试等待时间翻倍
            retry_delay=$((retry_delay * 2))
        fi

        attempt=$((attempt + 1))
    done

    echo_error "推送失败，已重试 $max_retries 次"
    return 1
}

# 解析配置文件中的 YAML frontmatter
parse_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo_error "配置文件不存在: $CONFIG_FILE"
        echo_error "请先运行 setup-git.sh 进行配置"
        exit 1
    fi

    # 提取 YAML frontmatter (在 --- 之间的内容)
    local yaml_content=$(sed -n '/^---$/,/^---$/p' "$CONFIG_FILE" | sed '1d;$d')

    # 解析各字段
    GIT_REPO=$(echo "$yaml_content" | grep "^git_repo:" | sed 's/^git_repo:[[:space:]]*//')
    GIT_REMOTE=$(echo "$yaml_content" | grep "^git_remote:" | sed 's/^git_remote:[[:space:]]*//')
    GIT_BRANCH=$(echo "$yaml_content" | grep "^git_branch:" | sed 's/^git_branch:[[:space:]]*//')

    # 展开 ~ 符号
    GIT_REPO="${GIT_REPO/#\~/$HOME}"

    # 验证配置
    if [[ -z "$GIT_REPO" ]]; then
        echo_error "配置文件中缺少 git_repo"
        exit 1
    fi

    if [[ ! -d "$GIT_REPO" ]]; then
        echo_error "仓库目录不存在: $GIT_REPO"
        exit 1
    fi

    # 默认值
    GIT_REMOTE="${GIT_REMOTE:-origin}"
    GIT_BRANCH="${GIT_BRANCH:-main}"
}

# 提交工作日志
commit_worklog() {
    local source_file="$1"
    local filename=$(basename "$source_file")

    # 检查源文件
    if [[ ! -f "$source_file" ]]; then
        echo_error "源文件不存在: $source_file"
        exit 1
    fi

    echo_info "源文件: $source_file"
    echo_info "目标仓库: $GIT_REPO"
    echo_info "远程/分支: $GIT_REMOTE/$GIT_BRANCH"

    # 进入仓库目录
    cd "$GIT_REPO"

    # 确保在正确的分支
    local current_branch=$(git branch --show-current 2>/dev/null || echo "")
    if [[ -n "$current_branch" && "$current_branch" != "$GIT_BRANCH" ]]; then
        echo_info "切换到分支: $GIT_BRANCH"
        git checkout "$GIT_BRANCH" 2>/dev/null || git checkout -b "$GIT_BRANCH"
    fi

    # 拉取最新变更 (避免冲突)
    echo_info "拉取远程更新..."
    git pull "$GIT_REMOTE" "$GIT_BRANCH" --rebase 2>/dev/null || true

    # 复制文件到仓库
    cp "$source_file" "$GIT_REPO/$filename"
    echo_info "已复制文件到仓库"

    # Git 操作
    git add "$filename"

    # 检查是否有变更
    if git diff --cached --quiet; then
        echo_info "文件无变更，跳过提交"
        exit 0
    fi

    # 提取日期作为提交信息
    local date_str=$(echo "$filename" | sed 's/\.md$//')

    # 检测是新建还是更新
    local is_new_file=false
    if ! git ls-files --error-unmatch "$filename" &>/dev/null; then
        is_new_file=true
    fi

    local commit_msg
    if $is_new_file; then
        commit_msg="docs: 工作日志 $date_str

🤖 Generated with Claude Code Daily Summary"
    else
        commit_msg="docs: 更新工作日志 $date_str

🤖 Incremental update by Claude Code Daily Summary"
    fi

    git commit -m "$commit_msg"
    echo_success "已提交: $(echo "$commit_msg" | head -1)"

    # 推送 (带重试)
    if ! git_push_with_retry "$GIT_REMOTE" "$GIT_BRANCH"; then
        echo_error "请检查网络连接或手动推送: git push $GIT_REMOTE $GIT_BRANCH"
        exit 1
    fi
}

# 主流程
main() {
    if [[ $# -lt 1 ]]; then
        echo "用法: $0 <markdown_file>"
        echo ""
        echo "示例: $0 /tmp/worklog/2025-12-24.md"
        exit 1
    fi

    local source_file="$1"

    echo ""
    echo_info "===== Git Commit 工作日志 ====="
    echo ""

    # 解析配置
    parse_config

    # 提交
    commit_worklog "$source_file"

    echo ""
    echo_success "===== 完成 ====="
}

main "$@"
