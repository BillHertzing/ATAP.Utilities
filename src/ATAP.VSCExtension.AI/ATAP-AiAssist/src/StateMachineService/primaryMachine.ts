import { randomOutcome } from "@Utilities/index"; // ToDo: replace with a mocked iQueryService instead of using this import
import * as vscode from "vscode";
import { LogLevel, ILogger, Logger } from "@Logger/index";
import { DetailedError, HandleError } from "@ErrorClasses/index";

import {
  ActorRef,
  assertEvent,
  assign,
  fromPromise,
  OutputFrom,
  sendTo,
  setup,
} from "xstate";

import { IData } from "@DataService/index";

import {
  ModeMenuItemEnum,
  QueryAgentCommandMenuItemEnum,
  QueryFragmentEnum,
  QuickPickEnumeration,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
} from "@BaseEnumerations/index";

import { IQueryService } from "@QueryService/index";

import { IQueryFragmentCollection } from "@ItemWithIDs/index";

export interface IQuickPickTypeMapping {
  [QuickPickEnumeration.ModeMenuItemEnum]: ModeMenuItemEnum;
  [QuickPickEnumeration.QueryEnginesMenuItemEnum]: QueryEngineFlagsEnum;
  [QuickPickEnumeration.QueryAgentCommandMenuItemEnum]: QueryAgentCommandMenuItemEnum;
  //[QuickPickEnumeration.VCSCommandMenuItemEnum]: string;
}
export type QuickPickMappingKeysT = keyof IQuickPickTypeMapping;
export type QuickPickValueT =
  | [QuickPickEnumeration.ModeMenuItemEnum, ModeMenuItemEnum]
  | [QuickPickEnumeration.QueryEnginesMenuItemEnum, QueryEngineFlagsEnum]
  | [
      QuickPickEnumeration.QueryAgentCommandMenuItemEnum,
      QueryAgentCommandMenuItemEnum,
    ];
export function createQuickPickValue<K extends QuickPickMappingKeysT>(
  type: K,
  value?: IQuickPickTypeMapping[K],
): QuickPickValueT {
  return [type, value] as QuickPickValueT;
}

// **********************************************************************************************************************
// types and interfaces across all machines
export interface IAllMachinesBaseContext {
  logger: ILogger;
}

export interface IActorRefAndSubscription {
  actorRef: ActorRef<any, any>;
  subscription: any;
}
export interface IAllMachinesCommonResults {
  isCancelled: boolean;
  errorMessage?: string;
}

// **********************************************************************************************************************
// types and interfaces for the quickPickMachine
export interface IQuickPickActorRefAndSubscription
  extends IActorRefAndSubscription {}
// what the quickPickActor contributes to the primaryMachine's context
export interface IQuickPickMachineComponentOfPrimaryMachineContext {
  quickPickMachineActorRefAndSubscription?: IQuickPickActorRefAndSubscription;
  quickPickMachineOutput?: IQuickPickMachineOutput;
}
export interface IQuickPickEventPayload {
  kindOfEnumeration: QuickPickEnumeration;
  cTSToken: vscode.CancellationToken;
}
export interface IQuickPickMachineInput
  extends Omit<IQuickPickEventPayload, "kindOfEnumeration">,
    IAllMachinesBaseContext {
  pickValue: QuickPickValueT;
  pickItems: vscode.QuickPickItem[];
  prompt: string;
  parent: ActorRef<any, any>;
}
export interface IQuickPickMachineContext
  extends IQuickPickMachineInput,
    IAllMachinesCommonResults {
  isLostFocus: boolean;
}
export interface IQuickPickMachineOutput extends IAllMachinesCommonResults {
  pickValue: QuickPickValueT;
  isLostFocus: boolean;
}
export interface IQuickPickActorLogicInput
  extends Omit<
    IQuickPickMachineContext,
    "parent" | "isCancelled" | "isLostFocus"
  > {}
