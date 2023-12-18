import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';
import { IDataService, IData, IStateManager, IConfigurationData } from '@DataService/index';

import { EventEmitter } from 'events';

export interface IEventManager {
  getEventEmitter(): EventEmitter;
  dispose(): void;
}

@logConstructor
export class EventManager implements IEventManager {
  private eventEmitter: EventEmitter;
  private disposed = false;
  constructor(
    private readonly logger: ILogger,
    private readonly extensionContext: vscode.ExtensionContext, //, // readonly folder: vscode.WorkspaceFolder,
    private readonly configurationData: IConfigurationData,
  ) {
    //ToDo: wrap in a try/catch
    this.eventEmitter = new EventEmitter();
  }

  public getEventEmitter() {
    return this.eventEmitter;
  }

  dispose() {
    if (!this.disposed) {
      // release any resources
      this.disposed = true;
    }
  }
}
