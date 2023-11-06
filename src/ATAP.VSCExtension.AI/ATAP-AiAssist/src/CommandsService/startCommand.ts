import { LogLevel, ILogger, Logger } from '@Logger/Logger';
import * as vscode from 'vscode';

export function startCommand(logger: ILogger): void {
  let message: string = 'starting commandID startCommand';
  logger.log(message, LogLevel.Debug);
}
