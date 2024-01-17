import vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

import { IData } from '@DataService/index';

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QueryEngineFlagsEnum,
  QueryEngineNamesEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
  SupportedQueryEnginesEnum,
} from '@BaseEnumerations/index';

export interface IPickItems {
  vCSCommandMenuItems: vscode.QuickPickItem[];
  modeMenuItems: vscode.QuickPickItem[];
  queryEnginesMenuItems: vscode.QuickPickItem[];
  queryAgentCommandMenuItems: vscode.QuickPickItem[];
}
export class PickItems {
  constructor(private readonly data: IData) {}

  get vCSCommandMenuItems(): vscode.QuickPickItem[] {
    const items: vscode.QuickPickItem[] = [];
    for (const key in VCSCommandMenuItemEnum) {
      if (VCSCommandMenuItemEnum.hasOwnProperty(key)) {
        const enumValue = VCSCommandMenuItemEnum[key as keyof typeof VCSCommandMenuItemEnum];
        let label: string;
        let description: string;
        let kind: vscode.QuickPickItemKind;
        switch (enumValue) {
          case VCSCommandMenuItemEnum.SelectMode:
            label = `${enumValue}`;
            description = `Change CurrentMode: ${this.data.stateManager.currentMode}`;
            break;
          case VCSCommandMenuItemEnum.SelectQueryAgentCommand:
            label = `${enumValue}`;
            description = `Change CurrentQueryAgentCommand: ${this.data.stateManager.currentQueryAgentCommand}`;
            break;
          case VCSCommandMenuItemEnum.SelectQueryEngines:
            label = `${enumValue}`;
            description = 'Select CurrentQueryEngines';
            break;
          case VCSCommandMenuItemEnum.ShowLogs:
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

  get queryEnginesMenuItems(): vscode.QuickPickItem[] {
    const items: vscode.QuickPickItem[] = [];
    const currentQueryEngines = this.data.stateManager.currentQueryEngines;
    for (const key in QueryEngineNamesEnum) {
      if (QueryEngineNamesEnum.hasOwnProperty(key)) {
        const enumNameValue = QueryEngineNamesEnum[key as keyof typeof QueryEngineNamesEnum];
        const enumFlagValue = QueryEngineFlagsEnum[key as keyof typeof QueryEngineFlagsEnum];
        let label: string;
        let description: string;
        switch (enumNameValue) {
          case QueryEngineNamesEnum.ChatGPT:
            label = `${enumNameValue}`;
            description =
              `Toggle ${enumNameValue}, currently ` + (currentQueryEngines & enumFlagValue ? 'enabled' : 'disabled');
            break;
          case QueryEngineNamesEnum.Claude:
            label = `${enumNameValue}`;
            description =
              `Toggle ${enumNameValue}, currently ` + (currentQueryEngines & enumFlagValue ? 'enabled' : 'disabled');
            break;
          case QueryEngineNamesEnum.Bard:
            label = `${enumNameValue}`;
            description =
              `Toggle ${enumNameValue}, currently ` + (currentQueryEngines & enumFlagValue ? 'enabled' : 'disabled');
            break;
          case QueryEngineNamesEnum.Grok:
            label = `${enumNameValue}`;
            description =
              `Toggle ${enumNameValue}, currently ` + (currentQueryEngines & enumFlagValue ? 'enabled' : 'disabled');
            break;
          default:
            continue;
        }
        items.push({ label, description });
      }
    }
    return items;
  }
  get queryAgentCommandMenuItems(): vscode.QuickPickItem[] {
    const items: vscode.QuickPickItem[] = [];
    const currentQueryAgentCommand = this.data.stateManager.currentQueryAgentCommand;

    for (const key in QueryAgentCommandMenuItemEnum) {
      if (QueryAgentCommandMenuItemEnum.hasOwnProperty(key)) {
        const enumValue = QueryAgentCommandMenuItemEnum[key as keyof typeof QueryAgentCommandMenuItemEnum];
        let label: string;
        let description: string;
        let kind: vscode.QuickPickItemKind;
        switch (enumValue) {
          case QueryAgentCommandMenuItemEnum.Chat:
            label = `${enumValue}`;
            description = 'Chat' + (currentQueryAgentCommand === QueryAgentCommandMenuItemEnum.Chat ? ' ✓' : ' ');
            break;
          case QueryAgentCommandMenuItemEnum.Fix:
            label = `${enumValue}`;
            description = 'Fix' + (currentQueryAgentCommand === QueryAgentCommandMenuItemEnum.Fix ? ' ✓' : ' ');
            break;
          case QueryAgentCommandMenuItemEnum.Test:
            label = `${enumValue}`;
            description = 'Test' + (currentQueryAgentCommand === QueryAgentCommandMenuItemEnum.Test ? ' ✓' : ' ');
            break;
          case QueryAgentCommandMenuItemEnum.Document:
            label = `${enumValue}`;
            description =
              'Document' + (currentQueryAgentCommand === QueryAgentCommandMenuItemEnum.Document ? ' ✓' : ' ');
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
