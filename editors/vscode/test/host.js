'use strict';

const assert = require('node:assert/strict');
const vscode = require('vscode');
const { loadSarif } = require('../src/sarif');

function result(uri, level = 'warning', line = 17) {
  return {
    ruleId: 'host_smoke', level, message: { text: 'Host smoke finding' },
    locations: [{ physicalLocation: {
      artifactLocation: { uri, uriBaseId: 'PROJECTROOT' }, region: { startLine: line },
    } }],
  };
}
function report(results) { return { version: '2.1.0', runs: [{ results }] }; }
async function writeJson(uri, value) {
  await vscode.workspace.fs.writeFile(uri, Buffer.from(JSON.stringify(value), 'utf8'));
}

async function run() {
  const extension = vscode.extensions.getExtension('godot-dev-tools.godot-dev-tools-sarif');
  assert.ok(extension, 'extension is discoverable by its manifest ID');
  await extension.activate();
  assert.ok((await vscode.commands.getCommands(true)).includes('gdt.loadSarif'), 'command is registered');
  assert.equal(vscode.workspace.workspaceFolders.length, 1);
  const root = vscode.workspace.workspaceFolders[0].uri;
  const player = vscode.Uri.joinPath(root, 'player.gd');
  await vscode.workspace.fs.writeFile(player, Buffer.from('line\n'.repeat(20), 'utf8'));
  let input;
  if (process.env.GDT_SARIF_REPORT) {
    input = vscode.Uri.file(process.env.GDT_SARIF_REPORT);
  } else {
    input = vscode.Uri.joinPath(root, 'fixture.sarif');
    await writeJson(input, report([result('player.gd')]));
  }
  const collection = vscode.languages.createDiagnosticCollection('gdt-host-smoke');
  try {
    const first = await loadSarif(vscode, collection, input, root);
    assert.ok(first.findings > 0);
    const firstDiagnostics = collection.get(player);
    assert.ok(firstDiagnostics && firstDiagnostics.length === 1, 'diagnostic belongs to the actual project file URI');
    assert.equal(firstDiagnostics[0].range.start.line, 16);
    assert.equal(firstDiagnostics[0].severity, vscode.DiagnosticSeverity.Warning);
    assert.ok(vscode.languages.getDiagnostics(player).some(d => d.source === 'godot-dev-tools'));

    const special = vscode.Uri.joinPath(root, 'file # 100% é.gd');
    await vscode.workspace.fs.writeFile(special, Buffer.from('x\n', 'utf8'));
    const second = vscode.Uri.joinPath(root, 'replacement.sarif');
    await writeJson(second, report([result('file # 100% é.gd', 'note', 1)]));
    await loadSarif(vscode, collection, second, root);
    assert.equal((collection.get(player) || []).length, 0, 'old report diagnostics are cleared');
    assert.equal(collection.get(special)[0].severity, vscode.DiagnosticSeverity.Information);

    const malformed = vscode.Uri.joinPath(root, 'malformed.sarif');
    await vscode.workspace.fs.writeFile(malformed, Buffer.from('{', 'utf8'));
    await assert.rejects(loadSarif(vscode, collection, malformed, root));
    assert.equal(collection.get(special).length, 1, 'a failed load retains the last diagnostics');
    console.log(`VS Code extension host smoke passed (${vscode.version}; ${first.findings} initial diagnostic(s)).`);
  } finally {
    collection.dispose();
  }
}

module.exports = { run };
