import * as vscode from "vscode";
import { LogLevel, ILogger, Logger } from "@Logger/index";
import { IData } from "@DataService/index";
import { DetailedError } from "@ErrorClasses/index";
import { logConstructor, logMethod, logAsyncFunction } from "@Decorators/index";
import {
  ISerializationStructure,
  stringifyWithCircularReference,
  fromJson,
  fromYaml,
} from "@Serializers/index";
import { QueryEngineNamesEnum } from "@BaseEnumerations/index";
import {
  Actor,
  ActorRef,
  AnyActorLogic,
  createActor,
  assign,
  createMachine,
  fromCallback,
  StateMachine,
  fromPromise,
  AnyStateMachine,
} from "xstate";
import { createBrowserInspector } from "@statelyai/inspect";

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
} from "@BaseEnumerations/index";

import { IQueryService } from "@QueryService/index";

import {
  IQuickPickEventPayload,
  IQueryMultipleEngineEventPayload,
} from "@StateMachineService/index";

import { primaryMachine } from "./primaryMachine";
import { inspector } from "@StateMachineService/inspector";
import { testMachine } from "./testMachine";

export interface IStateMachineService {
  quickPick(data: IQuickPickEventPayload): void;
  sendQuery(data: IQueryMultipleEngineEventPayload): void;
  sendTest(data: IQueryMultipleEngineEventPayload): void;
  start(): void;
  disposeAsync(): void;
}

@logConstructor
export class StateMachineService implements IStateMachineService {
  private readonly extensionID: string;
  private readonly extensionName: string;
  private readonly primaryMachineInspector = createBrowserInspector();
  private readonly primaryMachineInspectorLogger: ILogger;
  private readonly testMachineInspectorLogger: ILogger;
  private primaryActor: ActorRef<any, any, any> | undefined;
  private testActor;

  private disposed = false;

  constructor(
    private readonly logger: ILogger,
    private readonly data: IData,
    private readonly queryService: IQueryService,
    private readonly extensionContext: vscode.ExtensionContext,
  ) {
    this.logger = new Logger(this.logger, "StateMachineService");
    this.extensionID = extensionContext.extension.id;
    this.extensionName = this.extensionID.split(".")[1];
    const primaryMachineInspector = createBrowserInspector(); // This line produces the errorMessage
    this.primaryMachineInspectorLogger = new Logger(
      this.logger,
      "Inspector(Primary)",
    );
    this.primaryActor = createActor(primaryMachine, {
      input: {
        logger: this.logger,
        data: this.data,
        queryService: this.queryService,
      },
      // for Debugging
      inspect: (inspEvent) => {
        inspector(this.primaryMachineInspectorLogger, inspEvent);
      },
    });
    this.testMachineInspectorLogger = new Logger(
      this.logger,
      "Inspector(Test)",
    );
    let cancellationTokenSource = new vscode.CancellationTokenSource();
    this.testActor = createActor(testMachine, {
      input: {
        logger: this.logger,
        queryEngineName: QueryEngineNamesEnum.ChatGPT,
        queryString: "test",
        queryService: this.queryService,
        parent: this.primaryActor!,
        cTSToken: cancellationTokenSource.token,
      },
      // for Debugging

      inspect: (inspEvent) => {
        inspector(this.testMachineInspectorLogger, inspEvent);
        let _eventInput = "";
        let _eventData = "";
        let _eventOutput = "";
        let _inspEventEventType = "";
        if (inspEvent.type === "@xstate.snapshot") {
          switch (inspEvent.event.type) {
            case "queryEvent":
            case "xstate.init":
            case "xstate.done.actor.gatheringActor":
            case "xstate.promise.resolve":
              break;
            default:
              _inspEventEventType = "inspEvent.event.type is unknown";
          }
          this.logger.log(
            `StateMachineService inspect received inspEvent type @xstate.snapshot. event.type: ${inspEvent.event.type} ${inspEvent.event.input ? `event_input: ${inspEvent.event.input}` : ""}${inspEvent.event.output ? `event_output: ${inspEvent.event.output}` : ""}${_inspEventEventType ? _inspEventEventType : ""}  snapshot.status: ${inspEvent.snapshot.status}`,
            LogLevel.Trace,
          );
        } else if (inspEvent.type === "@xstate.actor") {
          this.logger.log(
            `StateMachineService inspect received inspEvent type @xstate.actor. actorRef.id: ${
              inspEvent.actorRef.id
            } rootId: ${inspEvent.rootId.toString()}`,
            LogLevel.Trace,
          );
        } else if (inspEvent.type === "@xstate.event") {
          const _preamble = `StateMachineService inspect received inspEvent type @xstate.event. event.type: ${inspEvent.event.type} ; actorRefID: ${inspEvent.actorRef.id} `;
          switch (inspEvent.event.type) {
            case "xstate.init":
            case "queryEvent":
            case "xstate.error.actor.queryMachine":
            case "xstate.promise.resolve":
            case "xstate.done.actor.gatheringActor":
              break;
            default:
              _inspEventEventType = "inspEvent.event.type is unknown";
          }
          this.logger.log(
            `${_preamble} ${inspEvent.event.type} ${inspEvent.event.input ? `event_input: ${inspEvent.event.input}` : ""}${inspEvent.event.data ? `event_data: ${inspEvent.event.data}` : ""}${inspEvent.event.output ? `event_output: ${inspEvent.event.output}` : ""}${_inspEventEventType ? _inspEventEventType : ""}`,
            LogLevel.Trace,
          );
        } else {
          this.logger.log(
            `StateMachineService inspect received unexpected event type ${inspEvent}`,
            LogLevel.Debug,
          );
        }
      },
    });
    // this.testActor.start();
  }
  @logMethod(LogLevel.Debug)
  quickPick(payload: IQuickPickEventPayload): void {
    this.primaryActor!.send({ type: "QUICKPICK_START", payload: payload });
  }
  @logMethod(LogLevel.Debug)
  sendQuery(payload: IQueryMultipleEngineEventPayload): void {
    this.primaryActor!.send({ type: "QUERY_START", payload: payload });
  }

