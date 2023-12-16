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
  // ToDo: create the items at extension activation so they don't get recreated over and over
  const items: vscode.QuickPickItem[] = [];
  for (const key in StatusMenuItemEnum) {
    if (StatusMenuItemEnum.hasOwnProperty(key)) {
      const enumValue = StatusMenuItemEnum[key as keyof typeof StatusMenuItemEnum];
      let label: string;
      let description: string;
      let kind: vscode.QuickPickItemKind;
      switch (enumValue) {
        case StatusMenuItemEnum.Mode:
          label = `${enumValue}: ${data.stateManager.getCurrentMode()}`;
          description = 'Change CurrentMode';
          break;
        case StatusMenuItemEnum.Command:
          label = `${enumValue}: ${data.stateManager.getCurrentCommand()}`;
          description = 'Change CurrentCommand';
          break;
        case StatusMenuItemEnum.Sources:
          label = `${enumValue}: ${data.stateManager.getCurrentSources()}`;
          description = 'Change Sources';
          break;
        case StatusMenuItemEnum.ShowLogs:
          label = '──────────';
          description = '';
          kind = vscode.QuickPickItemKind.Separator;
          items.push({ label, kind });
          label = `${enumValue}`;
          description = 'Show AiAssist logs in output channel';
          break;
        default:
          continue;
      }
      items.push({ label, description });
    }
  }

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
