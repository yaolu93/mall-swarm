#!/bin/bash

# =================================================================
# 脚本功能：自动同步、暂存并推送 (支持干净处理暂存区冲突)
# =================================================================

set -u

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}==> $1${NC}"; }
print_error() { echo -e "${RED}Error: $1${NC}"; }
print_warn() { echo -e "${YELLOW}Warning: $1${NC}"; }

# 1. 检查 Git 环境
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    print_error "当前目录不是一个 Git 仓库！"
    exit 1
fi

# 2. 检查是否有任何改动（包括未跟踪的文件）
if [[ -z $(git status --porcelain) ]]; then
    print_status "没有检测到任何更改，仓库已是最新状态。"
    exit 0
fi

# 3. 核心：处理远程同步
current_branch=$(git branch --show-current)
print_status "当前分支: $current_branch"

# 使用 stash 临时保存所有改动（包括未暂存和已暂存的）
print_status "正在临时隐藏本地改动 (git stash)..."
HAS_STASH=false
if [[ -n $(git status --porcelain) ]]; then
    git stash push -m "Auto-stash before sync"
    HAS_STASH=true
fi

# 4. 执行同步
print_status "正在从远程获取更新并变基 (git pull --rebase)..."
if ! git pull --rebase origin "$current_branch"; then
    print_error "同步失败！远程与本地可能存在冲突。"
    if [ "$HAS_STASH" = true ]; then
        print_warn "你的改动仍在 stash 中，请手动执行 'git stash pop' 后解决冲突。"
    fi
    exit 1
fi

# 5. 还原改动
if [ "$HAS_STASH" = true ]; then
    print_status "正在恢复本地改动 (git stash pop)..."
    if ! git stash pop; then
        print_error "恢复改动时发生冲突！请手动解决冲突。"
        exit 1
    fi
fi

# 6. 重新暂存并准备提交
print_status "正在重新暂存所有更改 (git add .)..."
git add .
print_status "当前更改摘要:"
git status -s

# 7. 交互式 Commit Message
echo -e "${YELLOW}请输入 Commit Message (直接回车则使用 'update content'):${NC} "
read commit_msg
commit_msg=${commit_msg:-"update content"}

# 8. 执行提交与推送
print_status "正在提交..."
if ! git commit -m "$commit_msg"; then
    print_error "Commit 失败！"
    exit 1
fi

print_status "正在推送到远程..."
if ! git push origin "$current_branch"; then
    print_error "Push 失败！"
    exit 1
fi

print_status "✨ 仓库同步并更新成功！"
