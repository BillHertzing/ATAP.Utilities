import { ILogger, LogLevel } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction } from '@Decorators/index';

// an enumeration to represent the StatusMenuIItem choices
export enum StatusMenuItemEnum {
  Mode = 'mode',
  Command = 'command',
  Sources = 'sources',
  Logs = 'logs',
}
export interface IStateMachineService {
  getNextState(): string;
  getCurrentState(): string;
}

export class StateMachineService implements IStateMachineService {
  constructor(
    private readonly logger: ILogger,
    private readonly data: IData,
  ) {
    //attach a listener to the 'handleStatusMenuResults' event
    this.data.eventManager.getEventEmitter().on('handleStatusMenuResults', (statusMenuItem: StatusMenuItemEnum) => {
      this.logger.log(
        `StateMachineService onHandleStatusMenuResults received ${statusMenuItem.toString()}`,
        LogLevel.Debug,
      );
      this.handleStatusMenuResults(statusMenuItem);
    });
  }

  @logFunction
  getNextState(): string {
    return 'next state';
  }

  @logFunction
  getCurrentState(): string {
    return 'current state';
  }

  @logFunction
  handleStatusMenuResults(statusMenuItem: StatusMenuItemEnum): void {
    this.logger.log(`handleStatusMenuResults received ${statusMenuItem.toString()}`, LogLevel.Debug);
    // switch on the statusMenuItem
    switch (statusMenuItem) {
      case StatusMenuItemEnum.Mode:
        this.logger.log(`ToDo: handle ${StatusMenuItemEnum.Mode}`, LogLevel.Debug);
        break;
      case StatusMenuItemEnum.Command:
        this.logger.log(`ToDo: handle ${StatusMenuItemEnum.Command}`, LogLevel.Debug);
        break;
      case StatusMenuItemEnum.Sources:
        this.logger.log(`ToDo: handle ${StatusMenuItemEnum.Sources}`, LogLevel.Debug);
        break;
      case StatusMenuItemEnum.Logs:
        this.logger.log(`handle ${StatusMenuItemEnum.Logs}`, LogLevel.Debug);
        this.logger.getChannelInfo('ATAP-AiAssist')?.outputChannel?.show(true);
        break;
      default:
        // ToDo: investigate a better way than throwing inside an event handler....
        throw new DetailedError(` onHandleStatusMenuResults received an unexpected statusMenuItem: ${statusMenuItem}`);
        break;
    }
    // ToDo: is there anything we need to do after handling the statusMenuItem? Visual feedback? etc.
  }
}
