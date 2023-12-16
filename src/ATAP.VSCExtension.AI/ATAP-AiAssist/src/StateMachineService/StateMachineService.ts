import * as vscode from 'vscode';
import { ILogger, LogLevel } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction } from '@Decorators/index';
import { ISerializationStructure, fromJson, fromYaml } from '@Serializers/index';

// an enumeration to represent the StatusMenuItem choices
export enum StatusMenuItemEnum {
  Mode = 'Mode',
  Command = 'Command',
  Sources = 'Sources',
  ShowLogs = 'ShowLogs',
}

// an enumeration to represent the ModeItem choices
export enum ModeMenuItemEnum {
  Workspace,
  // eslint-disable-next-line @typescript-eslint/naming-convention
  VSCode,
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT,
  Claude,
}

// an enumeration to represent the CommandItem choices
export enum CommandMenuItemEnum {
  Chat,
  Fix,
  Test,
  Document,
}

export interface IStateMachineService {
  getNextState(): string;
  getCurrentState(): string;
}

export class StateMachineService implements IStateMachineService {
  constructor(
    private readonly logger: ILogger,
    private readonly data: IData,
    private readonly extensionContext: vscode.ExtensionContext,
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
  static Create(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    data: IData,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
  ): StateMachineService {
    let _obj: StateMachineService | null;
    if (initializationStructure) {
      try {
        // ToDo: deserialize based on contents of structure
        _obj = StateMachineService.convertFrom_yaml(initializationStructure.value);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(
            `${callingModule}: create stateMachineService from initializationStructure using convertFrom_xxx -> }`,
            e,
          );
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(
            `${callingModule}: create stateMachineService from initializationStructure using convertFrom_xxx threw something other than a polymorphous Error`,
          );
        }
      }
      if (_obj === null) {
        throw new Error(
          `${callingModule}: create stateMachineService from initializationStructure using convertFrom_xxx produced a null`,
        );
      }
      return _obj;
    } else {
      try {
        _obj = new StateMachineService(logger, data, extensionContext);
      } catch (e) {
        if (e instanceof Error) {
          throw new DetailedError(`${callingModule}: create stateMachineService from initializationStructure -> }`, e);
        } else {
          // ToDo:  investigation to determine what else might happen
          throw new Error(`${callingModule}: create stateMachineService from initializationStructure`);
        }
      }
      return _obj;
    }
  }

  static convertFrom_json(json: string): StateMachineService {
    return fromJson<StateMachineService>(json);
  }

  static convertFrom_yaml(yaml: string): StateMachineService {
    return fromYaml<StateMachineService>(yaml);
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
      case StatusMenuItemEnum.ShowLogs:
        this.logger.log(`handle ${StatusMenuItemEnum.ShowLogs}`, LogLevel.Debug);
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
