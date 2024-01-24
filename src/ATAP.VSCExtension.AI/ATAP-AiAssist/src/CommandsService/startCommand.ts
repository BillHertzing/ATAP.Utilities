import * as vscode from 'vscode';
import { LogLevel, IScopedLogger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

export function startCommand(logger: IScopedLogger): void {
  let message: string = 'starting commandID startCommand';
  logger.log(message, LogLevel.Debug);
}