export interface IQuickPickActorLogicOutput {
  pickValue: QuickPickValueT;
  isCancelled: boolean;
  isLostFocus: boolean;
}
export interface INotifyCompleteActionParameters {
  logger: ILogger;
  sendToTargetActorRef: ActorRef<any, any>;
  eventCausingTheTransitionIntoOuterDoneState: QuickPickMachineCompletionEventsT;
}
export type QuickPickMachineCompletionEventsT =
  | {
      type: "xstate.done.actor.quickPickActor";
      output: IQuickPickActorLogicOutput;
    }
  | { type: "xstate.error.actor.quickPickActor"; message: string }
  | { type: "xstate.done.actor.quickPickDisposeActor" }
  | { type: "xstate.error.actor.quickPickDisposeActor"; message: string };

export interface IAssignQuickPickActorDoneOutputToQuickPickMachineContextActionParameters
  extends IQuickPickMachineOutput {
  errorMessage?: string;
}

// **********************************************************************************************************************
// context type, input type, output type, and event{ type: 'QUERY_DONE' } | { type: 'DISPOSE_COMPLETE' } payload types for the QueryMultipleEngineMachine
/*  Values imported from the queryMultipleEngineMachine*/
import {
  IQueryMultipleEngineMachineOutput,
  IQueryMultipleEngineEventPayload,
  queryMultipleEngineMachine,
} from "@StateMachineService/index";

export interface IQueryMultipleEngineMachineActorRefAndSubscription
  extends IActorRefAndSubscription {}
// what the QueryMultipleEngineMachine contributes to the primaryMachine's context
export interface IQueryMultipleEngineMachineComponentOfPrimaryMachineContext {
  queryMultipleEngineMachineActorRefAndSubscription?: IQueryMultipleEngineMachineActorRefAndSubscription;
  queryMultipleEngineMachineOutput?: IQueryMultipleEngineMachineOutput;
}
// **********************************************************************************************************************
// Actor Logic for the quickPickMachine
export const quickPickActorLogic = fromPromise(
  async ({ input }: { input: IQuickPickActorLogicInput }) => {
    input.logger.log(
      `quickPickActorLogic called pickValue.KindOfEnumeration = ${input.pickValue[0]}, PickItems= ${input.pickItems}, prompt= ${input.prompt}`,
      LogLevel.Debug,
    );
    let _pick: vscode.QuickPickItem | undefined;
    let _isCancelled: boolean = false;
    let _isLostFocus: boolean = false;
    let _pickValue: QuickPickValueT = input.pickValue;
    const kindOfEnumeration = input.pickValue[0];
    _pick = await vscode.window.showQuickPick(
      input.pickItems,
      {
        placeHolder: input.prompt,
      },
      input.cTSToken,
    );
    if (input.cTSToken.isCancellationRequested) {
      _isCancelled = true;
      _pickValue = createQuickPickValue(kindOfEnumeration, undefined);
    } else if (_pick === undefined) {
      _isLostFocus = true;
      _pickValue = createQuickPickValue(kindOfEnumeration, undefined);
    } else {
      switch (kindOfEnumeration) {
        case QuickPickEnumeration.ModeMenuItemEnum:
          _pickValue = createQuickPickValue(
            kindOfEnumeration,
            _pick.label as ModeMenuItemEnum,
          );
          break;
        case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
          _pickValue = createQuickPickValue(
            kindOfEnumeration,
            _pick.label as QueryAgentCommandMenuItemEnum,
          );
          break;
        case QuickPickEnumeration.QueryEnginesMenuItemEnum:
          let _newQueryEngines: QueryEngineFlagsEnum = input
            .pickValue[1] as QueryEngineFlagsEnum;
          switch (_pick.label as QueryEngineNamesEnum) {
            case QueryEngineNamesEnum.Grok:
              _newQueryEngines ^= QueryEngineFlagsEnum.Grok;
              break;
            case QueryEngineNamesEnum.ChatGPT:
              _newQueryEngines ^= QueryEngineFlagsEnum.ChatGPT;
              break;
            case QueryEngineNamesEnum.Claude:
              _newQueryEngines ^= QueryEngineFlagsEnum.Claude;
              break;
            case QueryEngineNamesEnum.Bard:
              _newQueryEngines ^= QueryEngineFlagsEnum.Bard;
              break;
            default:
              throw new Error(
                `quickPickActorLogic received an unexpected QueryEngineName: ${_pick.label}`,
              );
          }
          _pickValue = createQuickPickValue(
            kindOfEnumeration,
            _newQueryEngines as QueryEngineFlagsEnum,
          );
          break;
        default:
          throw new Error(
            `quickPickActorLogic received an unexpected kindOfEnumeration: ${kindOfEnumeration}`,
          );
      }
    }
    input.logger.log(
      `quickPickActorLogic returning pickValue ${_pickValue}, isCancelled= ${_isCancelled}, isLostFocus= ${_isLostFocus}`,
      LogLevel.Debug,
    );

    return {
      pickValue: _pickValue,
      isCancelled: _isCancelled,
      isLostFocus: _isLostFocus,
    } as IQuickPickActorLogicOutput;
  },
);

