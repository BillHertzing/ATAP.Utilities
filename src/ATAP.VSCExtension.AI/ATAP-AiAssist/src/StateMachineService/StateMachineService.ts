import * as vscode from 'vscode';
import { ILogger, Logger, LogLevel } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction } from '@Decorators/index';
import { ISerializationStructure, fromJson, fromYaml } from '@Serializers/index';
import { Actor, createActor, assign, createMachine, fromCallback, StateMachine, fromPromise } from 'xstate';
import { resolve } from 'path';
import { IPickItems, PickItems } from '@DataService/PickItems';
import { primaryMachine } from './PrimaryMachine';
import { QuickPickEnumeration } from './PrimaryMachine';

// Common interface for input to actor and action logic
export interface ILoggerData {
  readonly logger: ILogger;
  readonly data: IData;
}
export class LoggerData implements ILoggerData {
  constructor(
    readonly logger: ILogger,
    readonly data: IData,
  ) {}
}
export interface IQuickPickInput extends ILoggerData {
  kindOfEnumeration: QuickPickEnumeration;
}
export class QuickPickInput implements IQuickPickInput {
  constructor(
    readonly kindOfEnumeration: QuickPickEnumeration,
    readonly logger: ILogger,
    readonly data: IData,
  ) {}
}

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

// The enumeration types for which the quickPickActorLogic can be used
export type PickableEnumerationTypes = StatusMenuItemEnum | ModeMenuItemEnum | CommandMenuItemEnum;

//
export interface IStateMachineService {
  quickPick(kindOfEnumeration: QuickPickEnumeration): void;
  start(): void;
  disposeAsync(): void;
}

@logConstructor
export class StateMachineService implements IStateMachineService {
  private readonly extensionID: string;
  private readonly extensionName: string;

  private primaryActor;

  private disposed = false;

