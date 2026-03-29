# isakov-bench

## Build

- Use `uv` to run Python: `uv run generate.py`
- Build: `./build.sh`
- Dev server: `./dev.sh`

## Important

- `index.html` is a **generated file** — never edit it directly.
  All changes go in `generate.py`, then regenerate with `./build.sh`.