// **********************************************************************************************************************
// Machine definition for the quickPickMachine
export const quickPickMachine = setup({
  types: {} as {
    context: IQuickPickMachineContext;
    input: IQuickPickMachineInput;
    output: IQuickPickMachineOutput;
    events:
      | QuickPickMachineCompletionEventsT
      | { type: "QUICKPICK_DONE" }
      | { type: "DISPOSE_START" } // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
      | { type: "DISPOSE_COMPLETE" };
  },
  actions: {
    assignQuickPickActorDoneOutputToQuickPickMachineContext: assign(
      ({ event }) => {
        assertEvent(event, "xstate.done.actor.quickPickActor");
        return {
          pickValue: event.output.pickValue,
          isCancelled: event.output.isCancelled,
          isLostFocus: event.output.isLostFocus,
        };
      },
    ),
    // assignQuickPickActorDoneOutputToQuickPickMachineContext2: assign(
    //   _,
    //   params: IAssignQuickPickActorDoneOutputToQuickPickMachineContextActionParameters,
    // ) => {
    //   params.logger.log(
    //     `assignQuickPickActorDoneOutputToQuickPickMachineContext2, pickValue= ${params.pickValue}, isCancelled= ${params.isCancelled}, isLostFocus= ${params.isLostFocus}, errorMessage= ${params.errorMessage!}`,
    //     LogLevel.Debug,
    //   );
    //   return assign({
    //     pickValue: params.pickValue,
    //     isCancelled: params.isCancelled,
    //     isLostFocus: params.isLostFocus,
    //     errorMessage: params.errorMessage,
    //   });
    // },
    assignQuickPickActorErrorOutputToQuickPickMachineContext: assign(
      ({ context, event }) => {
        assertEvent(event, "xstate.error.actor.quickPickActor");
        return {
          pickValue: createQuickPickValue(context.pickValue[0], undefined),
          isCancelled: false,
          isLostFocus: false,
          errorMessage: event.message,
        };
      },
    ),
    // the sendTo(...) is a special action that can go wherever an action can go
    //  it has two arguments, either or both of which can be a lambda that closes over their params argument
    //   The first lambda returns an actorRef, and the second lambda returns an event, thus satisfying the two argument types that sendTo expects
    notifyCompleteAction: sendTo(
      (_, params: INotifyCompleteActionParameters) => {
        params.logger.log(
          `notifyCompleteAction, in the destination selector lambda, sendToTargetActorRef is ${params.sendToTargetActorRef.id}`,
          LogLevel.Debug,
        );
        return params.sendToTargetActorRef;
      },
      (_, params: INotifyCompleteActionParameters) => {
        params.logger.log(
          `notifyCompleteAction, in the event selector lambda, eventCausingTheTransitionIntoOuterDoneState is ${params.eventCausingTheTransitionIntoOuterDoneState.type}`,
          LogLevel.Debug,
        );
        // discriminate on event that triggers this action and send QUICKPICK_DONE or DISPOSE_COMPLETE
        let _eventToSend:
          | { type: "QUICKPICK_DONE" }
          | { type: "DISPOSE_COMPLETE" };
        switch (params.eventCausingTheTransitionIntoOuterDoneState.type) {
          case "xstate.done.actor.quickPickActor":
            _eventToSend = { type: "QUICKPICK_DONE" };
            break;
          case "xstate.done.actor.quickPickDisposeActor":
            _eventToSend = { type: "DISPOSE_COMPLETE" };
            break;
          // ToDo: add case legs for the two error events that come from the quickPickActor and quickPickDisposeActor
          default:
            throw new Error(
              `notifyCompleteAction received an unexpected event type: ${params.eventCausingTheTransitionIntoOuterDoneState.type}`,
            );
        }
        params.logger.log(
          `notifyCompleteAction, in the event selector lambda, _eventToSend is ${_eventToSend.type}`,
          LogLevel.Debug,
        );
        return _eventToSend;
      },
    ),
    disposingStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposingStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      // ToDo: add code to dispose of any allocated resource
    },

    debugQuickPickMachineContext: ({ context, event }) => {
      context.logger.log(
        `debugQuickPickMachineContext, context.pickValue: ${context.pickValue}, context.isCancelled: ${context.isCancelled} context.isLostFocus: ${context.isLostFocus}`,
        LogLevel.Debug,
      );
    },
  },
  actors: {
    quickPickActor: quickPickActorLogic,
  },
}).createMachine({
  id: "quickPickMachine",
  context: ({ input }) => ({
    logger: new Logger(input.logger, "quickPickMachine"),
    // logger: context.logger,
    parent: input.parent,
    pickValue: input.pickValue,
    pickItems: input.pickItems,
    prompt: input.prompt,
    cTSToken: input.cTSToken,
    isCancelled: false,
    isLostFocus: false,
  }),
  output: ({ context }) => ({
    pickValue: context.pickValue,
    isCancelled: context.isCancelled,
    isLostFocus: context.isLostFocus,
    errorMessage: context.errorMessage,
  }),
  initial: "startedState",
  states: {
    startedState: {
      entry: ({ context }) => {
        context.logger.log(
          `quickPickMachine startedState entry`,
          LogLevel.Debug,
        );
      },
      type: "parallel",
      states: {
        operationState: {
          // This state handles the main operation of the machine. First of two parallel states
          initial: "quickPickState",
          states: {
            quickPickState: {
              description:
                "A state where an actor is invoked to show and let the user select an enum value from a QuickPick list.",
              invoke: {
                id: "quickPickActor",
                src: "quickPickActor",
                input: ({ context }) => ({
                  logger: context.logger,
                  cTSToken: context.cTSToken,
                  pickValue: context.pickValue,
                  pickItems: context.pickItems,
                  prompt: context.prompt,
                }),
                onDone: {
                  target: "innerDoneState",
                  actions: [
                    {
                      type: "assignQuickPickActorDoneOutputToQuickPickMachineContext",
                      params: ({ context, event }) => ({
                        logger: context.logger,
                        pickValue: event.output.pickValue,
                        isCancelled: event.output.isCancelled,
                        isLostFocus: event.output.isLostFocus,
                      }),
                    },
                  ],
                },
                onError: {
                  target: "errorState",
                  actions:
                    "assignQuickPickActorErrorOutputToQuickPickMachineContext",
                },
              },
            },
            errorState: {
              // ToDO: add code to attempt to remediate the error, otherwise transition to innerDoneState
              always: {
                target: "innerDoneState",
              },
            },
            innerDoneState: {
              description:
                "quickPickMachine is done. Transition to the outerDoneState",
              always: "#quickPickMachine.outerDoneState",
            },
          },
        },
        disposeState: {
          // 2nd parallel state. This state can be transitioned to from any state
          initial: "inactiveState",
          states: {
            inactiveState: {
              on: {
                DISPOSE_START: "disposingState",
              },
            },
            disposingState: {
              entry: "disposingStateEntryAction",
              on: {
                DISPOSE_COMPLETE: {
                  target: "disposeCompleteState",
                },
              },
            },
            disposeCompleteState: {
              always: "#quickPickMachine.outerDoneState",
            },
          },
        },
      },
    },
    outerDoneState: {
      type: "final",
      entry: [
        // call the notifyComplete action here, setting the value of the params' properties to values pulled from the context and the event
        // that entered the outerDonestate.
        // When notifyCompleteAction is called, the lambda's supplied as arguments to sendTo (because they close over params), will use the values
        //  set into params here, when the lambdas run
        {
          type: "notifyCompleteAction",
          params: ({ context, event }) =>
            ({
              logger: context.logger,
              sendToTargetActorRef: context.parent,
              eventCausingTheTransitionIntoOuterDoneState: event,
            }) as INotifyCompleteActionParameters,
        },
        "debugQuickPickMachineContext",
      ],
    },
  },
});

