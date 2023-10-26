import * as vscode from "vscode";
import { processPs1Files } from './processPs1Files';  // adjust the import to your file structure

import StringBuilder from "./StringBuilder";

export function activate(context: vscode.ExtensionContext) {
  let copyToSubmitDisposable = vscode.commands.registerCommand(
    "ATAP-AIAssist.copyToSubmit",
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
  let removeRegionDisposable = vscode.commands.registerCommand(
    "ATAP-AIAssist.removeRegion",
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

  let processPs1FilesDisposable = vscode.commands.registerCommand('ATAP-AIAssist.processPs1Files', async (commandId: string | null) => {
    const processPs1FilesRecord = await processPs1Files(commandId);
    let message: string = '';
    if (processPs1FilesRecord.success) {
      message = `processPs1Files processed ${processPs1FilesRecord.numFilesProcessed} files, using commandID  ${processPs1FilesRecord.commandIDUsed}`;
      vscode.window.showInformationMessage(`${message}`);
    } else {
      message = `processPs1Files failed, error message is ${processPs1FilesRecord.errorMessage}, attemptedCommandID is ${processPs1FilesRecord.commandIDUsed}`;
      vscode.window.showErrorMessage(`${message}`);
    }
  });


  context.subscriptions.push(copyToSubmitDisposable);
  context.subscriptions.push(removeRegionDisposable);
  context.subscriptions.push(processPs1FilesDisposable);



}
