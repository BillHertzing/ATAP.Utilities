import { LogLevel, ILogger, Logger } from '@Logger/Logger';
import * as vscode from 'vscode';

import { startCommand } from './startCommand';
import { showVSCEnvironment } from './showVSCEnvironment';
import { sendFilesToAPI } from './sendFilesToAPI';
import { showQuickPickExample } from './showQuickPickExample';
import { quickPickFromSettings } from './quickPickFromSettings';
import { copyToSubmit } from './copyToSubmit';

export class CommandsService {
  private disposables: vscode.Disposable[] = [];
  private message: string;

  constructor(private logger: ILogger, private context: vscode.ExtensionContext) {
    this.message = 'starting CommandsService constructor';
    this.logger.log(this.message, LogLevel.Debug);
    this.registerCommands();
    this.message = 'leaving CommandsService constructor';
    this.logger.log(this.message, LogLevel.Debug);
  }

  private registerCommands(): void {
    this.message = 'starting registerCommands';
    this.logger.log(this.message, LogLevel.Debug);

    this.message = 'registering showVSCEnvironment';
    this.logger.log(this.message, LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.showVSCEnvironment', () => {
        let message: string = 'starting commandID showVSCEnvironment';
        this.logger.log(message, LogLevel.Debug);
        showVSCEnvironment(this.logger);
      }),
    );

    this.message = 'registering sendFilesToAPI';
    this.logger.log(this.message, LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.sendFilesToAPI', () => {
        let message: string = 'starting commandID sendFilesToAPI';
        this.logger.log(message, LogLevel.Debug);
        sendFilesToAPI(this.context, this.logger);
      }),
    );

    this.message = 'registering startCommand';
    this.logger.log(this.message, LogLevel.Trace);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.startCommand', () => {
        let message: string = 'starting commandID startCommand';
        this.logger.log(message, LogLevel.Debug);
        startCommand(this.logger);
      }),
    );

    this.message = 'registering showQuickPickExample';
    this.logger.log(this.message, LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.showQuickPickExample', async () => {
        let message: string = 'starting commandID showQuickPickExample';
        this.logger.log(message, LogLevel.Debug);
        try {
          const result = await showQuickPickExample(this.logger);
          message = `result.success = ${result.success}, result `;
          this.logger.log(message, LogLevel.Debug);
        } catch (e) {
          if (e instanceof Error) {
            // Report the error
            message = e.message;
          } else {
            // If e is not an instance of Error, you might want to handle it differently
            message = `An unknown error occurred, and the instance of (e) returned is of type ${typeof e}`;
          }
          this.logger.log(message, LogLevel.Error);
        }
      }),
    );

    this.message = 'registering quickPickFromSettings';
    this.logger.log(this.message, LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.quickPickFromSettings', async () => {
        let message: string = 'starting commandID quickPickFromSettings';
        this.logger.log(message, LogLevel.Debug);
        try {
          // ToDo: how to pass the string for 'setting' to the extension command
          // ToDo: the extensionId.setting that needs / contains the QuickPick setting
          let setting: string = 'CategoryCollection';
          const result = await quickPickFromSettings(this.logger, setting);
          message = `result.success = ${result.success}, result `;
          this.logger.log(message, LogLevel.Debug);
        } catch (e) {
          if (e instanceof Error) {
            // Report the error
            message = e.message;
          } else {
            // If e is not an instance of Error, you might want to handle it differently
            message = `An unknown error occurred, and the instance of (e) returned is of type ${typeof e}`;
          }
          this.logger.log(message, LogLevel.Error);
        }
      }),
    );

    this.message = 'registering copyToSubmit';
    this.logger.log(this.message, LogLevel.Debug);
    this.disposables.push(
      vscode.commands.registerCommand('atap-aiassist.copyToSubmit', async () => {
        let message: string = 'starting commandID copyToSubmit';
        this.logger.log(message, LogLevel.Debug);
        try {
          const result = await copyToSubmit(this.context, this.logger);
          message = `result.success = ${result.success}, result `;
          this.logger.log(message, LogLevel.Debug);
        } catch (e) {
          if (e instanceof Error) {
            // Report the error
            message = e.message;
          } else {
            // If e is not an instance of Error, you might want to handle it differently
            message = `An unknown error occurred, and the instance of (e) returned is of type ${typeof e}`;
          }
          this.logger.log(message, LogLevel.Error);
        }
      }),
    );


  }

  public getDisposables(): vscode.Disposable[] {
    return this.disposables;
  }
}
