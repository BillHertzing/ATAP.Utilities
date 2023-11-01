import {
  LogLevel,
  ChannelInfo,
  ILogger,
  Logger,
  getLoggerLogLevelFromSettings,
  setLoggerLogLevelFromSettings,
  getDevelopmentLoggerLogLevelFromSettings,
  setDevelopmentLoggerLogLevelFromSettings,
} from '../Logger';
import * as vscode from 'vscode';

import { startCommand } from './startCommand';

export class CommandsService {
  private disposables: vscode.Disposable[] = [];

  constructor(private logger: ILogger) {
    this.registerCommands();
  }

  private registerCommands(): void {
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.showVSCEnvironment,', () => {
        let message: string = 'registering commandID showVSCEnvironment';
        this.logger.log(message, LogLevel.Debug);
        showVSCEnvironment(this.logger);
      }),
    );

    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.startCommand,', () => {
        let message: string = 'registering commandID startCommand';
        this.logger.log(message, LogLevel.Debug);
        startCommand(this.logger);;
      }),
    );
  }

  public getDisposables(): vscode.Disposable[] {
    return this.disposables;
  }
}

function showVSCEnvironment(logger: ILogger): void {
  let message: string = 'starting commandID showVSCEnvironment';
  logger.log(message, LogLevel.Debug);
  const workspaceFolders = vscode.workspace.workspaceFolders;
  // Check if a workspace is open
  if (workspaceFolders && workspaceFolders.length > 0) {
    // Use the URI property to get the folder path
    message = `workspaceFolder = ${workspaceFolders[0].uri.fsPath} `;
  } else {
    message = 'No workspace folder open.';
  }
  const editor = vscode.window.activeTextEditor;
  if (editor) {
    const document = editor.document;
    const fileName = document.fileName;
    message += `; fileDirname = ${document.fileName}`;
  } else {
    message += '; No editor open';
  }
  logger.log(message, LogLevel.Debug);
}
