import { randomOutcome } from '@Utilities/index'; // ToDo: replace with a mocked iQueryService instead of using this import
import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { ActorRef, assertEvent, assign, fromPromise, OutputFrom, sendTo, setup } from 'xstate';

import { QueryFragmentEnum, QueryEngineNamesEnum, QueryEngineFlagsEnum } from '@BaseEnumerations/index';

import { IQueryService } from '@QueryService/index';

import { IQueryFragmentCollection } from '@ItemWithIDs/index';

import { DetailedError, HandleError } from '@ErrorClasses/index';

import {
  IAllMachinesBaseContext,
  IActorRefAndSubscription,
  IAllMachinesCommonResults,
} from '@StateMachineService/index';

import {
  IQuerySingleEngineMachineInput,
  IQuerySingleEngineMachineContext,
  IQuerySingleEngineMachineOutput,
  IQuerySingleEngineActorLogicInput,
  IQuerySingleEngineActorLogicOutput,
  IQuerySingleEngineMachineDoneEventPayload,
  querySingleEngineMachine,
} from '@StateMachineService/index';

export type QuerySingleEngineActorOutputsT = Record<QueryEngineNamesEnum, IQuerySingleEngineActorLogicOutput>;
export type QuerySingleEngineActorRefsT = Record<QueryEngineNamesEnum, IActorRefAndSubscription>;

export interface IQuerySingleEngineComponentOfQueryMultipleEngineMachineContext {
  querySingleEngineActorRefs: QuerySingleEngineActorRefsT;
  querySingleEngineActorOutputs: Partial<QuerySingleEngineActorOutputsT>; // partial because the instance doesn't have to have every member of the enumeration
}

// **********************************************************************************************************************
// context type, input type, output type, and event payload types for the queryMultipleEngineMachine
export interface IQueryMultipleEngineMachineInput extends IAllMachinesBaseContext, IQueryMultipleEngineEventPayload {
  parent: ActorRef<any, any>;
  currentQueryEngines: QueryEngineFlagsEnum;
  queryService: IQueryService;
}
export interface IQueryMultipleEngineMachineContext
  extends IQueryMultipleEngineMachineInput,
    IQueryGatheringActorComponentOfQueryMultipleEngineMachineContext,
    IQuerySingleEngineComponentOfQueryMultipleEngineMachineContext,
    IAllMachinesCommonResults {}
export interface IQueryMultipleEngineMachineOutput
  extends Omit<IQuerySingleEngineComponentOfQueryMultipleEngineMachineContext, 'querySingleEngineActorRefs'>,
    IAllMachinesCommonResults {}

export interface IQueryMultipleEngineEventPayload {
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
}

export interface INotifyCompleteActionParameters {
  logger: ILogger;
  sendToTargetActorRef: ActorRef<any, any>;
  eventCausingTheTransitionIntoOuterDoneState: QueryMultipleEngineMachineCompletionEventsT;
}

// **********************************************************************************************************************
// input and output to the QueryGatheringActorLogicSource
export interface IQueryGatheringActorComponentOfQueryMultipleEngineMachineContext {
  queryString?: string;
}
export interface IQueryGatheringActorLogicInput extends IAllMachinesBaseContext {
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
}
export interface IQueryGatheringActorLogicOutput
  extends IQueryGatheringActorComponentOfQueryMultipleEngineMachineContext,
    IAllMachinesCommonResults {}

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
// parameter type for the QueryMultipleEngineMachineNotifyCompleteAction
export interface IQueryMultipleEngineMachineNotifyCompleteActionParameters {
  logger: ILogger;
  sendToTargetActorRef: ActorRef<any, any>;
  eventCausingTheTransitionIntoOuterDoneState: QueryMultipleEngineMachineCompletionEventsT;
  queryEngineName: QueryEngineNamesEnum;
}

export type QueryMultipleEngineMachineCompletionEventsT =
  | { type: 'xstate.done.actor.gatheringActor'; output: IQueryGatheringActorLogicOutput }
  | { type: 'xstate.error.actor.gatheringActor'; message: string }
  | { type: 'QUERY_SINGLE_ENGINE_MACHINE_DONE'; payload: IQuerySingleEngineMachineDoneEventPayload }
  //| { type: 'xstate.done.actor.queryMultipleEngineActor'; output: IQueryMultipleEngineActorLogicOutput }
  //| { type: 'xstate.error.actor.queryMultipleEngineActor'; message: string }
  | { type: 'xstate.done.actor.disposeActor' }
  | { type: 'xstate.error.actor.disposeActor'; message: string };
