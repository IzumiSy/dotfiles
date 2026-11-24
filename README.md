# dotfiles
> There is no place like home 

![Enjoy](http://cdn.tinybuddha.com/wp-content/uploads/2015/01/Enjoy.jpg)

## Setup

```bash
./setup install
./setup uninstall

# Select links by their source paths in setup's LINKS list.
./setup install nvim pi/AGENTS.md pi/settings.json
./setup install git/config git/ignore
./setup uninstall nvim
```

`./setup` without arguments defaults to `install`. Without link arguments, all links are selected. Unknown link names fail before any changes are made.

## Notes

- `install` is effectively idempotent: it skips links that already point at this repo.
- `uninstall` is also effectively idempotent: it removes only links that point at this repo.
- Git configuration and global ignore patterns are linked to `${XDG_CONFIG_HOME:-$HOME/.config}/git/config` and `git/ignore`. `setup` leaves an existing `~/.gitconfig` untouched; its settings take precedence.
- The Pi sandbox startup points sbx's global `core.excludesfile` at the XDG ignore file while preserving its other settings and repository-specific overrides.
- When migrating, remove `~/.gitconfig` or `~/.gitignore_global` only if they are old symlinks to this repo's matching files; keep regular files.
