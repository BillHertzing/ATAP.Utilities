import vscode from 'vscode';
import { ModeMenuItemEnum, CommandMenuItemEnum, StatusMenuItemEnum } from '@StateMachineService/index';

export interface IPickItemsInitializer {
  statusMenuItems: vscode.QuickPickItem[];
  modeMenuItems: vscode.QuickPickItem[];
  commandMenuItems: vscode.QuickPickItem[];
}
export class PickItemsInitializer {
  public readonly statusMenuItems: vscode.QuickPickItem[];
  public readonly modeMenuItems: vscode.QuickPickItem[];
  public readonly commandMenuItems: vscode.QuickPickItem[];

  constructor() {
    this.statusMenuItems = PickItemsInitializer.initializeStatusMenuItems();
    this.modeMenuItems = PickItemsInitializer.initializeModeMenuItems();
    this.commandMenuItems = PickItemsInitializer.initializeCommandMenuItems();
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
            label = `${enumValue}`;
            description = 'Change CurrentMode';
            break;
          case StatusMenuItemEnum.Command:
            label = `${enumValue}`;
            description = 'Change CurrentCommand';
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

  static initializeModeMenuItems(): vscode.QuickPickItem[] {
    const items: vscode.QuickPickItem[] = [];
    for (const key in ModeMenuItemEnum) {
      if (ModeMenuItemEnum.hasOwnProperty(key)) {
        const enumValue = ModeMenuItemEnum[key as keyof typeof ModeMenuItemEnum];
        let label: string;
        let description: string;
        let kind: vscode.QuickPickItemKind;
        switch (enumValue) {
          case ModeMenuItemEnum.Workspace:
            label = `${enumValue}`;
            description = 'Use Workspace';
            break;
          case ModeMenuItemEnum.VSCode:
            label = `${enumValue}`;
            description = 'Use VSCode';
            break;
          case ModeMenuItemEnum.ChatGPT:
            label = `${enumValue}`;
            description = 'Use ChatGPT';
            break;
          case ModeMenuItemEnum.Claude:
            label = `${enumValue}`;
            description = 'Use Claude';
            break;
          default:
            continue;
        }
        items.push({ label, description });
      }
    }
    return items;
  }

  static initializeCommandMenuItems(): vscode.QuickPickItem[] {
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
