import * as vscode from "vscode";
import { processPs1Files } from './processPs1Files';  // adjust the import to your file structure

import StringBuilder from "./StringBuilder";

export function activate(context: vscode.ExtensionContext) {
  let disposablecopyToSubmit = vscode.commands.registerCommand(
    "atapfirst.copyToSubmit",
    () => {
      let editor = vscode.window.activeTextEditor;
      if (editor) {
        let document = editor.document;
        let selection = editor.selection;
        let text = document.getText(selection);

        let textToSubmit = new StringBuilder();
        textToSubmit.append(text);

        vscode.window.showInformationMessage(
          "Text copied to textToSubmit StringBuilder object"
        );
      }
    }
  );
  let disposableremoveRegion = vscode.commands.registerCommand(
    "atapfirst.removeRegion",
    () => {
      const editor = vscode.window.activeTextEditor;

      if (editor) {
        const document = editor.document;
        const edit = new vscode.WorkspaceEdit();

        for (let i = 0; i < document.lineCount; i++) {
          const line = document.lineAt(i);

          if (
            line.text.trim().startsWith("#region") ||
            line.text.trim().startsWith("#endregion")
          ) {
            const range = line.rangeIncludingLineBreak;
            edit.delete(document.uri, range);
          }
        }

        vscode.workspace.applyEdit(edit);
      }
    }
  );

  let disposableprocessPs1Files = vscode.commands.registerCommand('atapfirst.processPs1Files', async (commandId: string) => {
    await processPs1Files(commandId);
  });


  context.subscriptions.push(disposablecopyToSubmit);
  context.subscriptions.push(disposableremoveRegion);
  context.subscriptions.push(disposableprocessPs1Files);



}
