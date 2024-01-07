import * as vscode from 'vscode';

import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { StringBuilder } from '@Utilities/index';

import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

import { IQueryEngineChatGPT, QueryEngineChatGPT } from './QueryEngineChatGPT';

export interface IQueryEngine {
  QueryAsync(): Promise<void>;
  ConstructQueryAsync(): Promise<void>;
  SendQueryAsync(textToSubmit: string): Promise<void>;
}

// @logConstructor
export abstract class QueryEngine implements IQueryEngine {
  constructor(
    private readonly logger: ILogger,
    private readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
    private readonly configurationData: IConfigurationData,
  ) {}
  abstract QueryAsync(): Promise<void>;
  abstract ConstructQueryAsync(): Promise<void>;
  abstract SendQueryAsync(textToSubmit: string): Promise<void>;
}

export interface IQueryResultBase {
  resultContent: StringBuilder;
  resultSnapshot: StringBuilder;
  isValid: boolean; // Indicates the validity of the data
  errorMessage?: string; // Optional field for error message
}

// @logConstructor
export abstract class QueryResultBase implements IQueryResultBase {
  constructor(
    readonly resultContent: StringBuilder,
    readonly resultSnapshot: StringBuilder,
    readonly isValid: boolean,
    readonly errorMessage?: string,
  ) {}
}
