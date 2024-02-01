import * as vscode from 'vscode';

import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { StringBuilder } from '@Utilities/index';

import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

import { IQueryEngineChatGPT, QueryEngineChatGPT } from './QueryEngineChatGPT';

export interface IQueryEngine {
  sendQueryAsync(textToSubmit: string, cTSToken: vscode.CancellationToken): Promise<void>;
}

// @logConstructor
export abstract class QueryEngine implements IQueryEngine {
  constructor(
    private readonly logger: ILogger,
    private readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
    private readonly configurationData: IConfigurationData,
  ) {}
  abstract sendQueryAsync(textToSubmit: string, cTSToken: vscode.CancellationToken): Promise<void>;
}
