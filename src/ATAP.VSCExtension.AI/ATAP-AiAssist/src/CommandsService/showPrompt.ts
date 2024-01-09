import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { DataService, IData } from '@DataService/DataService';

import * as vscode from 'vscode';

export function showPrompt(logger: ILogger, data: IData): void {
  const document = data.getTemporaryPromptDocument() as vscode.TextDocument;
  vscode.window.showTextDocument(document);
}
