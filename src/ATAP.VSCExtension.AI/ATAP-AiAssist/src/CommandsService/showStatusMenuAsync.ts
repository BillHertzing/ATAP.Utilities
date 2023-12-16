import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';
import * as vscode from 'vscode';

import { StatusMenuItemEnum } from '@StateMachineService/index';

export async function showStatusMenuAsync(
  logger: ILogger,
  data: IData,
  // ToDo: add a cancellationToken
  // cancellationToken?: vscode.CancellationToken,
): Promise<{
  success: boolean;
  statusMenuItem: StatusMenuItemEnum | null;
  errorMessage: string | null;
}> {
  logger.log('starting function showStatusMenuAsync', LogLevel.Debug);

  // ToDo: maintain a reference to the quickPick so that it can be canceled during extension deactivation or at any time via a cancellation token

  const items: vscode.QuickPickItem[] = [
    { label: `mode: ${data.stateManager.getCurrentMode()}`, description: 'Change CurrentMode' },
    { label: `command: ${data.stateManager.getCurrentCommand()}`, description: 'Change getCurrentCommand' },
    { label: `sources: ${data.stateManager.getCurrentSources()}`, description: 'Change getCurrentSources' },
    { label: '──────────', kind: vscode.QuickPickItemKind.Separator },
    { label: 'Show Logs', description: 'Show logs in output channel' },
  ];

  const pick = await vscode.window.showQuickPick(items, {
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
