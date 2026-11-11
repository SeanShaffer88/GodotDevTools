# Tool Finder

Search the suite by **problem**, not by tool name. Enable the addon, type a plain-words problem in the dock, and select **Find tools**.

```sh
godot --headless --path . --script res://addons/tool_finder/cli/tfd_cli.gd -- --query="my game lags on mobile"
```

The CLI accepts `--query=<text>`, `--out=<dir>` (default `res://reports/tool_finder`) and `--fail-on=no_match`. It writes JSON and Markdown, exits 2 on `--fail-on=no_match`, 1 on an empty query or write failure, 0 otherwise.

## Scope and limitations

- The catalog is built from `addons/*/plugin.cfg` at run time, so new tools appear automatically. No tool imports another tool.
- Matching is keyword + problem-phrase ranking (lag, mobile, crash, leak, test, accessibility, localization, export, shader, audio, physics, save, ui), always explained in `why`. It is not semantic search and never uses the network.
- Results are recommendations, not diagnoses. Run the suggested tool's CLI for evidence.
