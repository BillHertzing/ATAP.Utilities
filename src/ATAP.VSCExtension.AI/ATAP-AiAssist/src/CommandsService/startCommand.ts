import * as vscode from "vscode";
import { LogLevel, ILogger, Logger } from "@Logger/index";
import { DetailedError, HandleError } from "@ErrorClasses/index";
import { logConstructor, logMethod, logAsyncFunction } from "@Decorators/index";

export function startCommand(logger: ILogger): void {
  let message: string = "starting commandID startCommand";
  logger.log(message, LogLevel.Debug);
}
