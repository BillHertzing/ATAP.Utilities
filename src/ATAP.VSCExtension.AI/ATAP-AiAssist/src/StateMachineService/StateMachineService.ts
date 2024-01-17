import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction } from '@Decorators/index';
import { ISerializationStructure, stringifyWithCircularReference, fromJson, fromYaml } from '@Serializers/index';
import { Actor, createActor, assign, createMachine, fromCallback, StateMachine, fromPromise } from 'xstate';
import { resolve } from 'path';

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
  SupportedQueryEnginesEnum,
} from '@BaseEnumerations/index';

// common type

export type LoggerDataT = { logger: ILogger; data: IData };

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

import { QuickPickEventPayload } from './quickPickActorLogic';

import { primaryMachine } from './PrimaryMachine';

// export interface IUpdateUIInput extends IQuickPickInput {
//   priorMode: ModeMenuItemEnum;
//   currentMode: ModeMenuItemEnum;
//   priorQueryAgentCommand: QueryAgentCommandMenuItemEnum;
//   currentQueryAgentCommand: QueryAgentCommandMenuItemEnum;
// }
// export class UpdateUIInput implements IUpdateUIInput {
//   constructor(
//     readonly priorMode: ModeMenuItemEnum,
//     readonly currentMode: ModeMenuItemEnum,
//     readonly priorQueryAgentCommand: QueryAgentCommandMenuItemEnum,
//     readonly currentQueryAgentCommand: QueryAgentCommandMenuItemEnum,
//     readonly kindOfEnumeration: QuickPickEnumeration,
//     readonly logger: ILogger,
//     readonly data: IData,
//   ) {}
// }

// The enumeration types for which the quickPickActorLogic can be used
// export type PickableEnumerationTypes = VCSCommandMenuItemEnum | ModeMenuItemEnum | QueryAgentCommandMenuItemEnum;

//
export interface IStateMachineService {
  quickPick(data: QuickPickEventPayload): void;
  start(): void;
  disposeAsync(): void;
}

@logConstructor
export class StateMachineService implements IStateMachineService {
  private readonly extensionID: string;
  private readonly extensionName: string;

  private dummy: string = 'dummy';
  private primaryActor;

  private disposed = false;

  constructor(
    private readonly logger: ILogger,
    private readonly data: IData,
    private readonly extensionContext: vscode.ExtensionContext,
  ) {
    this.extensionID = extensionContext.extension.id;
    this.extensionName = this.extensionID.split('.')[1];

    this.primaryActor = createActor(primaryMachine, {
      input: { logger: this.logger, data: this.data, dummy: this.dummy },
      // for Debugging
      inspect: (inspEvent) => {
        // this.logger.log(
        //   `StateMachineService inspect received inspEvent.type = ${inspEvent.type}`, //${stringifyWithCircularReference(inspEvent)}`,
        //   LogLevel.Debug,
        // );
        if (inspEvent.type === '@xstate.snapshot') {
          this.logger.log(
            `StateMachineService inspect received event type @xstate.snapshot. event.type: ${inspEvent.event.type} event.input: ${inspEvent.event.input} event.output: ${inspEvent.event.output} snapshot.status: ${inspEvent.snapshot.status}`,
            LogLevel.Debug,
          );
        } else if (inspEvent.type === '@xstate.actor') {
          this.logger.log(
            `StateMachineService inspect received event type @xstate.actor. actorRef.id: ${
              inspEvent.actorRef.id
            } rootId: ${inspEvent.rootId.toString()}`,
            LogLevel.Debug,
          );
        } else if (inspEvent.type === '@xstate.event') {
          this.logger.log(
            `StateMachineService inspect received event type @xstate.event. event.type: ${inspEvent.event.type} event.input: ${inspEvent.event.input} event.output: ${inspEvent.event.output}`,
            LogLevel.Debug,
          );
        }
      },
    });
  }
  @logFunction
  quickPick(payload: QuickPickEventPayload): void {
    this.primaryActor.send({ type: 'quickPickEvent', data: payload });
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
//     src: queryAgentCommandMenuLogic,
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
//   actors: { queryAgentCommandMenuLogic }
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
//       queryAgentCommandMenu: {
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

//  const queryAgentCommandMenuLogic = fromPromise(async () => {
//   return QueryAgentCommandMenuItemEnum.Chat;
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