export type QueryMultipleEngineMachineNotifyEventsT = { type: 'QUERY_DONE' } | { type: 'DISPOSE_COMPLETE' };
type QueryMultipleEngineMachineAllEventsT =
  | QueryMultipleEngineMachineCompletionEventsT
  | QueryMultipleEngineMachineNotifyEventsT
  | { type: 'DISPOSE_START' }; // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.

// **********************************************************************************************************************
// Machine definition for the queryMultipleEngineMachine
export const queryMultipleEngineMachine = setup({
  types: {} as {
    context: IQueryMultipleEngineMachineContext;
    input: IQueryMultipleEngineMachineInput;
    output: IQueryMultipleEngineMachineOutput;
    events: QueryMultipleEngineMachineAllEventsT;
    children: {
      gatheringActor: 'gatheringActor';
    };
  },
  actors: {
    gatheringActor: queryGatheringActorLogic,
  },
  actions: {
    // spawn a querySingleEngineMachine for each enabled queryAgent and store the actor references in the context.querySingleEngineActorRefs
    // fetchingStateEntryAction: assign({
    //   querySingleEngineActorRefs: ({ context, spawn, event, self }) => {
    //     context.logger.log(`fetchingStateEntryAction started`, LogLevel.Debug);
    // create a local variable to hold the new querySingleEngineActorRefs object

    // const numActive = Object.entries(QueryEngineFlagsEnum).filter(
    //   // get just the active query engines
    //   ([name, queryEngineFlagValue]) =>
    //     context.currentQueryEngines & (queryEngineFlagValue as QueryEngineFlagsEnum),
    // ).length;
    // context.logger.log(
    //   `fetchingStateEntryAction numActive = ${numActive} querySingleEngineMachine(s) to be created`,
    //   LogLevel.Debug,
    // );

    //   let _querySingleEngineActorRefs: QuerySingleEngineActorRefsT = {} as QuerySingleEngineActorRefsT;
    //   // spawn a querySingleEngineMachine for each enabled queryAgent
    //   Object.entries(QueryEngineFlagsEnum)
    //     .filter(
    //       // get just the active query engines
    //       ([name, queryEngineFlagValue]) =>
    //         context.currentQueryEngines & (queryEngineFlagValue as QueryEngineFlagsEnum),
    //     )
    //     // convert from the name of the enumeration values (string) to the actual entire enumeration object
    //     .map(([name]) => QueryEngineNamesEnum[name as keyof typeof QueryEngineNamesEnum])
    //     // iterate over each active enumeration object and spawn a querySingleEngineMachine for each
    //     .forEach((name) => {
    //       const _actorRef = spawn('querySingleEngineMachine', {
    //         systemId: `qSAM-${name}`,
    //         id: 'querySingleEngineMachine',
    //         input: {
    //           logger: context.logger,
    //           queryEngineName: name,
    //           parent: self,
    //           queryService: context.queryService,
    //           queryString: context.queryString as string,
    //           cTSToken: context.cTSToken,
    //         },
    //       });
    //       const _subscription = _actorRef.subscribe((state) => {});
    //       //store the spawned actor reference and its subscription in the querySingleEngineActorRefs object keyed by the enumeration object
    //       _querySingleEngineActorRefs[name] = { actorRef: _actorRef, subscription: _subscription };
    //     });
    //   context.logger.log(
    //     `fetchingStateEntryAction created ${Object.keys(_querySingleEngineActorRefs).length} querySingleEngineMachine(s)`,
    //     LogLevel.Debug,
    //   );

    //   // return the new _querySingleEngineActorRefs structure, placing it into the context.querySingleEngineActorRefs
    //   return _querySingleEngineActorRefs;
    //   },
    // }),
    assignGatheringActorDoneOutputToQueryMachineContext: assign(({ context, spawn, event, self }) => {
      assertEvent(event, 'xstate.done.actor.gatheringActor');
      return {
        queryString: event.output.queryString,
        isCancelled: event.output.isCancelled,
      };
    }),

    assignGatheringActorErrorOutputToQueryMachineContext: assign(({ context, spawn, event, self }) => {
      assertEvent(event, 'xstate.error.actor.gatheringActor');
      return {};
    }),
    assignQuerySingleEngineMachineDoneOutputToQueryMultipleEngineMachineContext: assign(
      ({ context, spawn, event, self }) => {
        assertEvent(event, 'QUERY_SINGLE_ENGINE_MACHINE_DONE');
        const _queryEngineName = event.payload.queryEngineName;
        const _querySingleEngineMachineRef = context.querySingleEngineActorRefs![_queryEngineName];
        // confirm the querySingleEngineMachine is done
        if (_querySingleEngineMachineRef.actorRef.getSnapshot().status !== 'done') {
          throw new Error('OMG how can this happen??!! Gotta submit an xState issue if this ever pops up');
        }
        const _oneSingleEngineMachineOutput = context.querySingleEngineActorRefs[
          _queryEngineName
        ].actorRef.getSnapshot().output as IQuerySingleEngineMachineOutput;
        const _querySingleEngineActorOutputs =
          context.querySingleEngineActorOutputs as Partial<QuerySingleEngineActorOutputsT>;
        _querySingleEngineActorOutputs[_queryEngineName] = _oneSingleEngineMachineOutput;
        return {
          querySingleEngineActorOutputs: _querySingleEngineActorOutputs,
        };
      },
    ),
    sendQueryMachineDoneEvent: ({ context }) => {
      sendTo(context.parent, {
        type: 'QUERY_DONE',
      });
    },
    disposingStateEntryAction: (context) => {
      context.context.logger.log(`disposingStateEntryAction, event type is ${context.event.type}`, LogLevel.Debug);
      // ToDo: add code to dispose of any allocated resource
    },
    disposeCompleteStateEntryAction: ({ context, event }) => {
      context.logger.log(`disposeCompleteStateEntryAction, event type is ${event.type}`, LogLevel.Debug);
    },
    debugMachineContext: ({ context, event }) => {
      context.logger.log(
        `debugMachineContext, context.querySingleEngineActorOutputs: ${context.querySingleEngineActorOutputs}, TBD`,
        LogLevel.Debug,
      );
    },
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
        let _eventToSend: { type: 'QUERY_DONE' } | { type: 'DISPOSE_COMPLETE' };
        switch (params.eventCausingTheTransitionIntoOuterDoneState.type) {
          // case 'xstate.done.actor.queryMultipleEngineMachineActor':
          //   _eventToSend = { type: 'QUERY_DONE' };
          //   break;
          // case 'xstate.done.actor.queryMultipleEngineMachineDisposeActor':
          //   _eventToSend = { type: 'DISPOSE_COMPLETE' };
          //   break;
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
  },
  guards: {
    allQuerySingleEngineActorOutputsDefined: (context) => {
      const _querySingleEngineActorRefs = context.context.querySingleEngineActorRefs as QuerySingleEngineActorRefsT;
      const _querySingleEngineActorOutputs = context.context
        .querySingleEngineActorOutputs as Partial<QuerySingleEngineActorOutputsT>;
      return (
        Object.keys(context.context.querySingleEngineActorRefs as QuerySingleEngineActorRefsT).length ===
        Object.keys(context.context.querySingleEngineActorOutputs as Partial<QuerySingleEngineActorOutputsT>).length
      );
    },
  },
}).createMachine({
  id: 'queryMultipleEngineMachine',
  context: ({ input }) => ({
    logger: input.logger,
    parent: input.parent,
    queryService: input.queryService,
    queryFragmentCollection: input.queryFragmentCollection,
    currentQueryEngines: input.currentQueryEngines,
    querySingleEngineActorRefs: {} as QuerySingleEngineActorRefsT,
    querySingleEngineActorOutputs: {} as Partial<QuerySingleEngineActorOutputsT>,
    cTSToken: input.cTSToken,
    isCancelled: false,
  }),
  output: ({ context }) =>
    ({
      querySingleEngineActorOutputs: context.querySingleEngineActorOutputs,
      isCancelled: context.isCancelled,
      errorMessage: context.errorMessage,
    }) as IQueryMultipleEngineMachineOutput,
  initial: 'startedState',
  states: {
    startedState: {
      // entry: ({ context }) => {
      //   context.logger.log(`queryMultipleEngineMachine startedState entry`, LogLevel.Debug);
      // },
      // type: 'parallel',
      // states: {
      //   operationState: {
      //     initial: 'gatheringState',
      //     entry: ({ context }) => {
      //       context.logger.log(`operationState entry`, LogLevel.Debug);
      //     },
      //     states: {
      //       gatheringState: {
      //         description:
      //           'given an ordered collection of fragment identifiers, gather the fragments and assemble them into a query string',
      //         entry: ({ context }) => {
      //           context.logger.log(`gatheringState entry`, LogLevel.Debug);
      //         },
      //         invoke: {
      //           id: 'gatheringActor',
      //           src: 'gatheringActor',
      //           input: ({ context }) => ({
      //             logger: context.logger,
      //             queryFragmentCollection: context.queryFragmentCollection,
      //             cTSToken: context.cTSToken,
      //           }),
      //           onDone: {
      //             target: 'fetchingState',
      //             // set the context for queryString and isCancelled
      //             actions: 'assignGatheringActorDoneOutputToQueryMachineContext',
      //           },
      //           onError: {
      //             target: 'errorState',
      //             actions: 'assignGatheringActorErrorOutputToQueryMachineContext',
      //           },
      //         },
      //       },
      //       fetchingState: {
      //         id: 'fetchingState',
      //         description: 'given a query string, send it to every enabled queryAgent and collect the results',
      //         entry:
      //           // this entry action spawns a querySingleEngineMachine for each enabled queryAgent and stores the actor references in the context.querySingleEngineActorRefs
      //           'fetchingStateEntryAction',
      //         // when a querySingleEngineMachine is done, it will send the QUERY.SINGLE_ENGINE_MACHINE_DONE event to this machine
      //         // when this machine receives a QUERY.SINGLE_ENGINE_MACHINE_DONE event it will:
      //         // read the event payload for the engineName
      //         // get the corresponding actorRef, confirm it is in done state,
      //         // and assign the output of the querySingleEngineMachine of type IQuerySingleEngineMachineOutput to the value of context.querySingleEngineActorOutputs instance keyed by the engineName
      //         // ToDo: Notify this machine's parent machine (primaryMachine) that one querySingleEngineMachine is done and send the instance of the IQuerySingleEngineMachineOutput to its parent
      //         // transition to the doneState guarded by condition that all of the context.querySingleEngineActorOutputs instances are defined for every entry in context.querySingleEngineActorRefs
      //         on: {
      //           QUERY_SINGLE_ENGINE_MACHINE_DONE: {
      //             target: 'waitingForAllState',
      //             actions: 'assignQuerySingleEngineMachineDoneOutputToQueryMultipleEngineMachineContext', // assign to querySingleEngineActorOutputs in this machine's context the output of the querySingleEngineMachine
      //           },
      //         },
      //       },
      //       waitingForAllState: {
      //         // if all context.querySingleEngineActorOutputs are defined, transition to the doneState
      //         // else transition back to the fetchingState, (note that reset is NOT true, so entry actions will not be re-executed)
      //         always: [
      //           { target: 'doneState', guard: 'allQuerySingleEngineActorOutputsDefined' },
      //           { target: 'fetchingState' },
      //         ],
      //       },
      //       errorState: {
      //         // ToDO: add code to attempt to remediate the error, otherwise transition to doneState
      //         always: {
      //           target: 'doneState',
      //         },
      //       },
      //       doneState: {
      //         description:
      //           'all querySingleEngineMachines are done the querySingleEngineActorOutputs are all defined. Send the QUERY_DONE to the parent machine',
      //         type: 'final',
      //         entry: 'sendQueryMachineDoneEvent',
      //       },
      //     },
      //   },
      //   disposeState: {
      //     // 2nd parallel state. This state can be transitioned to from any state
      //     initial: 'inactiveState',
      //     states: {
      //       inactiveState: {
      //         on: {
      //           DISPOSE_START: 'disposingState',
      //         },
      //       },
      //       disposingState: {
      //         entry: 'disposingStateEntryAction',
      //         on: {
      //           DISPOSE_COMPLETE: {
      //             target: 'disposeCompleteState',
      //           },
      //         },
      //       },
      //       disposeCompleteState: {
      //         entry: 'disposeCompleteStateEntryAction',
      //         type: 'final',
      //       },
      //     },
      //   },
      // },
    },
    outerDoneState: {
      type: 'final',
      entry: [
        {
          type: 'notifyCompleteAction',
          params: ({ context, event }) =>
            ({
              logger: context.logger,
              sendToTargetActorRef: context.parent,
              eventCausingTheTransitionIntoOuterDoneState: event,
            }) as INotifyCompleteActionParameters,
        },
        'debugMachineContext',
      ],
    },
  },
});
