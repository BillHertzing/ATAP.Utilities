import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';

import { StatusMenuItemEnum } from '@StateMachineService/index';

export async function showStatusMenuAsync(
  logger: ILogger,
  data: IData,
  quickPickItems:vscode.QuickPickItem[]
  
  // ToDo: add a cancellationToken
  // cancellationToken?: vscode.CancellationToken,
): Promise<{
  success: boolean;
  statusMenuItem: StatusMenuItemEnum | null;
  errorMessage: string | null;
}> {
  logger.log('starting function showStatusMenuAsync', LogLevel.Debug);

  const pick = await vscode.window.showQuickPick(quickPickItems, {
    placeHolder: 'Select an option',
  });

  if (pick !== undefined) {
    const statusMenuItem = pick.label as StatusMenuItemEnum;

    return {
      success: true,
      statusMenuItem: statusMenuItem,
      errorMessage: null,
    };
  } else {
    return {
      success: false,
      statusMenuItem: null,
      errorMessage: 'Status menu was was canceled',
    };
  }
}