/*******************************************************************/
/* Primary Machine */

export interface IPrimaryMachineInput extends IAllMachinesBaseContext {
  queryService: IQueryService;
  data: IData;
}

export interface IPrimaryMachineContext
  extends IPrimaryMachineInput,
    IQuickPickMachineComponentOfPrimaryMachineContext,
    IQueryMultipleEngineMachineComponentOfPrimaryMachineContext {}

// create the primaryMachine definition
export const primaryMachine = setup({
  types: {} as {
    context: IPrimaryMachineContext;
    input: IPrimaryMachineInput;
    events:
      | { type: "QUICKPICK_START"; payload: IQuickPickEventPayload }
      | { type: "QUICKPICK_DONE" }
      | { type: "QUERY_START"; payload: IQueryMultipleEngineEventPayload }
      | { type: "QUERY_DONE" }
      | { type: "DISPOSE_START" } // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
      | { type: "DISPOSE_COMPLETE" };
  },
  actions: {
    spawnQuickPickMachine: assign(({ context, spawn, event, self }) => {
      assertEvent(event, "QUICKPICK_START");
      let _pickItems: vscode.QuickPickItem[];
      let _pickValue: QuickPickValueT;
      let _prompt = "";
      switch (event.payload.kindOfEnumeration) {
        case QuickPickEnumeration.ModeMenuItemEnum:
          _pickValue = createQuickPickValue(
            event.payload.kindOfEnumeration,
            context.data.stateManager.currentMode,
          );
          _pickItems = context.data.pickItems.modeMenuItems;
          _prompt = `currently active Mode is ${context.data.stateManager.currentMode}, select one from the list to change it`;
          break;
        case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
          _pickValue = createQuickPickValue(
            event.payload.kindOfEnumeration,
            context.data.stateManager.currentQueryAgentCommand,
          );
          _pickItems = context.data.pickItems.queryAgentCommandMenuItems;
          _prompt = `currently active Query Agent Command is ${context.data.stateManager.currentQueryAgentCommand}, select one from the list to change it`;
          break;
        case QuickPickEnumeration.QueryEnginesMenuItemEnum:
          _pickValue = createQuickPickValue(
            event.payload.kindOfEnumeration,
            context.data.stateManager.currentQueryEngines,
          );
          _pickItems = context.data.pickItems.queryEnginesMenuItems;
          _prompt = `currently active Query Engines are shown below, select one from the list to change it`;
          break;
        default:
          throw new Error(
            `primaryMachine received an unexpected kindOfEnumeration: ${event.payload.kindOfEnumeration}`,
          );
      }
      const _actorRef = spawn("quickPickMachine", {
        systemId: "quickPickMachine",
        id: "quickPickMachine",
        input: {
          logger: context.logger,
          parent: self,
          pickValue: _pickValue,
          pickItems: _pickItems,
          prompt: _prompt,
          cTSToken: event.payload.cTSToken,
        },
      });
      const _subscription = _actorRef.subscribe((x) => {
        context.logger.log(
          `spawnQuickPickMachine subscription called with x = ${x}`,
          LogLevel.Debug,
        );
      });
      return {
        quickPickMachineActorRefAndSubscription: {
          actorRef: _actorRef,
          subscription: _subscription,
        },
      };
    }),
    spawnMultipleEngineQueryMachine: assign(
      ({ context, spawn, event, self }) => {
        context.logger.log(
          `spawnMultipleEngineQueryMachine called`,
          LogLevel.Debug,
        );
        assertEvent(event, "QUERY_START");
        const _currentQueryEngines =
          context.data.stateManager.currentQueryEngines;
        const _actorRef = spawn("queryMultipleEngineMachine", {
          systemId: "queryMultipleEngineMachine",
          id: "queryMultipleEngineMachine",
          input: {
            logger: context.logger,
            parent: self,
            queryService: context.queryService,
            queryFragmentCollection: event.payload.queryFragmentCollection,
            currentQueryEngines: _currentQueryEngines,
            cTSToken: event.payload.cTSToken,
          },
        });
        const _subscription = _actorRef.subscribe((state) => {
          context.logger.log(
            `spawnMultipleEngineQueryMachine subscription called with x = ${state}`,
            LogLevel.Debug,
          );
        });
        return {
          queryMultipleEngineMachineActorRefAndSubscription: {
            actorRef: _actorRef,
            subscription: _subscription,
          },
        };
      },
    ),
    // copy the results (output) from the quickPickMachine to the context
    assignQuickPickMachineDoneOutputToPrimaryMachineContext: assign(
      ({ context }) => {
        context.logger.log(
          `assignQuickPickMachineDoneOutputToPrimaryMachineContext called`,
          LogLevel.Debug,
        );
        const _quickPickMachineActorRef =
          context.quickPickMachineActorRefAndSubscription as IQuickPickActorRefAndSubscription;
        // confirm the quickPickMachineActor is done
        if (
          _quickPickMachineActorRef.actorRef.getSnapshot().status !== "done"
        ) {
          throw new Error(
            "OMG how can this happen??!! Gotta submit an xState issue if this ever pops up",
          );
        }
        // ToDo: unsubscribe from the quickPickMachineActorRef
        // ToDo: set the actorRef to undefined
        // Save the output of the quickPickMachine to the IData instance
        return {
          quickPickMachineOutput:
            context.quickPickMachineActorRefAndSubscription!.actorRef.getSnapshot()
              .output,
          data: {
            ...context.data,
            stateManager: {
              ...context.data.stateManager,
              currentQueryEngines:
                context.quickPickMachineActorRefAndSubscription!.actorRef.getSnapshot()
                  .output.pickValue.value,
            },
          },
          quickPickMachineActorRefAndSubscription: undefined,
        };
      },
    ),
    // copy the results (output) from the queryMultipleEngineMachine to the context
    assignQueryMultipleEngineMachineDoneOutputToPrimaryMachineContext: assign(
      ({ context }) => {
        context.logger.log(
          `assignQueryMultipleEngineMachineDoneOutputToPrimaryMachineContext called`,
          LogLevel.Debug,
        );
        const _queryMultipleEngineMachineActorRef =
          context.queryMultipleEngineMachineActorRefAndSubscription as IQueryMultipleEngineMachineActorRefAndSubscription;
        // confirm the queryMultipleEngineMachineActor is done
        if (
          _queryMultipleEngineMachineActorRef.actorRef.getSnapshot().status !==
          "done"
        ) {
          throw new Error(
            "OMG how can this happen??!! Gotta submit an xState issue if this ever pops up",
          );
        }
        // ToDo: unsubscribe from the quickPickMachineActorRef
        // ToDo: set the actorRef to undefined
        return {
          quickPickMachineOutput:
            context.quickPickMachineActorRefAndSubscription!.actorRef.getSnapshot()
              .output,
          quickPickMachineActorRefAndSubscription: undefined,
        };
      },
    ),
    updateUIStateEntryAction: (context) => {
      context.context.logger.log(
        `updateUIStateEntryAction, event type is ${context.event.type}`,
        LogLevel.Debug,
      );
    },
    updateUIStateExitAction: (context) => {
      context.context.logger.log(
        `updateUIStateExitAction, event type is ${context.event.type}`,
        LogLevel.Debug,
      );
    },
    updateUIAction: ({ context, event }) => {
      context.logger.log(
        `updateUIAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      switch (event.type) {
        case "QUERY_DONE":
          context.logger.log(
            `updateUIStateEntry, received event type is ${event.type}, context.queryMultipleEngineMachineOutput is ${context.queryMultipleEngineMachineOutput}`,
            LogLevel.Debug,
          );
          break;
        case "QUICKPICK_DONE":
          context.logger.log(
            `updateUIStateEntry, received event type is ${event.type}, context.quickPickMachineOutput is ${context.quickPickMachineOutput}`,
            LogLevel.Debug,
          );
          break;
        default:
          throw new Error(
            `updateUIStateEntry received an unexpected event type: ${event.type}`,
          );
      }
      // if queryMultipleEngineMachineOutput.isCancelled is true, clean up any small UI elements
      // if queryMultipleEngineMachineOutput.errorMessage is defined, display the error message in the UI
      // if queryMultipleEngineMachineOutput.isCancelled is false,
      //  and also context.queryMultipleEngineMachineOutput!.querySingleEngineActorOutputs.isCancelled is false for all keys, then update the UI
      // ToDO: what if some are cancelled but others have returned responses?
    },
    disposingStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposingStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
    },
    disposeCompleteStateEntryAction: ({ context, event }) => {
      context.logger.log(
        `disposeCompleteStateEntryAction, event type is ${event.type}`,
        LogLevel.Debug,
      );
      // Todo: add code to send the DISPOSE_EVENT to any spawned MachineActorRef so that it can free any allocated resources
      // ToDo: current machineActorRefs are queryMultipleEngineMachineMachineActorRefAndSubscription and quickPickMachineActorRefAndSubscription
      // ToDo: add code to dispose of any allocated resource
    },
    debugPrimaryMachineContext: ({ context, event }) => {
      context.logger.log(
        `debugPrimaryMachineContext, context.quickPickMachineOutput.pickValue: ${context.quickPickMachineOutput!.pickValue}, context.quickPickMachineOutput.isCancelled: ${context.quickPickMachineOutput!.isCancelled}, context.quickPickMachineOutput.isLostFocus: ${context.quickPickMachineOutput!.isLostFocus}, context.quickPickMachineOutput.errorMessage: ${context.quickPickMachineOutput!.errorMessage}, context.quickPickMachineActorRefAndSubscription: ${context.quickPickMachineActorRefAndSubscription}, context.queryMultipleEngineMachineOutput: ${context.queryMultipleEngineMachineOutput}, context.queryMultipleEngineMachineActorRefAndSubscription: ${context.queryMultipleEngineMachineActorRefAndSubscription}`,
        LogLevel.Debug,
      );
    },
    debugPrimaryMachineData: ({ context, event }) => {
      context.logger.log(
        `debugPrimaryMachineContext, context.quickPickMachineOutput.pickValue: ${context.quickPickMachineOutput!.pickValue}, context.quickPickMachineOutput.isCancelled: ${context.quickPickMachineOutput!.isCancelled}, context.quickPickMachineOutput.isLostFocus: ${context.quickPickMachineOutput!.isLostFocus}, context.quickPickMachineOutput.errorMessage: ${context.quickPickMachineOutput!.errorMessage}, context.quickPickMachineActorRefAndSubscription: ${context.quickPickMachineActorRefAndSubscription}, context.queryMultipleEngineMachineOutput: ${context.queryMultipleEngineMachineOutput}, context.queryMultipleEngineMachineActorRefAndSubscription: ${context.queryMultipleEngineMachineActorRefAndSubscription}`,
        LogLevel.Debug,
      );
    },
  },
  actors: {
    quickPickMachine: quickPickMachine,
    queryMultipleEngineMachine: queryMultipleEngineMachine,
  },
}).createMachine({
  id: "primaryMachine",
  context: ({ input }) => ({
    logger: new Logger(input.logger, "primaryMachine"),
    data: input.data,
    quickPickMachineActorRefAndSubscription: undefined,
    quickPickMachineOutput: undefined,
    queryService: input.queryService,
    queryMultipleEngineMachineActorRefAndSubscription: undefined,
    queryMultipleEngineMachineOutput: undefined,
  }),
  type: "parallel",
  states: {
    operationState: {
      // This state handles the main operation of the machine. First of two parallel states
      initial: "idleState",
      states: {
        idleState: {
          on: {
            QUICKPICK_START: {
              target: "quickPickState",
            },
            QUERY_START: {
              target: "queryingState",
            },
            QUERY_DONE: {
              target: "updateUIState",
              // copy the results (output) from the queryMultipleEngineMachine to the context
              actions: [
                "assignQueryMultipleEngineMachineDoneOutputToPrimaryMachineContext",
                "debugPrimaryMachineContext",
              ],
            },
            QUICKPICK_DONE: {
              target: "updateUIState",
              // copy the results (output) from the quickPickMachine to the context
              actions: [
                "assignQuickPickMachineDoneOutputToPrimaryMachineContext",
                "debugPrimaryMachineContext",
              ],
            },
            "xstate.done.actor.quickPickMachine": {
              target: "updateUIState",
            },
          },
        },
        errorState: {
          // ToDO: add code to attempt to remediate the error, otherwise transition to finalErrorState and throw an error
          always: {
            target: "idleState",
          },
        },
        quickPickState: {
          description:
            "A parent state with child states that allow a user to see a list of available enumeration values, pick one, update the extension (transition it) to the UI indicated by the new value, update the 'currentValue' of the enumeration, and then return to the Idle state.",
          entry: "spawnQuickPickMachine", // spawn the quickPickMachine and store the reference in the context
          always: "idleState",
        },
        queryingState: {
          description:
            "A state that spawns a queryMultipleEngineMachine which encapsulates multiple states for handling parallel queries to multiple QueryAgents.",
          entry: [
            "spawnMultipleEngineQueryMachine",
            ({ context }) => {
              context.logger.log("queryingState entry", LogLevel.Debug);
            },
          ], // spawn the queryMultipleEngineMachine and store the reference in the context
          always: "idleState",
        },
        updateUIState: {
          description: "appearance",
          entry: "updateUIStateEntryAction",
          exit: "updateUIStateExitAction",
          always: {
            target: "idleState",
            actions: "updateUIAction",
          },
          // ToDo: all the various on... events
          on: {
            QUERY_DONE: {
              target: "idleState",
              actions: "updateUIAction",
            },
            QUICKPICK_DONE: {
              target: "idleState",
            },
          },
        },
      },
    },

    disposeState: {
      // 2nd parallel state. This state can be transitioned to from any state
      initial: "inactiveState",
      states: {
        inactiveState: {
          on: {
            DISPOSE_START: "disposingState",
          },
        },
        disposingState: {
          entry: "disposingStateEntryAction",

          on: {
            DISPOSE_COMPLETE: {
              target: "disposeCompleteState",
            },
          },
        },
        disposeCompleteState: {
          entry: "disposeCompleteStateEntryAction",
          type: "final",
        },
      },
    },
  },
});
