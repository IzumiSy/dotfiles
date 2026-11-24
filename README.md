# dotfiles
> There is no place like home 

![Enjoy](http://cdn.tinybuddha.com/wp-content/uploads/2015/01/Enjoy.jpg)

## Setup

```bash
./setup install
./setup uninstall

# Select links by their source paths in setup's LINKS list.
./setup install nvim pi/AGENTS.md pi/settings.json
./setup uninstall nvim
```

`./setup` without arguments defaults to `install`. Without link arguments, all links are selected. Unknown link names fail before any changes are made.

## Notes

- `install` is effectively idempotent: it skips links that already point at this repo.
- `uninstall` is also effectively idempotent: it removes only links that point at this repo.
