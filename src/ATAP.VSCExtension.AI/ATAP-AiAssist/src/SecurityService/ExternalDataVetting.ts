import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger } from '@Logger/index';
import { logConstructor, logFunction } from '@Decorators/index';

import { EventEmitter } from 'events';

export interface IExternalDataVetting {
  AttachListener(eventEmitter: EventEmitter): void;
}

@logConstructor
export class ExternalDataVetting {
  constructor(private logger: ILogger) {}

  @logFunction
  AttachListener(eventEmitter: EventEmitter): void {
    // Connect the listener to the event emitter
    eventEmitter.on('ExternalDataReceived', (data: any, EventToRaiseMagicString: string) => {
      // Vet all external data here
      // Use a third-party library to vet the data
      this.logger.log(`ToDo:add data vetting for ${data}`, LogLevel.Debug);
      // If the data is valid, raise the follow-on event as specified
      eventEmitter.emit(EventToRaiseMagicString, data);
    });
  }
}
