# tiny-tools

A collection of small, portable shell utilities.

## wt.sh

Git worktree management with automated setup and cleanup.

### Setup

```bash
ln -s ~/code/tiny-tools/wt.sh ~/.local/bin/wt
```

Then use `wt` anywhere in a git repository.

### Usage

**List worktrees:**
```bash
wt ls
```

**Create a new worktree:**
```bash
wt add improve-login
```

Creates a worktree at `../projectname.wt/improve-login/` and copies:
- `.env`
- `node_modules`
- `.claude/settings.local.json`

**Remove a worktree:**
```bash
wt rm improve-login
```

Prompts for confirmation before removing.

### How it works

- Automatically detects the git repository root
- Derives the project name from the repository directory
- Ensures worktree paths are correct from any subdirectory
- Works in any git repository without configuration
