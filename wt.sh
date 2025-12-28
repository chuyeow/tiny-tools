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
            elif [[ "$line" =~ ^branch\ refs/heads/main$ ]]; then
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

    local cd_command="cd \"$(cd $worktree_path && pwd)\""
    echo "$cd_command" | pbcopy
    echo "✓ Copied to clipboard: $cd_command" >&2
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
