import { LogLevel, ILogger } from '@Logger/Logger';
import * as vscode from 'vscode';
import { StringBuilder } from '../Utilities';



export async function copyToSubmit(context: vscode.ExtensionContext, logger: ILogger) {
  let message: string = 'starting command copyToSubmit';
  logger.log(message, LogLevel.Debug);

  // ToDo: make this an async function
  try {
    let editor = vscode.window.activeTextEditor;
    if (editor) {
      let document = editor.document;
      let selection = editor.selection;
      let text = await document.getText(selection);

      let message: string = `the editor's selected text fetched: ${text}`;
      logger.log(message, LogLevel.Debug);
      let textToSubmit = new StringBuilder();
      //textToSubmit.append(text);
    }
  } catch (error) {
    message = `An error occurred while fetching the selected text: ${error}`;
    logger.log(message, LogLevel.Error);
  }
}

