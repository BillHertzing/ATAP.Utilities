import { LogLevel, ILogger } from '@Logger/index';
import * as vscode from 'vscode';
import { StringBuilder } from '../Utilities';

export async function copyToSubmit(extensionContext: vscode.ExtensionContext, logger: ILogger) {
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
  } catch (e) {
    if (e instanceof Error) {
      // Report the error
      message = e.message;
    } else {
      // ToDo: e is not an instance of Error, needs investigation to determine what else might happen
      message = `An unknown error occurred during the copyToSubmit call, and the instance of (e) returned is of type ${typeof e}`;
    }
    logger.log(message, LogLevel.Error);
  }
}

