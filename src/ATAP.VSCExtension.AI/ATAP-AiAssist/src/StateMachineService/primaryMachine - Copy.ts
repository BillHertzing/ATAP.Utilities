import { randomOutcome } from '@Utilities/index'; // ToDo: replace with a mocked iQueryService instead of using this import
import * as vscode from 'vscode';
import { LogLevel, IScopedLogger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';

import { ActorRef, assertEvent, assign, fromPromise, sendTo, setup } from 'xstate';

import {
  ModeMenuItemEnum,
  QueryAgentCommandMenuItemEnum,
  QueryFragmentEnum,
  QuickPickEnumeration,
} from '@BaseEnumerations/index';

import { IQueryService } from '@QueryService/index';

import { IQueryFragmentCollection } from '@ItemWithIDs/index';

/*
export enum QuickPickEnumeration {
  // eslint-disable-next-line @typescript-eslint/naming-convention
  VCSCommandMenuItemEnum = 'VCSCommandMenuItemEnum',
  ModeMenuItemEnum = 'ModeMenuItemEnum',
  QueryAgentCommandMenuItemEnum = 'QueryAgentCommandMenuItemEnum',
  QueryEnginesMenuItemEnum = 'QueryEnginesMenuItemEnum',
}
*/
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
  | [QuickPickEnumeration.QueryAgentCommandMenuItemEnum, QueryAgentCommandMenuItemEnum];
export function createQuickPickValue<K extends QuickPickMappingKeysT>(
  type: K,
  value: IQuickPickTypeMapping[K],
): QuickPickValueT {
  return [type, value] as QuickPickValueT;
}

// **********************************************************************************************************************
// types and interfaces across all machines
export interface IAllMachinesBaseContext {
  logger: IScopedLogger;
}

export type ActorRefAndSubscriptionT = { actorRef: ActorRef<any, any>; subscription: any };
export interface IAllMachinesCommonResults {
  isCancelled: boolean;
  errorMessage?: string;
}

// **********************************************************************************************************************
// types and interfaces for the quickPickMachine
export type QuickPickActorRefAndSubscriptionT = { actorRef: ActorRef<any, any>; subscription: any };
// what the quickPickMachine contributes to the primaryMachine's context
export interface IQuickPickMachineComponentOfPrimaryMachineContext {
  quickPickMachineActorRef?: QuickPickActorRefAndSubscriptionT;
}
export interface IQuickPickEventPayload {
  pickValue: QuickPickValueT;
  pickItems: vscode.QuickPickItem[];
  prompt: string;
  cTSToken: vscode.CancellationToken;
}
export interface IQuickPickMachineInput extends IAllMachinesBaseContext, IQuickPickEventPayload {
  parent: ActorRef<any, any>;
}
export interface IQuickPickMachineContext extends IQuickPickMachineInput, IAllMachinesCommonResults {
  isLostFocus: boolean;
}
export interface IQuickPickMachineOutput extends IAllMachinesCommonResults {
  pickValue?: QuickPickValueT;
  isLostFocus: boolean;
}
export interface IQuickPickActorLogicInput extends IAllMachinesBaseContext, IQuickPickEventPayload {}
export interface IQuickPickActorLogicOutput {
  pickValue: QuickPickValueT;
  isCancelled: boolean;
  isLostFocus: boolean;
}

/*******************************************************************/
export enum QueryEngineNamesEnum {
  // OpenAi's AI
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 'ChatGPT',
  // Anthropic's AI
  Claude = 'Claude',
  // Google's AI
  Bard = 'Bard',
  // X's AI
  Grok = 'Grok',
}
export enum QueryEngineFlagsEnum {
  // OpenAi's AI
  // eslint-disable-next-line @typescript-eslint/naming-convention
  ChatGPT = 1 << 0,
  // Anthropic's AI
  Claude = 1 << 1,
  // Google's AI
  Bard = 1 << 2,
  // X's AI
  Grok = 1 << 3,
}

// **********************************************************************************************************************
// context type, input type, output type, and event payload types for the QueryMachine
// what the quickPickMachine contributes to the primaryMachine's context
export interface IQueryMachineComponentOfPrimaryMachineContext {
  queryMachineActorRef?: ActorRefAndSubscriptionT;
  queryMachineOutput?: IQueryMachineOutput;
}
export interface IQueryEventPayload {
  queryFragmentCollection: IQueryFragmentCollection;
  currentQueryEngines: QueryEngineFlagsEnum;
  cTSToken: vscode.CancellationToken;
}
export interface IQueryMachineInput extends IAllMachinesBaseContext, IQueryEventPayload {
  parent: ActorRef<any, any>;
  queryService: IQueryService;
}
export type QuerySingleEngineActorOutputsT = Record<QueryEngineNamesEnum, IQuerySingleEngineActorLogicOutput>;
export type QuerySingleEngineActorRefsT = Record<QueryEngineNamesEnum, ActorRefAndSubscriptionT>;
export interface IQueryMachineContext
  extends IQueryMachineInput,
    IQueryGatheringActorComponentOfQueryMachineContext,
    IQuerySingleEngineComponentOfQueryMachineContext,
    IAllMachinesCommonResults {}
export interface IQueryMachineOutput extends IAllMachinesCommonResults {
  querySingleEngineActorOutputs?: QuerySingleEngineActorOutputsT;
}

// **********************************************************************************************************************
// input and output to the QueryGatheringActorLogicSource
export interface IQueryGatheringActorComponentOfQueryMachineContext {
  queryString?: string;
}
export interface IQueryGatheringActorLogicInput extends IAllMachinesBaseContext {
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
}
export interface IQueryGatheringActorLogicOutput
  extends IQueryGatheringActorComponentOfQueryMachineContext,
    IAllMachinesCommonResults {}
// **********************************************************************************************************************
// context type, input type, output type, and event payload types for the querySingleEngineMachine
export interface IQuerySingleEngineComponentOfQueryMachineContext {
  querySingleEngineActorRefs?: QuerySingleEngineActorRefsT;
  querySingleEngineActorOutputs?: QuerySingleEngineActorOutputsT;
}
export interface IQuerySingleEngineMachineInput extends IAllMachinesBaseContext {
  parent: ActorRef<any, any>;
  queryService: IQueryService;
  queryString: string;
  queryEngineName: QueryEngineNamesEnum;
  cTSToken: vscode.CancellationToken;
}
export interface IQuerySingleEngineMachineContext extends IQuerySingleEngineMachineInput, IAllMachinesCommonResults {
  response?: string;
}
export interface IQuerySingleEngineMachineOutput extends IQuerySingleEngineActorLogicOutput {}
// **********************************************************************************************************************
// context type, input type, output type, and event payload types for the querySingleEngineActorLogic
export interface IQuerySingleEngineActorLogicInput {
  logger: IScopedLogger;
  queryService: IQueryService;
  queryString?: string;
  queryEngineName: QueryEngineNamesEnum;
  cTSToken: vscode.CancellationToken;
}
export interface IQuerySingleEngineActorLogicOutput extends IAllMachinesCommonResults {
  queryEngineName: QueryEngineNamesEnum;
  response?: string;
}
export interface IQuerySingleEngineMachineDoneEventPayload {
  queryEngineName: QueryEngineNamesEnum;
}

// **********************************************************************************************************************
// Actor Logic for the quickPickMachine
export const quickPickActorLogic = fromPromise(async ({ input }: { input: IQuickPickActorLogicInput }) => {
  input.logger.log(
    `quickPickActorLogic called pickValue.KindOfEnumeration = ${input.pickValue[0]}, PickItems= ${input.pickItems}, prompt= ${input.prompt}`,
    LogLevel.Debug,
  );
  let _pick: vscode.QuickPickItem | undefined;
  let _isCancelled: boolean = false;
  let _isLostFocus: boolean = false;
  let _pickValue: QuickPickValueT = input.pickValue;
  const _quickPickKindOfEnumeration = input.pickValue[0];
  _pick = await vscode.window.showQuickPick(
    input.pickItems,
    {
      placeHolder: input.prompt,
    },
    input.cTSToken,
  );
  if (input.cTSToken.isCancellationRequested) {
    _isCancelled = true;
  } else if (_pick === undefined) {
    _isLostFocus = true;
  } else {
    switch (_quickPickKindOfEnumeration) {
      case QuickPickEnumeration.ModeMenuItemEnum:
        _pickValue = createQuickPickValue(_quickPickKindOfEnumeration, _pick.label as ModeMenuItemEnum);
        break;
      case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
        _pickValue = createQuickPickValue(_quickPickKindOfEnumeration, _pick.label as QueryAgentCommandMenuItemEnum);
        break;
      case QuickPickEnumeration.QueryEnginesMenuItemEnum:
        let _newQueryEngines: QueryEngineFlagsEnum = input.pickValue[1] as QueryEngineFlagsEnum;
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
            throw new Error(`quickPickActorLogic received an unexpected QueryEngineName: ${_pick.label}`);
        }
        _pickValue = createQuickPickValue(_quickPickKindOfEnumeration, _newQueryEngines as QueryEngineFlagsEnum);
        break;
      default:
        throw new Error(
          `quickPickActorLogic received an unexpected quickPickKindOfEnumeration: ${_quickPickKindOfEnumeration}`,
        );
    }
  }
  return {
    pickValue: _pickValue,
    isCancelled: _isCancelled,
    isLostFocus: _isLostFocus,
  } as IQuickPickActorLogicOutput;
});

