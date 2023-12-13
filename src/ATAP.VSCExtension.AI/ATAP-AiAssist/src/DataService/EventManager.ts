import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

import { EventEmitter } from 'events';

export interface IEventManager {
  GetEventEmitter(): EventEmitter;
}

@logConstructor
export class EventManager implements IEventManager {
  private eventEmitter: EventEmitter;

  constructor(
    private readonly logger: ILogger,
    private readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
    private readonly configurationData: IConfigurationData,
  ) {
    //ToDo: wrap in a try/catch
    this.eventEmitter = new EventEmitter();
  }

  public GetEventEmitter() {
    return this.eventEmitter;
  }
}
