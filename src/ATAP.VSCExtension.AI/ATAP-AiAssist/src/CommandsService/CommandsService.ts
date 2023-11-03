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
import { showVSCEnvironment } from './showVSCEnvironment';
import { sendFilesToAPI } from './sendFilesToAPI';

export class CommandsService {
  private disposables: vscode.Disposable[] = [];
  private message: string;

  constructor(private logger: ILogger, private context: vscode.ExtensionContext  ) {
    this.message = 'starting CommandsService constructor';
    this.logger.log(this.message, LogLevel.Trace);
    //this.registerCommands();
    this.message = 'leaving CommandsService constructor';
    this.logger.log(this.message, LogLevel.Trace);
  }

  private registerCommands(): void {
    this.message = 'starting registerCommands';
    this.logger.log(this.message, LogLevel.Trace);

    this.message = 'registering showVSCEnvironment';
    this.logger.log(this.message, LogLevel.Trace);
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

  }

  public getDisposables(): vscode.Disposable[] {
    return this.disposables;
  }
}
