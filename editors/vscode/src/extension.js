'use strict';

// Thin VS Code shell over the SARIF importer. No network requests.
const vscode = require('vscode');
const { createLoadCommand } = require('./sarif');

function activate(context) {
  const collection = vscode.languages.createDiagnosticCollection('godot-dev-tools');
  context.subscriptions.push(collection);
  context.subscriptions.push(vscode.commands.registerCommand('gdt.loadSarif', createLoadCommand(vscode, collection)));
}

function deactivate() {}
module.exports = { activate, deactivate };
