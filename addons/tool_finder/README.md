# Tool Finder

Search the suite by **problem**, not by tool name. Enable the addon, type a plain-words problem in the dock, and select **Find tools**.

```sh
godot --headless --path . --script res://addons/tool_finder/cli/tfd_cli.gd -- --query="my game lags on mobile"
```

The CLI accepts `--query=<text>`, `--out=<dir>` (default `res://reports/tool_finder`) and `--fail-on=no_match`. It writes JSON and Markdown, exits 2 on `--fail-on=no_match`, 1 on an empty query or write failure, 0 otherwise.

## How matching works

- The catalog is built from local `addons/*/plugin.cfg` files at run time. New addon folders appear automatically; no tool imports another tool.
- Queries and catalog text are split into whole letter/number words, case-insensitively; punctuation and underscores separate words. Common English filler words are dropped from the query, and a few simple English plurals and aliases are normalized (for example, `lags`/`lagging` to `lag`, `crashes` to `crash`, and `tests`/`testing` to `test`). Repeated normalized words count once. Single-character words are ignored.
- Each unique query word adds 3 points if it occurs in a title or ID, or 1 point if it occurs only in the description. Each matching problem keyword adds 5 points to its curated recommendations. Keywords include `lag`, `slow`, `mobile`, `android`, `touch`, `logcat`, `crash`, `leak`, `test`, `accessibility`, `localization`, `export`, `shader`, `audio`, `physics`, `save` and `ui`. Every match includes a `why` explanation using the normalized word and matching field or recommendation.
- At most ten results are returned, ordered by descending score and then addon ID. A nonempty query with no usable/matching words produces `no_match`; an empty or whitespace-only query is `bad_input`.

## Scope and limitations

The matcher is an offline, English-oriented rule set, **not** semantic search or a complete stemmer. It does not match arbitrary substrings or infer intent, and languages without spaces between words may not tokenize as expected. For example, `build` does not imply the `ui` problem keyword and `flag` does not imply `lag`. Results are recommendations, not diagnoses; run the suggested tool's CLI for evidence. The list reflects installed addon metadata, not whether an addon is enabled or will run successfully.
