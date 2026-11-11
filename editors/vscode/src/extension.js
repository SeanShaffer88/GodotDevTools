// Minimal SARIF -> VSCode diagnostics. No network. See editors/vscode/README.md.
const vscode = require('vscode');
const fs = require('fs');
function activate(context) {
  const collection = vscode.languages.createDiagnosticCollection('godot-dev-tools');
  context.subscriptions.push(collection);
  const cmd = vscode.commands.registerCommand('gdt.loadSarif', async () => {
    const uris = await vscode.window.showOpenDialog({ canSelectMany: false, filters: { SARIF: ['sarif'] } });
    if (!uris || !uris.length) return;
    const sarif = JSON.parse(fs.readFileSync(uris[0].fsPath, 'utf8'));
    const byFile = {};
    for (const run of sarif.runs || []) {
      for (const r of run.results || []) {
        const loc = (r.locations && r.locations[0] && r.locations[0].physicalLocation) || {};
        const file = loc.artifactLocation && loc.artifactLocation.uri;
        if (!file) continue;
        const line = (loc.region && loc.region.startLine) || 1;
        const range = new vscode.Range(line - 1, 0, line - 1, 1);
        const diag = new vscode.Diagnostic(range, r.message && r.message.text || r.ruleId || 'GodotDevTools finding', r.level === 'error' ? vscode.DiagnosticSeverity.Error : vscode.DiagnosticSeverity.Warning);
        diag.code = r.ruleId;
        diag.source = 'godot-dev-tools';
        (byFile[file] = byFile[file] || []).push(diag);
      }
    }
    for (const [file, diags] of Object.entries(byFile)) {
      collection.set(vscode.Uri.parse(file), diags);
    }
    vscode.window.showInformationMessage(`GodotDevTools: loaded ${Object.keys(byFile).length} file(s) from SARIF.`);
  });
  context.subscriptions.push(cmd);
}
function deactivate() {}
module.exports = { activate, deactivate };
