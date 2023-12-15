import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { logConstructor } from '@Decorators/index';

import { IData } from '@DataService/index';

@logConstructor
export class ExternalDataVetting {
  constructor(private logger: ILogger) {}

  AttachListener(data: IData): void {
    const eventEmitter = data.eventManager.GetEventEmitter();
    // Connect the listener to the event emitter
    eventEmitter.on('ExternalDataReceived', (data: any, EventToRaiseMagicString: string) => {
      // Vet all external data here
      // Use a third-party library to vet the data
      this.logger.log(`ToDo:add data vetting for ${data}`, LogLevel.Debug);
      // If the data is valid, raise the follwon event
      eventEmitter.emit(EventToRaiseMagicString, data);
    });
  }
}
