#!/bin/bash
# Manage git worktrees with automated setup and cleanup
# Usage: wt.sh <add|rm|ls|switch> [branch-name]

set -e

# Detect current worktree root, then derive worktree base from the primary worktree
GIT_ROOT="$(git rev-parse --show-toplevel)"
cd "$GIT_ROOT"

GIT_COMMON_DIR="$(git rev-parse --git-common-dir)"
GIT_COMMON_DIR_ABS="$(cd "$GIT_COMMON_DIR" && pwd -P)"

if [[ "$(basename "$GIT_COMMON_DIR_ABS")" != ".git" ]]; then
    echo "Error: Unexpected git common dir: $GIT_COMMON_DIR_ABS" >&2
    exit 1
fi

MAIN_WORKTREE_ROOT="$(cd "$GIT_COMMON_DIR_ABS/.." && pwd -P)"
PROJECT_NAME="$(basename "$MAIN_WORKTREE_ROOT")"
WORKTREE_BASE="$(dirname "$MAIN_WORKTREE_ROOT")/${PROJECT_NAME}.wt"
ENV_FILES=(".env" "node_modules" ".claude/settings.local.json" ".codex")

copy_or_print() {
    local text="$1"

    if command -v pbcopy >/dev/null; then
        if printf "%s" "$text" | pbcopy; then
            echo "✓ Copied to clipboard: $text" >&2
            return 0
        fi
        echo "Warning: pbcopy failed; printing command" >&2
    fi

    echo "$text"
    echo "✓ Command printed (clipboard unavailable)" >&2
}

show_usage() {
    local script_name=$(basename $0)
    cat << EOF
Usage: $script_name <command> [branch-name]

Commands:
  ls                List all active worktrees (alias: list)
  add <branch>      Create a new worktree with the given branch name
  rm <branch>       Remove a worktree (alias: delete)
  switch <branch>   Copy "cd <worktree dir>" to clipboard

Examples:
  $script_name add improve-git-usage
  $script_name rm improve-git-usage
  $script_name ls
  $script_name switch improve-git-usage    # Copies to clipboard, paste in terminal
  $script_name switch main                 # Switch back to main repository
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

    local cd_command="cd \"$(cd "$worktree_path" && pwd -P)\""

    echo "  $cd_command"
    copy_or_print "$cd_command" >/dev/null
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

    echo "Removing branch $branch_name..."
    git branch -d "$branch_name"
    echo "✓ Branch $branch_name removed successfully"
}

list_worktrees() {
    echo "Current worktrees:"
    git worktree list
}

switch_worktree() {
    local branch_name="$1"

    if [[ -z "$branch_name" ]]; then
        echo "Error: branch name required"
        show_usage
        exit 1
    fi

    local worktree_path
    if [[ "$branch_name" == "main" ]]; then
        # Find the main worktree from porcelain output
        local current_worktree=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^worktree ]]; then
                current_worktree="${line#worktree }"
            elif [[ "$line" =~ ^branch\ refs/heads/(main|master)$ ]]; then
                worktree_path="$current_worktree"
                break
            fi
        done < <(git worktree list --porcelain)

        if [[ -z "$worktree_path" ]]; then
            echo "Error: Could not find main worktree" >&2
            exit 1
        fi
    else
        worktree_path="${WORKTREE_BASE}/${branch_name}"
        if [[ ! -d "$worktree_path" ]]; then
            echo "Error: Worktree not found at $worktree_path" >&2
            exit 1
        fi
    fi

    local cd_command="cd \"$(cd "$worktree_path" && pwd -P)\""
    copy_or_print "$cd_command"
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
    switch)
        switch_worktree "$@"
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
