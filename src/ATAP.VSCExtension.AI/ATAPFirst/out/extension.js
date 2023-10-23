"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = void 0;
const vscode = require("vscode");
const processPs1Files_1 = require("./processPs1Files"); // adjust the import to your file structure
const StringBuilder_1 = require("./StringBuilder");
function activate(context) {
    let disposablecopyToSubmit = vscode.commands.registerCommand("atapfirst.copyToSubmit", () => {
        let editor = vscode.window.activeTextEditor;
        if (editor) {
            let document = editor.document;
            let selection = editor.selection;
            let text = document.getText(selection);
            let textToSubmit = new StringBuilder_1.default();
            textToSubmit.append(text);
            vscode.window.showInformationMessage("Text copied to textToSubmit StringBuilder object");
        }
    });
    let disposableremoveRegion = vscode.commands.registerCommand("atapfirst.removeRegion", () => {
        const editor = vscode.window.activeTextEditor;
        if (editor) {
            const document = editor.document;
            const edit = new vscode.WorkspaceEdit();
            for (let i = 0; i < document.lineCount; i++) {
                const line = document.lineAt(i);
                if (line.text.trim().startsWith("#region") ||
                    line.text.trim().startsWith("#endregion")) {
                    const range = line.rangeIncludingLineBreak;
                    edit.delete(document.uri, range);
                }
            }
            vscode.workspace.applyEdit(edit);
        }
    });
    let disposableprocessPs1Files = vscode.commands.registerCommand('atapfirst.processPs1Files', async (commandId) => {
        await (0, processPs1Files_1.processPs1Files)(commandId);
    });
    context.subscriptions.push(disposablecopyToSubmit);
    context.subscriptions.push(disposableremoveRegion);
    context.subscriptions.push(disposableprocessPs1Files);
}
exports.activate = activate;
//# sourceMappingURL=extension.js.map