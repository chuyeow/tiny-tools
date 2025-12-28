#!/bin/bash
# Manage git worktrees with automated setup and cleanup
# Usage: wt.sh <add|rm|ls> [branch-name]

set -e

# Detect git repository root and derive project name
GIT_ROOT=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT"
PROJECT_NAME=$(basename "$GIT_ROOT")
WORKTREE_BASE="../${PROJECT_NAME}.wt"
ENV_FILES=(".env" "node_modules" ".claude/settings.local.json")

show_usage() {
    local script_name=$(basename $0)
    cat << EOF
Usage: $script_name <command> [branch-name]

Commands:
  add <branch>      Create a new worktree with the given branch name
  rm <branch>       Remove a worktree (alias: delete)
  ls                List all active worktrees (alias: list)

Examples:
  $script_name add improve-git-usage
  $script_name rm improve-git-usage
  $script_name ls
EOF
}

create_worktree() {
    local branch_name="$1"

    if [[ -z "$branch_name" ]]; then
        echo "Error: branch name required"
        show_usage
        exit 1
    fi

    local worktree_path="${WORKTREE_BASE}/${branch_name}"

    if [[ -d "$worktree_path" ]]; then
        echo "Error: Worktree already exists at $worktree_path"
        exit 1
    fi

    echo "Creating worktree at $worktree_path..."
    git worktree add -b "$branch_name" "$worktree_path"

    echo "Copying environment files..."
    for file in "${ENV_FILES[@]}"; do
        if [[ -e "$file" ]]; then
            rsync -aR "$file" "$worktree_path/"
            echo "  ✓ $file"
        fi
    done

    echo ""
    echo "✓ Worktree created successfully"
    echo "  Location: $worktree_path"
    echo "  Branch:   $branch_name"
    echo ""
    echo "Start developing:"
    echo "  cd $(cd $worktree_path && pwd)"
}

delete_worktree() {
    local branch_name="$1"

    if [[ -z "$branch_name" ]]; then
        echo "Error: branch name required"
        show_usage
        exit 1
    fi

    local worktree_path="${WORKTREE_BASE}/${branch_name}"

    echo "Current worktrees:"
    git worktree list
    echo ""

    if [[ ! -d "$worktree_path" ]]; then
        echo "Error: Worktree not found at $worktree_path"
        exit 1
    fi

    read -p "Remove worktree: $worktree_path? (y/n) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        exit 0
    fi

    echo "Removing worktree..."
    git worktree remove "$worktree_path"

    # Clean up empty directory
    if [[ -d "$worktree_path" ]]; then
        rmdir "$worktree_path" 2>/dev/null || true
    fi

    echo "✓ Worktree removed successfully"
}

list_worktrees() {
    echo "Current worktrees:"
    git worktree list
}

# Main
if [[ $# -eq 0 ]]; then
    show_usage
    echo ""
    list_worktrees
    exit 0
fi

command="$1"
shift || true

case "$command" in
    add)
        create_worktree "$@"
        ;;
    rm | delete)
        delete_worktree "$@"
        ;;
    ls | list)
        list_worktrees
        ;;
    -h | --help)
        show_usage
        ;;
    *)
        echo "Error: Unknown command '$command'"
        show_usage
        exit 1
        ;;
esac
