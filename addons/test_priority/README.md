# Regression Test Prioritizer

Rank tests by how many distinct changed paths reach their explicit mappings. Mapping shape: `{"paths":{"res://src/player.gd":["res://tests/test_player.gd"]}}`; changed paths: `{"changed":["res://src/player.gd"]}`. With no graph, matches are exact as before. Ties sort by test path; duplicate changes and duplicate test mappings count once. Unmatched changes are warnings, not proof that no test is needed.

## Optional dependency graph

Pass `--graph=<path>` to use a [Scene Dependency Map](../scene_dependency/README.md) JSON report, or a JSON object with `edges` of the form `{"from":"dependent","to":"dependency"}`. A changed dependency propagates backwards through all reachable dependents (including cycles) to their mapped tests. Each test's score counts each original changed path at most once. Its `evidence` lists the changed path, mapped path and one deterministic shortest chain **from change to dependent**. A path is unmapped only when no test is mapped directly or through any known dependent. Use exactly the same path spelling in changes, graph and mapping (e.g. `res://...`); this tool does not normalize or obtain paths from Git.

Generate the graph separately using Scene Dependency Map, then for example:

```sh
godot --headless --path . --script res://addons/test_priority/cli/priority_cli.gd -- \
  --first=res://demo/test_priority/graph_mapping.json --second=res://demo/test_priority/graph_changes.json \
  --graph=res://demo/test_priority/graph.json --fail-on=unmapped_path
```

The dock accepts an optional graph path too. `--out` changes the report directory. JSON and Markdown reports are written under `res://reports/test_priority` by default. Selected warnings or `issues` exit 2; malformed input, invalid graph and I/O errors exit 1; otherwise exit 0.

The graph is optional input data, not an addon dependency. The source graph's static analysis can miss dynamically constructed references, binary internals, and out-of-scan dependencies; report findings are recommendations, not proof that other tests can be skipped. The tool does not execute or exclude tests, read Git, or automatically update mappings. Godot CI verifies the previous exact-path implementation; graph integration and a hands-on editor session remain to be verified.
