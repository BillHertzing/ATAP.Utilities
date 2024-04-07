import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

export function startCommand(logger: ILogger): void {
  let message: string = 'starting commandID startCommand';
  logger.log(message, LogLevel.Debug);
}
