import { LogLevel, ILogger } from '../Logger';
import * as vscode from 'vscode';

export async function showQuickPickExample(logger: ILogger): Promise<{
  success: boolean;
  pick: string | null;
  errorMessage: string | null;
}> {
  let message: string = 'starting commandID showQuickPickExample';
  logger.log(message, LogLevel.Debug);
  const items = ['ROption 1', 'ROption 2', 'ROption 3'];
  const pick = await vscode.window.showQuickPick(items, {
    placeHolder: 'Select an option',
  });

  if (pick !== undefined) {
    return {
      success: true,
      pick: pick,
      errorMessage: null,
    };
  } else {
    message = 'Quick Pick was canceled';
    return {
      success: false,
      pick: null,
      errorMessage: message,
    };
  }
}
