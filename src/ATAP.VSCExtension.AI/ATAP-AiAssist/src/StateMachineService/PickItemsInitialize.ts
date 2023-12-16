import vscode from 'vscode';
import { StatusMenuItemEnum } from '@StateMachineService/index';

export static class PickItemsInitialize {
    public readonly statusMenuItems: vscode.QuickPickItem[];

  constructor() {
    this.statusMenuItems = initializeStatusMenuItems();
  }


  static initializeStatusMenuItems(): vscode.QuickPickItem[] {
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
return items;
  }
}


}