  constructor(
    private readonly logger: ILogger,
    private readonly data: IData,
    private readonly extensionContext: vscode.ExtensionContext,
  ) {
    this.extensionID = extensionContext.extension.id;
    this.extensionName = this.extensionID.split('.')[1];

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

    this.primaryActor = createActor(primaryMachine, { input: { loggerData: new LoggerData(this.logger, this.data) } });
  }
  @logFunction
  quickPick(kindOfEnumeration: QuickPickEnumeration): void {
    this.primaryActor.send({ type: 'quickPickEvent', kindOfEnumeration });
  }
  @logFunction
  testActorsaveFile(): void {
    // placeholder
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
  start(): void {
    this.primaryActor.start();
  }

  @logFunction
  handleStatusMenuResults(statusMenuItem: StatusMenuItemEnum): void {
    this.logger.log(`handleStatusMenuResults received ${statusMenuItem.toString()}`, LogLevel.Debug);
    // switch on the statusMenuItem
    switch (statusMenuItem) {
      case StatusMenuItemEnum.Mode:
        this.logger.log(`handle ${StatusMenuItemEnum.Mode}`, LogLevel.Debug);
        // call showModeMenuAsync
        vscode.commands.executeCommand(`${this.extensionName}.showModeMenuAsync`);
        break;
      case StatusMenuItemEnum.Command:
        this.logger.log(`ToDo: handle ${StatusMenuItemEnum.Command}`, LogLevel.Debug);
        // call showCommandMenuAsync
        vscode.commands.executeCommand(`${this.extensionName}.showCommandMenuAsync`);

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
    this.data.stateManager.currentMode = modeMenuItem;
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
    this.logger.log(`CurrentMode is now ${this.data.stateManager.currentMode}`, LogLevel.Debug);
  }

  // handleCommandMenuResults
  @logFunction
  handleCommandMenuResults(commandMenuItem: CommandMenuItemEnum): void {
    this.logger.log(`handleCommandMenuResults received ${commandMenuItem.toString()}`, LogLevel.Debug);
    // make this the currentMode
    this.data.stateManager.currentCommand = commandMenuItem;
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
    this.logger.log(`CurrentCommand is now ${this.data.stateManager.currentCommand}`, LogLevel.Debug);
  }

  @logAsyncFunction
  async disposeAsync() {
    if (!this.disposed) {
      // Dispose of the primary actor
      this.primaryActor.send({ type: 'disposeEvent' });
      // ToDo: await the transition to the 'Done' state
      this.disposed = true;
    }
  }
}

// UpdateCurrentModeStateEntryAction: ({ context, event }) => {
//   context.logger.log(`UpdateCurrentModeStateEntryAction called`, LogLevel.Debug);
//   context.logger.log(`event type: ${event.type}`, LogLevel.Debug);
// },
// UpdateCurrentModeStateExitAction: ({ context, event }) => {
//   context.logger.log(`UpdateCurrentModeStateExitAction called`, LogLevel.Debug);
//   context.logger.log(`event type: ${event.type}`, LogLevel.Debug);
// },

// guards:{
//   'isNotNull': ({context}) => {
//     return !context.pick;
//   }
// },

// "Vet User Input": {
//   invoke:{
//     id:"Vet User Input Logic",
//     src: commandMenuLogic,
//     onDone:{
//       target:"UpdateMode",
//       actions: assign({
//         modeMenuItem: (_, event) => event.data,
//       }),
//     },
//     onError:{
//       target:"New state 1",
//       actions: assign({
//         errorMessage: (_, event) => event.data,
//       }),
//     },
//   }
//   on: {
//     handleMenuResults: {
//       target: "UpdateMode",
//     },
//     maliciousInputDetected: {
//       target: "New state 1",
//     },
//   },
// },
//     Done: {
//       type: 'final',
//     },
//     UpdateMode: {
//       on: {
//         always: {
//           target: 'FireModeChanged',
//         },
//       },
//     },
//     'New state 1': {},
//     FireModeChanged: {
//       always: {
//         target: 'Done',
//       },
//     },
//   },
// },

// @logFunction
// async queryAsync ():Promise<void> {
//   return new Promise((resolve, reject) => {
//     this.primaryActor.send({ type: 'query' });
//     this.primaryActor.onTransition((state) => {
//       if (state.matches('success')) {
//         resolve();
//       } else if (state.matches('failure')) {
//         reject();
//       }
//     });
//   });
// }

// setup({
//   actors: { commandMenuLogic }
// }).createMachine({
//     // cspell:ignore-next-line
//     id: 'primaryMachine',
//     initial: 'preinitialize',
//     context: this.data,
//     states: {
//       preinitialize: {
//         on: {
//           Initialize: 'initializing',
//         },
//       },
//       initializing: {
//         on: {
//           InitializationComplete: 'idle',
//         },
//       },
//        idle: {
//         on: {
//           QUERY: 'querying',
//           COMMANDMENU: 'commandMenu',
//         },
//       },
//       commandMenu: {
//         on: {
//           ShowQuickPickAndWaitForCompletion: 'idle',
//           COMMANDMENU: 'commandMenu',
//         },
//       },
//       querying: {
//         on: {
//           QUERY: 'querying',
//           SUCCESS: 'success',
//           FAILURE: 'failure',
//         },
//       },
//       success: {
//         on: {
//           QUERY: 'querying',
//         },
//       },
//       failure: {
//         on: {
//           QUERY: 'querying',
//         },
//       },
//     },
//   });

// Create the primary actor and start it
//this.primaryActor = createActor(this.primaryMachine).start();

//  const commandMenuLogic = fromPromise(async () => {
//   return CommandMenuItemEnum.Chat;
// });

// interface IVetUnsafeData {
//   unsafeData: string;
//   subsequentEvent: Event;
// }

// const VetUserInputLogic = fromPromise<
//   {
//     safeUserInputData: string;
//   },
//   { unsafeUserInputData: string }
// >((input: { unsafeUserInputData: string }) => {
//   //const safeUserinputData = await // send string to 3rd party virus scanner;
//   const safeUserinputData = input.unsafeUserInputData;
// });

// | { type: 'UserInputComplete' }
// | { type: 'handleMenuResults' }
// | { type: 'maliciousInputDetected' },

// UpdateCurrentModeState: {
//   entry: [{
//     type: 'UpdateCurrentModeStateEntryAction',
//   }],
//   exit: {
//     type: 'UpdateCurrentModeStateExitAction',
//   },
//   invoke: {
//     src: 'UpdateCurrentModeActor',
//     input: ({ context }) => ({
//       logger: context.logger,
//       data: context.data,
//       pick: ModeMenuItemEnum
//     }),
//     onDone: {
//       target: 'Idle',
//     },
//   },
//   // always: {
//   //   target: 'Idle',
//   // },
// },
