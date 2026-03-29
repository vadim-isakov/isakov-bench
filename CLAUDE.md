# isakov-bench

## Build

- Use `uv` to run Python: `uv run generate.py`
- Build: `./build.sh`
- Dev server: `./dev.sh`
- Publish: `./publish.sh "commit message"` (rebuilds, commits, pushes; deploys via GitHub Pages)

## Benchmark Generation

- `./generate_result.sh <model> <prompt> [prompt2 ...]` — generate result(s) for a model
- `./generate_result.sh <model> --all` — generate all prompts for a model
- Example: `./generate_result.sh custom:glm-5.1 balloon fish`
- Model cannot read existing results (tools disabled for clean experiments)
- Shows live progress via stream-json
- Run `./build.sh` after to regenerate thumbnails and index.html

## Important

- `index.html` is a **generated file** — never edit it directly.
  All changes go in `generate.py`, then regenerate with `./build.sh`.
