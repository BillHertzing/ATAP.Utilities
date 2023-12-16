import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';

import { ModeMenuItemEnum, IPickItemsInitializer } from '@StateMachineService/index';

export async function showModeMenuAsync(
  logger: ILogger,
  data: IData,
  pickItemsInitializer: IPickItemsInitializer,
  // ToDo: add a cancellationToken
  // cancellationToken?: vscode.CancellationToken,
): Promise<{
  success: boolean;
  modeMenuItem: ModeMenuItemEnum | null;
  errorMessage: string | null;
}> {
  logger.log('starting function showModeMenuAsync', LogLevel.Debug);

  const pick = await vscode.window.showQuickPick(pickItemsInitializer.modeMenuItems, {
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
