import vscode from 'vscode';
import { ModeMenuItemEnum, CommandMenuItemEnum, StatusMenuItemEnum } from '@StateMachineService/index';
import { IData } from '@DataService/index';

export interface IPickItems {
  statusMenuItems: vscode.QuickPickItem[];
  modeMenuItems: vscode.QuickPickItem[];
  commandMenuItems: vscode.QuickPickItem[];
}
export class PickItems {
  constructor(private readonly data: IData) {}

  get statusMenuItems(): vscode.QuickPickItem[] {
    const items: vscode.QuickPickItem[] = [];
    for (const key in StatusMenuItemEnum) {
      if (StatusMenuItemEnum.hasOwnProperty(key)) {
        const enumValue = StatusMenuItemEnum[key as keyof typeof StatusMenuItemEnum];
        let label: string;
        let description: string;
        let kind: vscode.QuickPickItemKind;
        switch (enumValue) {
          case StatusMenuItemEnum.Mode:
            label = `${enumValue}`;
            description = `Change CurrentMode: ${this.data.stateManager.currentMode}`;
            break;
          case StatusMenuItemEnum.Command:
            label = `${enumValue}`;
            description = `Change CurrentCommand: ${this.data.stateManager.currentCommand}`;
            break;
          case StatusMenuItemEnum.Sources:
            label = `${enumValue}`;
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

  get modeMenuItems(): vscode.QuickPickItem[] {
    const items: vscode.QuickPickItem[] = [];
    const currentMode = this.data.stateManager.currentMode;
    for (const key in ModeMenuItemEnum) {
      if (ModeMenuItemEnum.hasOwnProperty(key)) {
        const enumValue = ModeMenuItemEnum[key as keyof typeof ModeMenuItemEnum];
        let label: string;
        let description: string;
        let kind: vscode.QuickPickItemKind;
        switch (enumValue) {
          case ModeMenuItemEnum.Workspace:
            label = `${enumValue}`;
            description = 'Use Workspace' + (currentMode === ModeMenuItemEnum.Workspace ? ' ✓' : ' ');
            break;
          case ModeMenuItemEnum.VSCode:
            label = `${enumValue}`;
            description = 'Use VSCode' + (currentMode === ModeMenuItemEnum.VSCode ? ' ✓' : ' ');
            break;
          case ModeMenuItemEnum.ChatGPT:
            label = `${enumValue}`;
            description = 'Use ChatGPT' + (currentMode === ModeMenuItemEnum.ChatGPT ? ' ✓' : ' ');
            break;
          case ModeMenuItemEnum.Claude:
            label = `${enumValue}`;
            description = 'Use Claude' + (currentMode === ModeMenuItemEnum.Claude ? ' ✓' : ' ');
            break;
          default:
            continue;
        }
        items.push({ label, description });
      }
    }
    return items;
  }

  get commandMenuItems(): vscode.QuickPickItem[] {
    const items: vscode.QuickPickItem[] = [];
    for (const key in CommandMenuItemEnum) {
      if (CommandMenuItemEnum.hasOwnProperty(key)) {
        const enumValue = CommandMenuItemEnum[key as keyof typeof CommandMenuItemEnum];
        let label: string;
        let description: string;
        let kind: vscode.QuickPickItemKind;
        switch (enumValue) {
          case CommandMenuItemEnum.Chat:
            label = `${enumValue}`;
            description = 'Chat';
            break;
          case CommandMenuItemEnum.Fix:
            label = `${enumValue}`;
            description = 'Fix';
            break;
          case CommandMenuItemEnum.Test:
            label = `${enumValue}`;
            description = 'Test';
            break;
          case CommandMenuItemEnum.Document:
            label = `${enumValue}`;
            description = 'Document';
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
