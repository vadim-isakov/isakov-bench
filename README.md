# isakov-bench

Side-by-side visual benchmark comparing AI coding agents on creative HTML/CSS/JS prompts.

**Live:** [bench.isakov.io](https://bench.isakov.io)

## Usage

```bash
./dev.sh          # local dev server with auto-rebuild
./build.sh        # regenerate index.html
./publish.sh "msg" # build, commit, push (deploys via GitHub Pages)
```

## Adding results

Place HTML files in `results/<prompt>/` using the naming convention:

```
<agent>--<model>--<YYYYMMDD>.html
```

Add prompt text in `prompts/<name>.txt`, then rebuild.

## License

MIT
