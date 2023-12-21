import * as vscode from 'vscode';
import { ILogger, Logger, LogLevel } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction } from '@Decorators/index';
import { ISerializationStructure, fromJson, fromYaml } from '@Serializers/index';
import { IPickItemsInitializer, PickItemsInitializer } from './PickItemsInitializer';

// an enumeration to represent the StatusMenuItem choices
export enum StatusMenuItemEnum {
  Mode = 'Mode',
  Command = 'Command',
  Sources = 'Sources',
  ShowLogs = 'ShowLogs',
}

// an enumeration to represent the ModeItem choices
export enum ModeMenuItemEnum {
  Workspace = 'Workspace',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  VSCode = 'VSCode',
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 'ChatGPT',
  Claude = 'Claude',
}

// an enumeration to represent the CommandItem choices
export enum CommandMenuItemEnum {
  Chat = 'Chat',
  Fix = 'Fix',
  Test = 'Test',
  Document = 'Document',
}

export interface IStateMachineService {
  initialize(): void;
  readonly pickItemsInitializer: IPickItemsInitializer;
  getNextState(): string;
  getCurrentState(): string;
}

export class StateMachineService implements IStateMachineService {
  readonly pickItemsInitializer: IPickItemsInitializer = new PickItemsInitializer();

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

    //attach a listener to the 'handleModeMenuResults' event
    this.data.eventManager.getEventEmitter().on('handleModeMenuResults', (modeMenuItem: ModeMenuItemEnum) => {
      this.logger.log(
        `StateMachineService onHandleModeMenuResults received ${modeMenuItem.toString()}`,
        LogLevel.Debug,
      );
      this.handleModeMenuResults(modeMenuItem);
    });

    //attach a listener to the 'handleCommandMenuResults' event
    this.data.eventManager.getEventEmitter().on('handleCommandMenuResults', (commandMenuItem: CommandMenuItemEnum) => {
      this.logger.log(
        `StateMachineService onHandleCommandMenuResults received ${commandMenuItem.toString()}`,
        LogLevel.Debug,
      );
      this.handleCommandMenuResults(commandMenuItem);
    });
  }

  static create(
    logger: ILogger,
    extensionContext: vscode.ExtensionContext,
    data: IData,
    callingModule: string,
    initializationStructure?: ISerializationStructure,
  ): StateMachineService {
    Logger.staticLog(`StateMachineService.create called`, LogLevel.Debug);

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
  initialize(): void {}

  @logFunction
  getNextState(): string {
    return 'next state';
  }

  @logFunction
  getCurrentState(): string {
    return 'current state';
  }

  get PickItemsInitializer(): IPickItemsInitializer {
    return this.pickItemsInitializer;
  }

  @logFunction
  handleStatusMenuResults(statusMenuItem: StatusMenuItemEnum): void {
    this.logger.log(`handleStatusMenuResults received ${statusMenuItem.toString()}`, LogLevel.Debug);
    // switch on the statusMenuItem
    switch (statusMenuItem) {
      case StatusMenuItemEnum.Mode:
        this.logger.log(`handle ${StatusMenuItemEnum.Mode}`, LogLevel.Debug);
        // call showModeMenuAsync
        vscode.commands.executeCommand('atap-aiassist.showModeMenuAsync');
        break;
      case StatusMenuItemEnum.Command:
        this.logger.log(`ToDo: handle ${StatusMenuItemEnum.Command}`, LogLevel.Debug);
        // call showCommandMenuAsync
        vscode.commands.executeCommand('atap-aiassist.showCommandMenuAsync');

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

  // handleModeMenuResults
  @logFunction
  handleModeMenuResults(modeMenuItem: ModeMenuItemEnum): void {
    this.logger.log(`handleModeMenuResults received ${modeMenuItem.toString()}`, LogLevel.Debug);
    // make this the currentMode
    this.data.stateManager.setCurrentMode(modeMenuItem);
    // switch on the modeMenuItem
    switch (modeMenuItem) {
      case ModeMenuItemEnum.Workspace:
        this.logger.log(`ToDo: handle ${ModeMenuItemEnum.Workspace}`, LogLevel.Debug);
        break;
      case ModeMenuItemEnum.VSCode:
        this.logger.log(`ToDo: handle ${ModeMenuItemEnum.VSCode}`, LogLevel.Debug);
        break;
      case ModeMenuItemEnum.ChatGPT:
        this.logger.log(`ToDo: handle ${ModeMenuItemEnum.ChatGPT}`, LogLevel.Debug);
        break;
      case ModeMenuItemEnum.Claude:
        this.logger.log(`ToDo: handle ${ModeMenuItemEnum.Claude}`, LogLevel.Debug);
        break;
      default:
    }
    this.logger.log(`CurrentMode is now ${this.data.stateManager.getCurrentMode()}`, LogLevel.Debug);
  }

  // handleCommandMenuResults
  @logFunction
  handleCommandMenuResults(commandMenuItem: CommandMenuItemEnum): void {
    this.logger.log(`handleCommandMenuResults received ${commandMenuItem.toString()}`, LogLevel.Debug);
    // make this the currentMode
    this.data.stateManager.setCurrentCommand(commandMenuItem);
    // switch on the commandMenuItem
    switch (commandMenuItem) {
      case CommandMenuItemEnum.Chat:
        this.logger.log(`ToDo: handle ${CommandMenuItemEnum.Chat}`, LogLevel.Debug);
        break;
      case CommandMenuItemEnum.Fix:
        this.logger.log(`ToDo: handle ${CommandMenuItemEnum.Fix}`, LogLevel.Debug);
        break;
      case CommandMenuItemEnum.Test:
        this.logger.log(`ToDo: handle ${CommandMenuItemEnum.Test}`, LogLevel.Debug);
        break;
      case CommandMenuItemEnum.Document:
        this.logger.log(`ToDo: handle ${CommandMenuItemEnum.Document}`, LogLevel.Debug);
        break;
      default:
    }
    this.logger.log(`CurrentCommand is now ${this.data.stateManager.getCurrentCommand()}`, LogLevel.Debug);
  }
}
