# Player Telemetry Schema Validator

Validate local, synthetic telemetry samples against a JSON event schema. Enable the plugin and enter schema and sample paths in the dock, or run:

```sh
godot --headless --path . --script res://addons/telemetry_schema/cli/tel_cli.gd -- \
  --schema=res://demo/telemetry/schema.json --samples=res://demo/telemetry/events.json \
  --fail-on=type_mismatch,sensitive_field
```

Schema shape: `{"events":{"event_name":{"fields":{"field_name":{"type":"string","required":true,"sensitive":false}}}}}`. Field types are `string`, `number`, `integer`, `boolean`, `object`, and `array`; `required` and `sensitive` are optional booleans. Samples have shape `{"events":[{"name":"event_name","fields":{"field_name":"value"}}]}`. JSON numbers with no fractional part satisfy `integer`. Sensitive fields trigger a review finding when present; there is no automatic personal-data detection.

The CLI defaults to the demo fixtures and writes JSON/Markdown reports to `res://reports/telemetry_schema` (`--out` overrides). `--fail-on` accepts `unknown_event`, `unknown_field`, `missing_field`, `type_mismatch`, `sensitive_field`, or `issues`. Selected findings exit 2; malformed inputs/schema/events or report-write errors exit 1; otherwise exit 0. Malformed data takes precedence over warning gates. Reports include event indices and field names but never payload values. Use synthetic samples: field names, input paths and files can still be sensitive.

This is a local static sample check, not a runtime SDK, endpoint scanner, consent system, privacy compliance audit, or guarantee of anonymity. It does not inspect nested object schemas or validate actual network traffic. It does not edit input files or use the network. Godot execution and a hands-on editor session remain to be verified.
