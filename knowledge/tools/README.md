# Tools

| File | What it does |
|---|---|
| [`build-ai-bundle.py`](build-ai-bundle.py) | Regenerates the repo-root `manifest.json` (machine-readable file map + reading order) and `ai-bundle.md` (the whole knowledge base as one file) so AI tools that download the repo — ChatGPT included — can ingest it locally. Run after any content change. Python 3, standard library only. |

The working tools for Godot development itself live in this
repo's `addons/` folder: the **GodotDevTools** suite — 141 Godot 4
dev-tool addons with editor docks, headless CLIs, and CI gates.
