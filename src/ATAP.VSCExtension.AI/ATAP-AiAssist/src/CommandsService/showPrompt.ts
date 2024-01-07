import { logFunction } from '@Decorators/Decorators';
import { LogLevel, ILogger } from '@Logger/index';
import { DataService, IData } from '@DataService/DataService';

import * as vscode from 'vscode';

export function showPrompt(logger: ILogger, data: IData): void {
  const document = data.getTemporaryPromptDocument() as vscode.TextDocument;
  vscode.window.showTextDocument(document);
}
