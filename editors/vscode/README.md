# VS Code SARIF diagnostics

Load the GodotDevTools [SARIF Exporter](https://github.com/SeanShaffer88/GodotDevTools/tree/main/addons/sarif_export) output as VS Code diagnostics. This is a separate extension from the MCP server; it does not run a Godot scan itself.

## Use

1. Run the desired tools, then run the SARIF Exporter in your Godot project:

   ```sh
   godot --headless --path /path/to/project --script res://addons/sarif_export/cli/srf_cli.gd -- --reports=res://reports
   ```

   The default output is `reports/sarif_export/gdt.sarif`.
2. Install the extension or open `editors/vscode` in VS Code and press F5 to launch an Extension Development Host. In the VS Code window that will display diagnostics, open the **Godot project folder** containing `project.godot` as a workspace folder.
3. Run **GodotDevTools: Load SARIF report** from the Command Palette and select the report. With multiple workspace folders, choose the folder that was the Godot project root when the report was generated. A single workspace folder is selected automatically, even when the report is stored elsewhere.

To build a local VSIX instead, run `npx --yes @vscode/vsce@3.6.2 package --no-dependencies` in `editors/vscode`, then use **Extensions: Install from VSIX**. Packaging downloads the `vsce` tool if it is not already cached and requires Node.js 20+; it does not publish the extension.

The exporter uses `PROJECTROOT` and a placeholder `file:///` base. This extension resolves its project-relative paths against the chosen workspace folder, not the placeholder or the report's directory. It groups results by file, uses the reported line and column when present, and maps SARIF `error`, `warning`, `note` and `none` to VS Code error, warning, information and hint diagnostics. Unknown lines start at line 1.

Each successful load replaces the extension's previous diagnostics, including when a report contains no usable locations. Cancelling or failing to read/parse a report leaves the previous diagnostics in place. Loading is manual; re-run the command after generating a new report. An information message includes the number of skipped results.

## Scope and limitations

- The supported input is the SARIF 2.1.0 subset produced by GodotDevTools: raw project-relative paths with `uriBaseId` `PROJECTROOT` (or no base ID), the first physical location of each result, and text messages. It does not implement general SARIF URI-base resolution, absolute file URIs, URL/percent-decoding, related locations or fixes. Results without a supported location, including absolute paths, `..` traversal and foreign base IDs, are skipped.
- Open the project root itself as a workspace folder; if a project is nested under a larger workspace, add that project folder before loading. Diagnostics do not prove the target file exists or that a finding is correct.
- The extension reads only the selected report and changes the VS Code diagnostic collection; it does not write project files or initiate network requests. VS Code's filesystem provider may access a remote workspace if you have configured one.
- Automated tests use mock VS Code APIs plus a configured VS Code extension-host smoke. They do not exercise the interactive picker or establish compatibility with arbitrary third-party SARIF logs.

## Tests

```sh
cd editors/vscode
npm ci --ignore-scripts
npm test
npm run test:host
```

`npm test` needs Node.js 18+ and the pinned development dependencies. `test:host` downloads VS Code 1.80.2 and runs an extension-host smoke; on Linux it needs a display (for example, `xvfb-run -a npm run test:host`). Set `GDT_SARIF_REPORT` to a real exporter output to exercise that report; otherwise the host test uses a synthetic fixture. The extension itself has no runtime npm dependencies.
