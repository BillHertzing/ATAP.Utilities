import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';

import { ModeMenuItemEnum } from '@StateMachineService/index';

export async function showModeMenuAsync(
  logger: ILogger,
  data: IData,
  quickPickItems:vscode.QuickPickItem[]
  // ToDo: add a cancellationToken
  // cancellationToken?: vscode.CancellationToken,
): Promise<{
  success: boolean;
  modeMenuItem: ModeMenuItemEnum | null;
  errorMessage: string | null;
}> {
  logger.log('starting function showModeMenuAsync', LogLevel.Debug);

  const pick = await vscode.window.showQuickPick(quickPickItems, {
    placeHolder: 'Select an option',
  });

  if (pick !== undefined) {
    const modeMenuItem = pick.label as ModeMenuItemEnum;

    return {
      success: true,
      modeMenuItem: modeMenuItem,
      errorMessage: null,
    };
  } else {
    return {
      success: false,
      modeMenuItem: null,
      errorMessage: 'Mode menu was was canceled',
    };
  }
}