// **********************************************************************************************************************
// Machine definition for the quickPickMachine
export const quickPickMachine = setup({
  types: {} as {
    context: IQuickPickMachineContext;
    input: IQuickPickMachineInput;
    output: IQuickPickMachineOutput;
    events:
      | { type: 'QUICKPICK_QUICKPICK_MACHINE_DONE' }
      | { type: 'done.invoke.quickPickActorLogic'; data: IQuickPickActorLogicOutput }
      | { type: 'xstate.done.actor.quickPickActor'; output: IQuickPickActorLogicOutput }
      | { type: 'DISPOSE_START' } // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
      | { type: 'DISPOSE_COMPLETE' };
  },
  actions: {
    sendQuickPickMachineDoneEvent: (context) => {
      sendTo(context.context.parent, {
        type: 'QUICKPICK_DONE',
      });
    },
    disposingStateEntryAction: (context) => {
      context.context.logger.log(`disposingStateEntryAction, event type is ${context.event.type}`, LogLevel.Debug);
      // ToDo: add code to dispose of any allocated resource
    },
    disposeCompleteStateEntryAction: (context) => {
      context.context.logger.log(
        `disposeCompleteStateEntryAction, event type is ${context.event.type}`,
        LogLevel.Debug,
      );
      sendTo(context.context.parent, {
        type: 'DISPOSE_COMPLETE',
      });
    },
  },
  actors: {
    quickPickActorLogic: quickPickActorLogic,
  },
}).createMachine({
  id: 'quickPickMachine',
  context: ({ input }) => ({
    logger: input.logger,
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
  type: 'parallel',
  states: {
    operationState: {
      // This state handles the main operation of the machine. First of two parallel states
      initial: 'quickPickState',
      states: {
        quickPickState: {
          description:
            'A state where an actor is invoked to show and let the user select an enum value from a QuickPick list.',
          invoke: {
            id: 'quickPickActor',
            src: 'quickPickActorLogic',
            input: ({ context }) => ({
              logger: context.logger,
              cTSToken: context.cTSToken,
              pickValue: context.pickValue,
              pickItems: context.pickItems,
              prompt: context.prompt,
            }),
            onDone: {
              target: 'doneState',
              actions: assign({
                pickValue: (_, event) => (event as any).data.pickValue,
                isCancelled: (_, event) => (event as any).data.isCancelled,
                isLostFocus: (_, event) => (event as any).data.isLostFocus,
              }),
            },
            onError: {
              target: 'errorState',
              actions: assign({
                pickValue: undefined,
                isCancelled: false,
                isLostFocus: false,
                errorMessage: (_, event) => (event as any).message,
              }),
            },
          },
        },
        errorState: {
          // ToDO: add code to attempt to remediate the error, otherwise transition to doneState
          always: {
            target: 'doneState',
          },
        },
        doneState: {
          description: 'quickPickMachine is done. Send the QUICKPICK_DONE to the parent machine',
          type: 'final',
          entry: 'sendQuickPickMachineDoneEvent',
        },
      },
    },
    disposeState: {
      // 2nd parallel state. This state can be transitioned to from any state
      initial: 'inactiveState',
      states: {
        inactiveState: {
          on: {
            DISPOSE_START: 'disposingState',
          },
        },
        disposingState: {
          entry: 'disposingStateEntryAction',
          on: {
            DISPOSE_COMPLETE: {
              target: 'disposeCompleteState',
            },
          },
        },
        disposeCompleteState: {
          entry: 'disposeCompleteStateEntryAction',
          type: 'final',
        },
      },
    },
  },
  on: {
    // Global transition to disposingState
    DISPOSE_START: 'disposeState',
  },
});

/*******************************************************************/
/* Query Machine */
// **********************************************************************************************************************
// actor logic for the queryGatheringActor

export const queryGatheringActorLogic = fromPromise<IQueryGatheringActorLogicOutput, IQueryGatheringActorLogicInput>(
  async ({ input }: { input: IQueryGatheringActorLogicInput }) => {
    let _queryString = '';
    let _queryFragmentCollection: IQueryFragmentCollection;
    input.logger.log(`queryGatheringActorLogic called`, LogLevel.Debug);
    // always test the cancellation token on entry to the function to see if it has already been cancelled
    if (input.cTSToken.isCancellationRequested) {
      input.logger.log(`queryGatheringActorLogic leaving with cancelled = true`, LogLevel.Debug);
      return {
        queryString: '',
        isCancelled: true,
      } as IQueryGatheringActorLogicOutput;
    }
    _queryFragmentCollection = input.queryFragmentCollection;
    // if the queryFragmentCollection is not defined or is empty, then return an error
    if (!_queryFragmentCollection || _queryFragmentCollection.value.length === 0) {
      throw new Error('queryGatheringActorLogic: queryFragmentCollection is not defined or empty');
    }
    // switch on the fragmentKind and collect accordingly
    _queryFragmentCollection.value.forEach((element) => {
      // test for cancellation each time around the loop
      // if (input.queryCTSToken.isCancellationRequested) {
      //   input.logger.log(`gatheringActorLogic leaving with cancelled = true`, LogLevel.Debug);
      //   return {
      //     queryString: '',
      //     cancelled: true,
      //     cTSToken: input.cTSToken,
      //   } as QueryGatheringActorLogicOutputT;
      // }
      switch (element.value.kindOfFragment) {
        case QueryFragmentEnum.StringFragment:
          _queryString += element.value.value;
          break;
        case QueryFragmentEnum.FileFragment:
          //ToDo: Implement FileFragment
          //queryString += element.value;
          break;
        default:
          throw new Error(
            `queryGatheringActorLogic: Unhandled queryFragment.kindOfFragment: ${element.value.kindOfFragment}`,
          );
      }
    });
    input.logger.log(`queryGatheringActorLogic leaving with queryString= ${_queryString}`, LogLevel.Debug);
    return {
      queryString: _queryString,
      isCancelled: false,
    } as IQueryGatheringActorLogicOutput;
  },
);

// **********************************************************************************************************************
// actor logic definition for the querySingleEngineActorLogic
export const querySingleEngineActorLogic = fromPromise<
  IQuerySingleEngineActorLogicOutput,
  IQuerySingleEngineActorLogicInput
>(async ({ input }: { input: IQuerySingleEngineActorLogicInput }) => {
  input.logger.log(`querySingleActorLogic called`, LogLevel.Debug);
  // always test the cancellation token on entry to the function to see if it has already been cancelled
  if (input.cTSToken?.isCancellationRequested) {
    return { isCancelled: true } as IQuerySingleEngineActorLogicOutput;
  }
  let _qs = input.queryString;
  let _queryResponse: { result?: string; isCancelled: boolean };
  // use the queryService to handle the query to the Bard queryEngine
  try {
    _queryResponse = await randomOutcome('Response FromBard');
    // ToDo: use the queryService to handle the query to a queryEngine. For testing and development, pass an instance of queryService that uses a mock inside the sendQueryAsync
    // _queryResponse = await input.queryService.sendQueryAsync(
    //   input.queryString as string,
    //   input.queryEngineName,
    //   input.cTSToken,
    // );
  } catch (e) {
    // Rethrow the error with a more detailed error message
    HandleError(e, 'queryXXX', 'querySingleActorLogic', 'failed calling queryService.sendQueryAsync');
  }
  // always test the cancellation token after returning from an await to see if the function being awaited was cancelled
  if (input.cTSToken?.isCancellationRequested) {
    input.logger.log(
      `querySingleActorLogic leaving after await queryService.sendQueryAsync with cancelled = true`,
      LogLevel.Debug,
    );
    return { isCancelled: true } as IQuerySingleEngineActorLogicOutput;
  }
  input.logger.log(
    `querySingleActorLogic leaving with response = ${_queryResponse.result}, cancelled = false`,
    LogLevel.Debug,
  );
  return {
    queryEngineName: input.queryEngineName,
    queryResponse: _queryResponse.result,
    isCancelled: false,
  } as IQuerySingleEngineActorLogicOutput;
});

// **********************************************************************************************************************
// Machine definition for the querySingleEngineMachine

export const querySingleEngineMachine = setup({
  types: {} as {
    context: IQuerySingleEngineMachineContext;
    input: IQuerySingleEngineMachineInput;
    output: IQuerySingleEngineMachineOutput;
    events:
      | { type: 'QUERY.SINGLE_ENGINE_MACHINE_DONE'; payload: IQuerySingleEngineMachineDoneEventPayload }
      | { type: 'xstate.done.actor.querySingleEngineActor'; data: IQuerySingleEngineActorLogicOutput }
      | { type: 'xstate.error.actor.querySingleEngineActor'; data: { name: string; message: string } }
      | { type: 'DISPOSE_START' } // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
      | { type: 'DISPOSE_COMPLETE' };
    children: {
      querySingleEngineActor: 'querySingleEngineActor';
    };
  },
  actors: {
    querySingleEngineActor: querySingleEngineActorLogic,
  },
  actions: {
    disposingStateEntryAction: (context) => {
      context.context.logger.log(`disposingStateEntryAction, event type is ${context.event.type}`, LogLevel.Debug);
      // ToDo: add code to dispose of any allocated resource
    },
    disposeCompleteStateEntryAction: (context) => {
      context.context.logger.log(
        `disposeCompleteStateEntryAction, event type is ${context.event.type}`,
        LogLevel.Debug,
      );
      sendTo(context.context.parent, {
        type: 'DISPOSE_COMPLETE',
      });
    },
    sendQuerySingleEngineMachineDoneEvent: ({ context }) => {
      sendTo(context.parent, {
        type: 'QUERY.SiNGLE_ENGINE_MACHINE_DONE',
        payload: { queryEngineName: context.queryEngineName } as IQuerySingleEngineMachineDoneEventPayload,
      });
    },
  },
}).createMachine({
  context: ({ input }) => ({
    logger: input.logger,
    parent: input.parent,
    queryService: input.queryService,
    queryString: '',
    queryEngineName: input.queryEngineName,
    isCancelled: false,
    cTSToken: input.cTSToken,
  }),
  output: ({ context }) => ({
    queryEngineName: context.queryEngineName,
    response: context.response,
    isCancelled: context.isCancelled,
    errorMessage: context.errorMessage,
  }),
  type: 'parallel',
  states: {
    operationState: {
      states: {
        querySingleEngineActorState: {
          description: 'send a query to a single queryAgent and collect the result',
          invoke: {
            id: 'querySingleEngineActor',
            src: 'querySingleEngineActor',
            input: ({ context }) => ({
              logger: context.logger,
              queryService: context.queryService,
              queryString: context.queryString,
              queryEngineName: context.queryEngineName,
              cTSToken: context.cTSToken,
            }),
            onDone: {
              target: 'doneState',
              // set the context for response and isCancelled
              actions: assign({
                response: (_, event) => (event as any).output.response,
                isCancelled: (_, event) => (event as any).output.isCancelled,
              }),
            },
            onError: {
              // set the context for errorMessage and isCancelled
              target: 'errorState',
              actions: [
                assign({
                  response: undefined,
                  isCancelled: false,
                  errorMessage: (_, event) => (event as any).message,
                }),
              ],
            },
          },
          errorState: {
            // ToDO: add code to attempt to remediate the error, otherwise transition to doneState
            always: {
              target: 'doneState',
            },
          },
          doneState: {
            description:
              'querySingleEngineMachine  is done. send the QUERY.SINGLE_ENGINE_MACHINE_DONE event to the parent machine (queryMachine)',
            type: 'final',
            entry: 'sendQuerySingleEngineMachineDoneEvent',
          },
        },
      },
    },
    disposeState: {
      // 2nd parallel state. This state can be transitioned to from any state
      initial: 'inactiveState',
      states: {
        inactiveState: {
          on: {
            DISPOSE_START: 'disposingState',
          },
        },
        disposingState: {
          entry: 'disposingStateEntryAction',
          on: {
            DISPOSE_COMPLETE: {
              target: 'disposeCompleteState',
            },
          },
        },
        disposeCompleteState: {
          entry: 'disposeCompleteStateEntryAction',
          type: 'final',
        },
      },
    },
  },
});

// **********************************************************************************************************************
// Machine definition for the queryMachine
export const queryMachine = setup({
  types: {} as {
    context: IQueryMachineContext;
    input: IQueryMachineInput;
    output: IQueryMachineOutput;
    events:
      | { type: 'QUERY.SINGLE_ENGINE_MACHINE_DONE'; payload: IQuerySingleEngineMachineDoneEventPayload }
      | { type: 'QUERY.QUERY_MACHINE_DONE' }
      | { type: 'DISPOSE_START' } // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
      | { type: 'DISPOSE_COMPLETE' };
    children: {
      gatheringActor: 'gatheringActorLogic';
      querySingleEngineMachine: 'querySingleEngineMachine';
    };
  },
  actors: {
    gatheringActorLogic: queryGatheringActorLogic,
    querySingleEngineMachine: querySingleEngineMachine,
  },
  actions: {
    // spawn a querySingleEngineMachine for each enabled queryAgent and store the actor references in the context.querySingleEngineActorRefs
    fetchingStateEntryAction: assign({
      querySingleEngineActorRefs: ({ context, spawn, event, self }) => {
        // create a local variable to hold the new querySingleEngineActorRefs object
        let _querySingleEngineActorRefs: QuerySingleEngineActorRefsT = {} as QuerySingleEngineActorRefsT;
        // spawn a querySingleEngineMachine for each enabled queryAgent
        Object.entries(QueryEngineFlagsEnum)
          .filter(
            // get just the active query engines
            ([name, queryEngineFlagValue]) =>
              context.currentQueryEngines & (queryEngineFlagValue as QueryEngineFlagsEnum),
          )
          // convert from the name of the enumeration values (string) to the actual entire enumeration object
          .map(([name]) => QueryEngineNamesEnum[name as keyof typeof QueryEngineNamesEnum])
          // iterate over each active enumeration object and spawn a querySingleEngineMachine for each
          .forEach((name) => {
            const _actorRef = spawn('querySingleEngineMachine', {
              systemId: `qSAM-${name}`,
              id: 'querySingleEngineMachine',
              input: {
                logger: context.logger,
                queryEngineName: name,
                parent: self,
                queryService: context.queryService,
                queryString: context.queryString as string,
                cTSToken: context.cTSToken,
              },
            });
            const _subscription = _actorRef.subscribe((state) => {});
            //store the spawned actor reference and its subscription in the querySingleEngineActorRefs object keyed by the enumeration object
            _querySingleEngineActorRefs[name] = { actorRef: _actorRef, subscription: _subscription };
          });
        // return the new _querySingleEngineActorRefs structure, placing it into the context.querySingleEngineActorRefs
        return _querySingleEngineActorRefs;
      },
    }),
    sendQueryMachineDoneEvent: (context) => {
      sendTo(context.context.parent, {
        type: 'QUERY.QUERY_MACHINE_DONE',
      });
    },
    disposingStateEntryAction: (context) => {
      context.context.logger.log(`disposingStateEntryAction, event type is ${context.event.type}`, LogLevel.Debug);
      // ToDo: add code to dispose of any allocated resource
    },
    disposeCompleteStateEntryAction: (context) => {
      context.context.logger.log(
        `disposeCompleteStateEntryAction, event type is ${context.event.type}`,
        LogLevel.Debug,
      );
      sendTo(context.context.parent, {
        type: 'DISPOSE_COMPLETE',
      });
    },
  },
  guards: {
    allQuerySingleEngineActorOutputsDefined: (context) => {
      const _querySingleEngineActorRefs = context.context.querySingleEngineActorRefs as QuerySingleEngineActorRefsT;
      const _querySingleEngineActorOutputs = context.context
        .querySingleEngineActorOutputs as QuerySingleEngineActorOutputsT;
      return (
        Object.keys(context.context.querySingleEngineActorRefs as QuerySingleEngineActorRefsT).length ===
        Object.keys(context.context.querySingleEngineActorOutputs as QuerySingleEngineActorOutputsT).length
      );
    },
  },
}).createMachine({
  id: 'queryMachine',
  context: ({ input }) => ({
    logger: input.logger,
    parent: input.parent,
    queryService: input.queryService,
    queryFragmentCollection: input.queryFragmentCollection,
    currentQueryEngines: input.currentQueryEngines,
    cTSToken: input.cTSToken,
    isCancelled: false,
  }),
  output: ({ context }) => ({
    querySingleEngineActorOutputs: context.querySingleEngineActorOutputs,
    isCancelled: context.isCancelled,
    errorMessage: context.errorMessage,
  }),
  type: 'parallel',
  states: {
    operationState: {
      initial: 'gatheringState',
      states: {
        gatheringState: {
          description:
            'given an ordered collection of fragment identifiers, gather the fragments and assemble them into a query string',
          invoke: {
            id: 'gatheringActor',
            src: 'gatheringActorLogic',
            input: ({ context }) => ({
              logger: context.logger,
              queryFragmentCollection: context.queryFragmentCollection,
              cTSToken: context.cTSToken,
            }),
            onDone: {
              target: 'fetchingState',
              actions:
                // set the context for queryString and isCancelled
                assign({
                  queryString: (_, event) => (event as any).output.queryString,
                  //isCancelled: (_, event) => (event as {type: 'xstate.done.actor.gatheringActor'; output: IQueryGatheringActorLogicOutput}).output.isCancelled,           }
                  isCancelled: (_, event) => (event as any).output.isCancelled,
                }),
            },
            onError: {
              target: 'errorState',
              actions:
                // set the context for errorMessage and isCancelled
                assign({
                  queryString: undefined,
                  isCancelled: false,
                  errorMessage: (_, event) => (event as any).message,
                }),
            },
          },
        },
        fetchingState: {
          id: 'fetchingState',
          description: 'given a query string, send it to every enabled queryAgent and collect the results',
          entry: 'fetchingStateEntryAction', // this entry action spawns a querySingleEngineMachine for each enabled queryAgent and stores the actor references in the context.querySingleEngineActorRefs

          // when a querySingleEngineMachine is done, it will send the QUERY.SINGLE_ENGINE_MACHINE_DONE event to this machine
          // when this machine receives a QUERY.SINGLE_ENGINE_MACHINE_DONE event it will:
          // read the event payload for the engineName
          // get the corresponding actorRef, confirm it is in done state,
          // and assign the output of the querySingleEngineMachine of type IQuerySingleEngineMachineOutput to the value of context.querySingleEngineActorOutputs instance keyed by the engineName
          // ToDo: Notify this machine's parent machine (primaryMachine) that one querySingleEngineMachine is done and send the instance of the IQuerySingleEngineMachineOutput to its parent
          // transition to the doneState guarded by condition that all of the context.querySingleEngineActorOutputs instances are defined for every entry in context.querySingleEngineActorRefs
          on: {
            'QUERY.SINGLE_ENGINE_MACHINE_DONE': {
              target: 'waitingForAllState',
              actions: [
                // assign to querySingleEngineActorOutputs in this machine's context the output of the querySingleEngineMachine
                assign(({ context, event }) => {
                  assertEvent(event, 'QUERY.SINGLE_ENGINE_MACHINE_DONE');
                  const _queryEngineName = event.payload.queryEngineName;
                  const _querySingleEngineMachineRef = context.querySingleEngineActorRefs![_queryEngineName];
                  // confirm the querySingleEngineMachine is done
                  if (_querySingleEngineMachineRef.actorRef.getSnapshot().status !== 'done') {
                    throw new Error('OMG how can this happen??!! Gotta submit an xState issue if this ever pops up');
                  }
                  const _querySingleEngineActorResponse = _querySingleEngineMachineRef.actorRef.getSnapshot().output;
                  const _querySingleEngineActorOutputs =
                    context.querySingleEngineActorOutputs as QuerySingleEngineActorOutputsT;
                  _querySingleEngineActorOutputs[_queryEngineName] = _querySingleEngineActorResponse;
                  return {
                    querySingleEngineActorOutputs: _querySingleEngineActorOutputs,
                  };
                }),
              ],
            },
          },
        },
        waitingForAllState: {
          // if all context.querySingleEngineActorOutputs are defined, transition to the doneState
          // else transition back to the fetchingState, (note that reset is NOT true, so entry actions will not be re-executed)
          always: [
            { target: 'doneState', guard: 'allQuerySingleEngineActorOutputsDefined' },
            { target: 'fetchingState' },
          ],
        },
        errorState: {
          // ToDO: add code to attempt to remediate the error, otherwise transition to doneState
          always: {
            target: 'doneState',
          },
        },
        doneState: {
          description:
            'all querySingleEngineMachines are done the querySingleEngineActorOutputs are all defined. Send the QUERY.QUERY_MACHINE_DONE to the parent machine',
          type: 'final',
          entry: 'sendQueryMachineDoneEvent',
        },
      },
    },
    disposeState: {
      // 2nd parallel state. This state can be transitioned to from any state
      initial: 'inactiveState',
      states: {
        inactiveState: {
          on: {
            DISPOSE_START: 'disposingState',
          },
        },
        disposingState: {
          entry: 'disposingStateEntryAction',
          on: {
            DISPOSE_COMPLETE: {
              target: 'disposeCompleteState',
            },
          },
        },
        disposeCompleteState: {
          entry: 'disposeCompleteStateEntryAction',
          type: 'final',
        },
      },
    },
  },
});

export interface IPrimaryMachineInput extends IAllMachinesBaseContext {
  queryService: IQueryService;
}

export interface IPrimaryMachineContext
  extends IPrimaryMachineInput,
    IQuickPickMachineComponentOfPrimaryMachineContext,
    IQueryMachineComponentOfPrimaryMachineContext {}

// create the primaryMachine definition
export const primaryMachine = setup({
  types: {} as {
    context: IPrimaryMachineContext;
    input: IPrimaryMachineInput;
    events:
      | { type: 'QUICKPICK_START'; payload: IQuickPickEventPayload }
      | { type: 'QUICKPICK_QUICKPICK_MACHINE_DONE' }
      | { type: 'QUERY_START'; payload: IQueryEventPayload }
      | { type: 'QUERY_QUERY_MACHINE_DONE' }
      | { type: 'DISPOSE_START' } // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.
      | { type: 'DISPOSE_COMPLETE' };
  },
  actions: {
    spawnQuickPickMachine: assign(({ context, spawn, event, self }) => {
      const _actorRef = spawn('quickPickMachine', {
        systemId: 'quickPickMachine',
        id: 'quickPickMachine',
        input: {
          logger: context.logger,
          parent: self,
          pickValue: (event as { type: 'QUICKPICK_START'; payload: IQuickPickEventPayload }).payload.pickValue,
          pickItems: (event as { type: 'QUICKPICK_START'; payload: IQuickPickEventPayload }).payload.pickItems,
          prompt: (event as { type: 'QUICKPICK_START'; payload: IQuickPickEventPayload }).payload.prompt,
          cTSToken: (event as { type: 'QUICKPICK_START'; payload: IQuickPickEventPayload }).payload.cTSToken,
        },
      });
      const _subscription = _actorRef.subscribe((state) => {
        /* ToDo: */
      });
      return {
        quickPickMachineActorRef: {
          actorRef: _actorRef,
          subscription: _subscription,
        },
      };
    }),
    spawnQueryMachine: assign(({ context, spawn, event, self }) => {
      const _actorRef = spawn('queryMachine', {
        systemId: 'queryMachine',
        id: 'queryMachine',
        input: {
          logger: context.logger,
          parent: self,
          queryService: context.queryService,
          queryFragmentCollection: (event as { type: 'QUERY_START'; payload: IQueryEventPayload }).payload
            .queryFragmentCollection,
          currentQueryEngines: (event as { type: 'QUERY_START'; payload: IQueryEventPayload }).payload
            .currentQueryEngines,
          cTSToken: (event as { type: 'QUERY_START'; payload: IQueryEventPayload }).payload.cTSToken,
        },
      });
      const _subscription = _actorRef.subscribe((state) => {});

      return {
        queryMachineActorRef: {
          actorRef: _actorRef,
          subscription: _subscription,
        },
      };
    }),
    updateUIStateEntryAction: (context) => {
      context.context.logger.log(`updateUIStateEntryAction, event type is ${context.event.type}`, LogLevel.Debug);
    },
    updateUIStateExitAction: (context) => {
      context.context.logger.log(
        `updateUIStateupdateUIStateExitActionEntryAction, event type is ${context.event.type}`,
        LogLevel.Debug,
      );
    },
    updateUIStateQueryMachineDone: ({ context, event }) => {
      assertEvent(event, 'QUERY_QUERY_MACHINE_DONE');
      context.logger.log(
        `updateUIStateupdateUIStateExitActionEntryAction, context.queryMachineOutput is ${context.queryMachineOutput}`,
        LogLevel.Debug,
      );
      // if queryMachineOutput.isCancelled is true, clean up any small UI elements
      // if queryMachineOutput.errorMessage is defined, display the error message in the UI
      // if queryMachineOutput.isCancelled is false,
      //  and also context.queryMachineOutput!.querySingleEngineActorOutputs.isCancelled is false for all keys, then update the UI
      // ToDO: what if some are cancelled but others have returned responses?
    },
    disposingStateEntryAction: ({ context, event }) => {
      context.logger.log(`disposingStateEntryAction, event type is ${event.type}`, LogLevel.Debug);
    },
    disposeCompleteStateEntryAction: ({ context, event }) => {
      context.logger.log(`disposeCompleteStateEntryAction, event type is ${event.type}`, LogLevel.Debug);
      // Todo: add code to send the DISPOSE_EVENT to any spawned MachineActorRef so that it can free any allocated resources
      // ToDo: current machineActorRefs are queryMachineActorRef and (toDo) quickPickMachineActorRef
      // ToDo: add code to dispose of any allocated resource
    },
  },
  actors: {
    quickPickMachine: quickPickMachine,
    queryMachine: queryMachine,
  },
}).createMachine({
  id: 'primaryMachine',
  context: ({ input }) => ({
    logger: input.logger,
    //data: input.data,
    quickPickMachineActorRef: undefined,
    quickPickMachineOutput: undefined,
    queryService: input.queryService,
    queryMachineActorRef: undefined,
    queryMachineOutput: undefined,
  }),
  type: 'parallel',
  states: {
    operationState: {
      // This state handles the main operation of the machine. First of two parallel states
      initial: 'idleState',
      states: {
        idleState: {
          on: {
            QUICKPICK_START: {
              target: 'quickPickState',
            },
            QUERY_START: {
              target: 'queryingState',
            },
            QUERY_QUERY_MACHINE_DONE: {
              target: 'updateUIState',
              actions: assign({
                queryMachineOutput: ({ context }) => {
                  // copy the results (output) from the queryMachine to the context
                  const _queryMachineActorRef = context.queryMachineActorRef as ActorRefAndSubscriptionT;
                  // confirm the queryMachineActor is done
                  if (_queryMachineActorRef.actorRef.getSnapshot().status !== 'done') {
                    throw new Error('OMG how can this happen??!! Gotta submit an xState issue if this ever pops up');
                  }
                  return _queryMachineActorRef.actorRef.getSnapshot().output as IQueryMachineOutput;
                },
                queryMachineActorRef: undefined,
              }),
            },
            QUICKPICK_QUICKPICK_MACHINE_DONE: {
              target: 'updateUIState',
            },
          },
        },
        errorState: {
          // ToDO: add code to attempt to remediate the error, otherwise transition to finalErrorState and throw an error
          always: {
            target: 'idleState',
          },
        },
        quickPickState: {
          description:
            "A parent state with child states that allow a user to see a list of available enumeration values, pick one, update the extension (transition it) to the UI indicated by the new value, update the 'currentValue' of the enumeration, and then return to the Idle state.",
          entry: 'spawnQuickPickMachine', // spawn the quickPickMachine and store the reference in the context
          always: 'idleState',
        },
        queryingState: {
          description:
            'A state that spawns a queryMachine which encapsulates multiple states for handling parallel queries to multiple QueryAgents.',
          entry: 'spawnQueryMachine', // spawn the queryMachine and store the reference in the context
          always: 'idleState',
        },
        updateUIState: {
          description: 'appearance',
          entry: 'updateUIStateEntryAction',
          exit: 'updateUIStateExitAction',
          // ToDo: all the various on... events
          on: {
            QUERY_QUERY_MACHINE_DONE: {
              target: 'idleState',
              actions: 'updateUIStateQueryMachineDone',
            },
            QUICKPICK_QUICKPICK_MACHINE_DONE: {
              target: 'idleState',
            },
          },
        },
      },
    },
    disposeState: {
      // 2nd parallel state. This state can be transitioned to from any state
      initial: 'inactiveState',
      states: {
        inactiveState: {
          on: {
            DISPOSE_START: 'disposingState',
          },
        },
        disposingState: {
          entry: 'disposingStateEntryAction',

          on: {
            DISPOSE_COMPLETE: {
              target: 'disposeCompleteState',
            },
          },
        },
        disposeCompleteState: {
          entry: 'disposeCompleteStateEntryAction',
          type: 'final',
        },
      },
    },
  },
  on: {
    // Global transition to disposingState
    DISPOSE_START: 'disposingState',
  },
});
