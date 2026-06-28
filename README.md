# dotfiles
> There is no place like home 

![Enjoy](http://cdn.tinybuddha.com/wp-content/uploads/2015/01/Enjoy.jpg)

## Setup

```bash
./setup install
./setup uninstall
```

`./setup` without arguments defaults to `install`.

## Notes

- `install` is effectively idempotent: it skips links that already point at this repo.
- `uninstall` is also effectively idempotent: it removes only links that point at this repo.