  @logMethod(LogLevel.Debug)
  sendTest(payload: IQueryMultipleEngineEventPayload): void {
    this.testActor.send({ type: "QSE_START" });
  }

  @logMethod(LogLevel.Debug)
  testActorsaveFile(): void {
    // placeholder
  }

  // static create(
  //   logger: ILogger,
  //   extensionContext: vscode.ExtensionContext,
  //   data: IData,
  //   queryService: IQueryService,
  //   callingModule: string,
  //   initializationStructure?: ISerializationStructure,
  // ): StateMachineService {
  //   Logger.staticLog(`StateMachineService.create called`, LogLevel.Debug);

  //   let _obj: StateMachineService | null;
  //   if (initializationStructure) {
  //     try {
  //       // ToDo: deserialize based on contents of structure
  //       _obj = StateMachineService.convertFrom_yaml(initializationStructure.value);
  //     } catch (e) {
  //       if (e instanceof Error) {
  //         throw new DetailedError(
  //           `${callingModule}: create stateMachineService from initializationStructure using convertFrom_xxx -> }`,
  //           e,
  //         );
  //       } else {
  //         // ToDo:  investigation to determine what else might happen
  //         throw new Error(
  //           `${callingModule}: create stateMachineService from initializationStructure using convertFrom_xxx threw something other than a polymorphous Error`,
  //         );
  //       }
  //     }
  //     if (_obj === null) {
  //       throw new Error(
  //         `${callingModule}: create stateMachineService from initializationStructure using convertFrom_xxx produced a null`,
  //       );
  //     }
  //     return _obj;
  //   } else {
  //     try {
  //       _obj = new StateMachineService(logger, data, queryService, extensionContext);
  //     } catch (e) {
  //       if (e instanceof Error) {
  //         throw new DetailedError(`${callingModule}: create stateMachineService from initializationStructure -> }`, e);
  //       } else {
  //         // ToDo:  investigation to determine what else might happen
  //         throw new Error(`${callingModule}: create stateMachineService from initializationStructure`);
  //       }
  //     }
  //     return _obj;
  //   }
  // }

  static convertFrom_json(json: string): StateMachineService {
    return fromJson<StateMachineService>(json);
  }

  static convertFrom_yaml(yaml: string): StateMachineService {
    return fromYaml<StateMachineService>(yaml);
  }

  @logMethod(LogLevel.Trace)
  initialize(): void {}

  @logMethod(LogLevel.Trace)
  start(): void {
    this.primaryActor!.start();
  }

  @logAsyncFunction
  async disposeAsync() {
    if (!this.disposed) {
      // Dispose of the primary actor
      this.primaryActor!.send({ type: "DISPOSE_START" });
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

// @logMethod(LogLevel.Trace)
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
