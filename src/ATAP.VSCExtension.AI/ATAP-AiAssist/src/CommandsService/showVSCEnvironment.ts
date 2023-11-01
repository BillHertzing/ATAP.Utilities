import {
  LogLevel,
  ILogger,
} from '../Logger';
import * as vscode from 'vscode';

export function showVSCEnvironment(logger: ILogger): void {
  let message: string = 'starting commandID showVSCEnvironment';
  logger.log(message, LogLevel.Debug);
  const workspaceFolders = vscode.workspace.workspaceFolders;
  // Check if a workspace is open
  if (workspaceFolders && workspaceFolders.length > 0) {
    // Use the URI property to get the folder path
    message = `workspaceFolder = ${workspaceFolders[0].uri.fsPath} `;
  } else {
    message = 'No workspace folder open.';
  }
  const editor = vscode.window.activeTextEditor;
  if (editor) {
    const document = editor.document;
    const fileName = document.fileName;
    message += `; fileDirname = ${document.fileName}`;
  } else {
    message += '; No editor open';
  }
  logger.log(message, LogLevel.Debug);
}
