# tiny-tools

A collection of small utilities.

## wt.sh

Git worktree management with automated setup and cleanup.

### Setup

```bash
ln -s ~/code/tiny-tools/wt.sh ~/.local/bin/wt
```

Then use `wt` _anywhere_ in a git repository.

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

