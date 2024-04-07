import * as vscode from 'vscode';
import { DetailedError } from '@ErrorClasses/index';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { logConstructor, logFunction } from '@Decorators/index';

import { EventEmitter } from 'events';

export interface IExternalDataVetting {
  AttachListener(eventEmitter: EventEmitter): void;
}

@logConstructor
export class ExternalDataVetting {
  constructor(private readonly logger: ILogger) {
    this.logger = new Logger(this.logger, this.constructor.name);
    this.logger.log(`ExternalDataVetting.ctor Starting`, LogLevel.Trace);
    this.logger.log(`ExternalDataVetting.ctor Ending`, LogLevel.Trace);
  }

  AttachListener(eventEmitter: EventEmitter): void {
    this.logger.log(`AttachListener Starting`, LogLevel.Trace);
    // Connect the listener to the event emitter
    eventEmitter.on('ExternalDataReceived', (data: any, EventToRaiseMagicString: string) => {
      this.logger.log(`ExternalDataReceived Starting`, LogLevel.Trace);
      // Vet all external data here
      // ToDo: Use a third-party library to vet the data
      this.logger.log(`ToDo:add data vetting for ${data}`, LogLevel.Debug);
      // If the data is valid, raise the follow-on event as specified
      eventEmitter.emit(EventToRaiseMagicString, data);
      this.logger.log(`ExternalDataReceived Ending`, LogLevel.Trace);
    });
    this.logger.log(`AttachListener Ending`, LogLevel.Trace);
  }
}
