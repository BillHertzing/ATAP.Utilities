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

// **********************************************************************************************************************
// context type, input type, output type, and event payload types for the querySingleEngineMachine

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
  logger: ILogger;
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
export interface INotifyCompleteActionParameters {
  logger: ILogger;
  sendToTargetActorRef: ActorRef<any, any>;
  eventCausingTheTransitionIntoOuterDoneState: QuerySingleEngineMachineCompletionEventsT;
  queryEngineName: QueryEngineNamesEnum;
}

// **********************************************************************************************************************
// actor logic definition for the querySingleEngineActorLogic
export const querySingleEngineActorLogic = fromPromise<
  IQuerySingleEngineActorLogicOutput,
  IQuerySingleEngineActorLogicInput
>(async ({ input }: { input: IQuerySingleEngineActorLogicInput }) => {
  input.logger.log(`querySingleEngineActorLogic called`, LogLevel.Debug);
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
    HandleError(e, 'queryXXX', 'querySingleEngineActorLogic', 'failed calling queryService.sendQueryAsync');
  }
  // always test the cancellation token after returning from an await to see if the function being awaited was cancelled
  if (input.cTSToken?.isCancellationRequested) {
    input.logger.log(
      `querySingleEngineActorLogic leaving after await queryService.sendQueryAsync with cancelled = true`,
      LogLevel.Debug,
    );
    return { isCancelled: true } as IQuerySingleEngineActorLogicOutput;
  }
  input.logger.log(
    `querySingleEngineActorLogic leaving with response = ${_queryResponse.result}, cancelled = false`,
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
export type QuerySingleEngineMachineCompletionEventsT =
  | { type: 'xstate.done.actor.querySingleEngineActor'; output: IQuerySingleEngineActorLogicOutput }
  | { type: 'xstate.error.actor.querySingleEngineActor'; message: string }
  | { type: 'xstate.done.actor.disposeActor' }
  | { type: 'xstate.error.actor.disposeActor'; message: string };
export type QuerySingleEngineMachineNotifyEventsT =
  | { type: 'QUERY.SINGLE_ENGINE_MACHINE_DONE'; payload: IQuerySingleEngineMachineDoneEventPayload }
  | { type: 'DISPOSE_COMPLETE' };
type AllQuerySingleEngineMachineEventsT =
  | QuerySingleEngineMachineCompletionEventsT
  | QuerySingleEngineMachineNotifyEventsT
  | { type: 'DISPOSE_START' }; // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.

type QuerySingleEngineMachineAllEventsT =
  | QuerySingleEngineMachineCompletionEventsT
  | QuerySingleEngineMachineNotifyEventsT
  | { type: 'DISPOSE_START' }; // Can be called at any time. The machine must transition to the disposeState.disposingState, where any allocated resources will be freed.

export interface IQuerySingleEngineMachineNotifyCompleteActionParameters {
  logger: ILogger;
  sendToTargetActorRef: ActorRef<any, any>;
  eventCausingTheTransitionIntoOuterDoneState: QuerySingleEngineMachineCompletionEventsT;
  queryEngineName: QueryEngineNamesEnum;
}

export const querySingleEngineMachine = setup({
  types: {} as {
    context: IQuerySingleEngineMachineContext;
    input: IQuerySingleEngineMachineInput;
    output: IQuerySingleEngineMachineOutput;
    events: QuerySingleEngineMachineAllEventsT;
    children: {
      querySingleEngineActor: 'querySingleEngineActor';
    };
  },
  actors: {
    querySingleEngineActor: querySingleEngineActorLogic,
  },
  actions: {
    debugMachineContext: ({ context, event }) => {
      context.logger.log(
        `QuerySingleEngineContext, context.queryEngineName: ${context.queryEngineName},   context.queryString: ${context.queryString}, context.response: ${context!.response}, context.isCancelled: ${context.isCancelled}`,
        LogLevel.Debug,
      );
    },
    assignQuerySingleEngineActorDoneOutputToQueryMachineContext: assign({
      response: ({ context, spawn, event, self }) => {
        assertEvent(event, 'xstate.done.actor.querySingleEngineActor');
        return event.output.response;
      },
      isCancelled: ({ context, spawn, event, self }) => {
        assertEvent(event, 'xstate.done.actor.querySingleEngineActor');
        return event.output.isCancelled;
      },
    }),
    assignQuerySingleEngineActorErrorOutputToQueryMachineContext: assign({
      response: undefined,
      isCancelled: false,
      errorMessage: ({ context, event }) => {
        assertEvent(event, 'xstate.error.actor.querySingleEngineActor');
        return event.message;
      },
    }),
    disposeCompleteStateEntryAction: ({ context, event }) => {
      context.logger.log(`disposeCompleteStateEntryAction, event type is ${event.type}`, LogLevel.Debug);
      sendTo(context.parent, {
        type: 'DISPOSE_COMPLETE',
      });
    },
    notifyCompleteAction: sendTo(
      (_, params: IQuerySingleEngineMachineNotifyCompleteActionParameters) => {
        params.logger.log(
          `notifyCompleteAction, in the destination selector lambda, sendToTargetActorRef is ${params.sendToTargetActorRef.id}`,
          LogLevel.Debug,
        );
        return params.sendToTargetActorRef;
      },
      (_, params: IQuerySingleEngineMachineNotifyCompleteActionParameters) => {
        params.logger.log(
          `notifyCompleteAction, in the event selector lambda, eventCausingTheTransitionIntoOuterDoneState is ${params.eventCausingTheTransitionIntoOuterDoneState.type}`,
          LogLevel.Debug,
        );
        // discriminate on event that triggers this action and send QUICKPICK_DONE or DISPOSE_COMPLETE
        let _eventToSend:
          | { type: 'QUERY.SINGLE_ENGINE_MACHINE_DONE'; payload: IQuerySingleEngineMachineDoneEventPayload }
          | { type: 'DISPOSE_COMPLETE' };
        switch (params.eventCausingTheTransitionIntoOuterDoneState.type) {
          case 'xstate.done.actor.querySingleEngineActor':
            _eventToSend = {
              type: 'QUERY.SINGLE_ENGINE_MACHINE_DONE',
              payload: { queryEngineName: params.queryEngineName } as IQuerySingleEngineMachineDoneEventPayload,
            };
            break;
          case 'xstate.done.actor.disposeActor':
            _eventToSend = { type: 'DISPOSE_COMPLETE' };
            break;
          // ToDo: add case legs for the two error events that come from the querySingleEngineActor and disposeActor
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

    sendQuerySingleEngineMachineDoneEvent: ({ context }) => {
      sendTo(context.parent, {
        type: 'QUERY.SINGLE_ENGINE_MACHINE_DONE',
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
  id: 'querySingleEngineMachine',
  initial: 'startedState',
  states: {
    startedState: {
      type: 'parallel',
      states: {
        operationState: {
          initial: 'querySingleEngineState',
          states: {
            querySingleEngineState: {
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
                  actions: 'assignQuerySingleEngineActorDoneOutputToQueryMachineContext',
                },
                onError: {
                  // set the context for errorMessage and isCancelled
                  target: 'errorState',
                  actions: 'assignQuerySingleEngineActorErrorOutputToQueryMachineContext',
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
              description:
                'querySingleEngineMachine  is done. send the QUERY.SINGLE_ENGINE_MACHINE_DONE event to the parent machine (queryMachine)',
              entry: 'sendQuerySingleEngineMachineDoneEvent',
              always: '#querySingleEngineMachine.doneState',
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
              entry: ({ context, event }) => {
                context.logger.log(`disposingStateEntryAction, event type is ${event.type}`, LogLevel.Debug);
                // ToDo: add code to dispose of any allocated resource
              },
              on: {
                DISPOSE_COMPLETE: {
                  target: 'disposeCompleteState',
                },
              },
            },
            disposeCompleteState: {
              entry: ({ context, event }) => {
                context.logger.log(`disposeCompleteStateEntryAction, event type is ${event.type}`, LogLevel.Debug);
                // ToDo: add code to dispose of any allocated resource
              },
              always: '#querySingleEngineMachine.doneState',
            },
          },
        },
      },
    },
    doneState: {
      type: 'final',
      entry: [
        // call the notifyComplete action here, setting the value of the params' properties to values pulled from the context and the event
        // that entered the outerDonestate.
        // When notifyCompleteAction is called, the lambda's supplied as arguments to sendTo (because they close over params), will use the values
        //  set into params here, when the lambdas run
        {
          type: 'notifyCompleteAction',
          params: ({ context, event }) =>
            ({
              logger: context.logger,
              sendToTargetActorRef: context.parent,
              eventCausingTheTransitionIntoOuterDoneState: event,
              queryEngineName: context.queryEngineName,
            }) as INotifyCompleteActionParameters,
        },
        'debugMachineContext',
      ],
    },
  },
});
