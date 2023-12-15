import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';
import * as vscode from 'vscode';

export async function showStatusMenu(
  logger: ILogger,
  data: IData,
): Promise<{
  success: boolean;
  pick: string | null;
  errorMessage: string | null;
}> {
  logger.log('starting function showStatusMenu', LogLevel.Debug);

  const items = [
    `mode: ${data.stateManager.getCurrentMode()}`,
    `command: ${data.stateManager.getCurrentCommand()}`,
    `sources: ${data.stateManager.getCurrentSources()}`,
  ];
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
    return {
      success: false,
      pick: null,
      errorMessage: 'Status menu was was canceled',
    };
  }
}
