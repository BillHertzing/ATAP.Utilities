import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';

import { CommandMenuItemEnum } from '@StateMachineService/index';

export async function showCommandMenuAsync(
  logger: ILogger,
  data: IData,
  quickPickItems:vscode.QuickPickItem[]
  // ToDo: add a cancellationToken
  // cancellationToken?: vscode.CancellationToken,
): Promise<{
  success: boolean;
  commandMenuItem: CommandMenuItemEnum | null;
  errorMessage: string | null;
}> {
  logger.log('starting function showCommandMenuAsync', LogLevel.Debug);

  const pick = await vscode.window.showQuickPick(quickPickItems, {
    placeHolder: 'Select an option',
  });

  if (pick !== undefined) {
    const commandMenuItem = pick.label as CommandMenuItemEnum;

    return {
      success: true,
      commandMenuItem: commandMenuItem,
      errorMessage: null,
    };
  } else {
    return {
      success: false,
      commandMenuItem: null,
      errorMessage: 'Command menu was was canceled',
    };
  }
}
