import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError } from '@ErrorClasses/index';
import {
  assign,
  enqueueActions,
  createMachine,
  fromCallback,
  StateMachine,
  fromPromise,
  sendTo,
  raise,
  setup,
  assertEvent,
  ActorRef,
} from 'xstate';

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
} from '@BaseEnumerations/index';

import {
  GatheringActorLogicInputT,
  GatheringActorLogicOutputT,
  gatheringActorLogic,
  ParallelQueryActorLogicInputT,
  ParallelQueryActorLogicOutputT,
  SingleQueryActorLogicInputT,
  SingleQueryActorLogicOutputT,
  fetchingFromQueryEngineActorLogic,
  fetchingFromBardActorLogic,
  FetchingFromSingleQueryEngineOutputT,
  WaitingForAllActorLogicInputT,
  WaitingForAllActorLogicOutputT,
  waitingForAllActorLogic,
} from './queryActorLogic';

import { IQueryService } from '@QueryService/index';
import { LoggerDataT } from '@StateMachineService/index';

import { quickPickActorLogic, QuickPickEventPayloadT, QPActorLogicOutputT } from './quickPickActorLogic';
//import { queryMachine, QueryEventPayloadT, QueryOutputT } from './queryMachine';

export type QueryContextT = {
  queryService: IQueryService;
  queryString: string;
  queryError: Error | unknown | undefined;
  queryCancelled: boolean;
  queryActorCollection: { [key in QueryEngineNamesEnum]: ActorRef<any, any> } | undefined;
  queryResponses: {};
  queryErrors: {};
  queryCTSToken: vscode.CancellationToken | undefined;
};

export type PrimaryMachineContextT = {
  logger: ILogger;
  data: IData;
} & QueryContextT;

import { IQueryFragment, IQueryFragmentCollection } from '@ItemWithIDs/index';

export type QueryEventPayloadT = {
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
};

export type QueryOutputT = {
  responses?: { [key in QueryEngineNamesEnum]: string };
  errors?: { [key in QueryEngineNamesEnum]: string };
  cancelled: boolean;
};

function returnResultsStateEntryAction(context: PrimaryMachineContextT, event: any) {
  const _event = event as { type: 'xstate.done.actor.gatheringActor'; output: GatheringActorLogicOutputT };
  context.logger.log('returnResultsStateEntryAction started', LogLevel.Debug);
  // if (_event.output.cancelled) {
  //   return {
  //     type: 'queryCancelled',
  //     payload: {
  //       responses: {},
  //       errors: {},
  //       cancelled: true,
  //     },
  //   };
  // }
  // return {
  //   type: 'querySucceeded',
  //   payload: {
  //     responses: {},
  //     errors: {},
  //     cancelled: false,
  //   },
  // };
}

// create the primaryMachine definition
export const primaryMachine = setup({
  types: {} as {
    context: PrimaryMachineContextT;
    input: PrimaryMachineContextT;
    events:
      | { type: 'xstate.done.actor.queryMachineActor'; data: QueryOutputT }
      | { type: 'queryEvent'; payload: QueryEventPayloadT }
      | { type: 'querySucceeded'; payload: QueryOutputT }
      | { type: 'queryCancelled'; payload: QueryOutputT }
      | { type: 'queryError'; payload: QueryOutputT }
      | { type: 'gatherQueryFragmentsEvent'; payload: GatheringActorLogicInputT }
      | { type: 'gatheringActorLogicSucceeded'; output: GatheringActorLogicOutputT }
      | { type: 'gatheringActorLogicError'; output: GatheringActorLogicOutputT }
      | { type: 'gatheringActorLogicCancelled'; output: GatheringActorLogicOutputT }
      | { type: 'waitingForAllEvent' }
      | { type: 'waitingForAllActorLogicSucceeded'; output: WaitingForAllActorLogicOutputT }
      | { type: 'waitingForAllActorLogicError'; output: WaitingForAllActorLogicOutputT }
      | { type: 'waitingForAllActorLogicCancelled'; output: WaitingForAllActorLogicOutputT }
      | { type: 'sendQueryToBardEvent'; payload: SingleQueryActorLogicInputT }
      | { type: 'sendQueryToBardActorLogicSucceeded'; output: SingleQueryActorLogicOutputT }
      | { type: 'sendQueryToBardActorLogicCancelled'; output: SingleQueryActorLogicOutputT }
      | { type: 'sendQueryToBardActorLogicError'; output: SingleQueryActorLogicOutputT }
      | { type: 'errorEvent'; message: string }
      | { type: 'disposeEvent' }
      | { type: 'disposingCompleteEvent' };
  },
  actions: {
    idleEntryAction: (context) => {
      context.context.logger.log('idleEntryAction started', LogLevel.Debug);
    },
    queryingBardStateEntryAction: (context) => {
      context.context.logger.log('queryingBardStateEntryAction started', LogLevel.Debug);
    },
    waitingOnSendQueryToBardStateEntryAction: (context) => {
      context.context.logger.log('waitingOnSendQueryToBardStateEntryAction started', LogLevel.Debug);
    },
    fetchingFromBardStateEntryAction: (context) => {
      context.context.logger.log('fetchingFromBardStateEntryAction started', LogLevel.Debug);
    },
    waitingForAllStateEntryAction: (context) => {
      context.context.logger.log('waitingForAllStateEntryAction started', LogLevel.Debug);
    },
    returnResultsStateEntryAction: (context) => {
      context.context.logger.log('returnResultsStateEntryAction started', LogLevel.Debug);
    },
    updateUIStateEntryAction: (context) => {
      context.context.logger.log('updateUIStateEntryAction started', LogLevel.Debug);
    },
    parallelQueryingStateEntryAction: (context) => {
      context.context.logger.log('parallelQueryingStateEntryAction started', LogLevel.Debug);
      context.context.logger.log('raising sendQueryToBardEvent', LogLevel.Debug);
      raise({ type: 'sendQueryToBardEvent' });
    },
    raiseWaitingForAllEvent: raise({ type: 'waitingForAllEvent' }),
  },
}).createMachine({
  id: 'primaryMachine',
  context: ({ input }) => ({
    logger: input.logger,
    data: input.data,
    queryService: input.queryService,
    queryString: '',
    queryError: input.queryError,
    queryCancelled: input.queryCancelled,
    queryActorCollection: input.queryActorCollection,
    queryResponses: {},
    queryErrors: {},
    queryCTSToken: input.queryCTSToken,
  }),
  type: 'parallel',
  states: {
    operationState: {
      // This state handles the main operation of the machine. First of two parallel states
      initial: 'idleState',
      states: {
        idleState: {
          entry: ['idleEntryAction'],
          on: {
            queryEvent: {
              target: 'queryingState',
            },
          },
        },
        queryingState: {
          description:
            'A parent state that encapsulates multiple state for handling parallel queries to multiple QueryAgents.',
          initial: 'gatheringState',
          states: {
            gatheringState: {
              description:
                'given an ordered collection of fragment identifiers, gather the fragments and assemble them into a query string',
              entry: [
                // store the cTSToken passed as an event payload into the context for later reuse
                assign({
                  queryCTSToken: ({ event }) =>
                    (event as { type: 'queryEvent'; payload: QueryEventPayloadT }).payload.cTSToken,
                }),
              ],
              invoke: {
                id: 'gatheringActor',
                src: gatheringActorLogic,
                input: ({ context, event }) => ({
                  logger: context.logger,
                  data: context.data,
                  queryFragmentCollection: (event as { type: 'queryEvent'; payload: QueryEventPayloadT }).payload
                    .queryFragmentCollection,
                  queryCTSToken: (event as { type: 'queryEvent'; payload: QueryEventPayloadT }).payload.cTSToken,
                }),
                onDone: [
                  {
                    target: '#primaryMachine.operationState.idleState',
                    guard: (context, event) => {
                      assertEvent(context.event, 'xstate.done.actor.gatheringActor');
                      return context.event.output.cancelled;
                    },
                    actions: [
                      assign({
                        queryString: ({ event }) => '',
                        queryCancelled: ({ event }) => event.output.cancelled,
                      }),
                    ],
                  },
                  {
                    target: 'parallelQueryingState',
                    actions: [
                      assign({
                        queryString: ({ event }) => event.output.queryString,
                        queryCancelled: ({ event }) => event.output.cancelled,
                      }),
                      assign({
                        queryString: ({ event }) => event.output.queryString,
                        queryCancelled: ({ event }) => event.output.cancelled,
                      }),
                      'raiseWaitingForAllEvent',
                    ],
                  },
                ],
                onError: {
                  target: '#primaryMachine.operationState.errorState',
                  actions: [
                    assign({
                      queryError: ({ event }) => event.error,
                    }),
                  ],
                },
              },
              on: {
                gatheringActorLogicCancelled: {
                  target: '#primaryMachine.operationState.idleState',
                },
                gatheringActorLogicError: {
                  // ToDo: send the specific error information to the primary machine error state
                  target: '#primaryMachine.operationState.errorState',
                },
                gatheringActorLogicSucceeded: {
                  target: '#primaryMachine.operationState.queryingState.parallelQueryingState',
                },
              },
            },
            parallelQueryingState: {
              description: 'given a query string, send it to every enabled queryAgent and collect the results',
              // type: 'parallel',
              entry: 'parallelQueryingStateEntryAction',
              initial: 'waitingForAllState',
              //always: { target: 'waitingForAllState' },
              states: {
                queryingBardState: {
                  entry: 'queryingBardStateEntryAction',
                  initial: 'waitingOnSendQueryToBardState',
                  states: {
                    waitingOnSendQueryToBardState: {
                      entry: 'waitingOnSendQueryToBardStateEntryAction',
                      on: {
                        sendQueryToBardEvent: {
                          target:
                            '#primaryMachine.operationState.queryingState.parallelQueryingState.queryingBardState.fetchingFromBardState',
                        },
                      },
                    },
                    fetchingFromBardState: {
                      entry: 'fetchingFromBardStateEntryAction',
                      invoke: {
                        id: 'fetchingFromBardActor',
                        src: fetchingFromBardActorLogic,
                        input: ({ context, event }) => ({
                          logger: context.logger,
                          data: context.data,
                          queryService: context.queryService,
                          queryString: context.queryString,
                          queryCTSToken: context.queryCTSToken,
                        }),
                        onDone: [
                          {
                            target:
                              '#primaryMachine.operationState.queryingState.parallelQueryingState.waitingForAllState',
                            guard: (context, event) => {
                              assertEvent(context.event, 'xstate.done.actor.fetchingFromBardActor');
                              return context.event.output.isCancelled;
                            },
                            actions: [
                              assign({
                                queryCancelled: ({ event }) => event.output.cancelled,
                              }),
                            ],
                          },
                          {
                            target:
                              '#primaryMachine.operationState.queryingState.parallelQueryingState.waitingForAllState',
                            actions: [
                              assign({
                                queryCancelled: ({ event }) => event.output.cancelled,
                                queryResponses: ({ event }) => event.output.queryResponses,
                                queryErrors: ({ event }) => event.output.queryErrors,
                              }),
                            ],
                          },
                        ],
                        onError: {
                          target:
                            '#primaryMachine.operationState.queryingState.parallelQueryingState.waitingForAllState',
                          actions: [
                            assign({
                              queryErrors: ({ event }) => event.error,
                            }),
                          ],
                        },
                      },
                    },
                  },
                },
                waitingForAllState: {
                  /* the invoke with a promise.allSettled happens in this actor logic
                   where the actors in the promise.allSettled array are the enabled fetchingFromXYZActor
                  when all of the active enabled fetchingFromXYZActors resolve or reject, move to the returnResultsState
                 */
                  entry: 'waitingForAllStateEntryAction',
                  invoke: {
                    id: 'waitingForAllActor',
                    src: waitingForAllActorLogic, // This logic should be FromPromise, and the promise should be Promise.all of the active query engines
                    input: ({ context, event }) =>
                      ({
                        logger: context.logger,
                        data: context.data,
                        queryActorCollection: context.queryActorCollection,
                        queryCTSToken: context.queryCTSToken,
                      }) as WaitingForAllActorLogicInputT,
                    onDone: [
                      {
                        target: '#primaryMachine.operationState.idleState',
                        guard: (context, event) => {
                          assertEvent(context.event, 'xstate.done.actor.waitingForAllActor');
                          return context.event.output.queryCancelled;
                        },
                        actions: [
                          assign({
                            queryCancelled: ({ event }) => event.output.queryCancelled,
                          }),
                        ],
                      },
                      {
                        target: '#primaryMachine.operationState.queryingState.parallelQueryingState.returnResultsState',
                        actions: [
                          assign({
                            queryResponses: ({ event }) => event.output.queryResponses,
                            queryErrors: ({ event }) => event.output.queryErrors,
                            queryCancelled: ({ event }) => event.output.queryCancelled,
                          }),
                        ],
                      },
                    ],
                    onError: {
                      target: '#primaryMachine.operationState.errorState',
                      actions: [
                        assign({
                          queryError: ({ event }) => event.error,
                        }),
                      ],
                    },
                  },
                },
                returnResultsState: {
                  description: 'assign the results to the context',
                  entry: 'returnResultsStateEntryAction',

                  output: { responses: {}, errors: {}, cancelled: false } as QueryOutputT,
                  always: [{ target: '#primaryMachine.operationState.updateUIState' }],
                },
              },
              on: {
                sendQueryToBardEvent: {
                  target:
                    '#primaryMachine.operationState.queryingState.parallelQueryingState.queryingBardState',
                },
              },
            },
          },
          on: {
            querySucceeded: {
              target: 'updateUIState',
            },
            queryCancelled: {
              target: 'idleState',
            },
          },
        },
        updateUIState: {
          description: 'appearance',
          entry: 'updateUIStateEntryAction',
          // ToDo: all the various on... events
          always: [
            {
              target: '#primaryMachine.operationState.idleState',
            },
          ],
        },
        errorState: {
          // ToDO: add code to attempt to remediate the error, otherwise transition to finalErrorState and throw an error
          always: {
            //actions: [{()=> { context.logger.log('hi', LogLevel.Debug); }},  ],
            target: 'idleState',
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
            disposeEvent: 'disposingState',
          },
        },
        disposingState: {
          on: {
            disposingCompleteEvent: {
              target: 'doneState',
            },
          },
        },
        doneState: {
          type: 'final',
        },
      },
    },
  },
  on: {
    // Global transition to deactivateState
    disposeEvent: '.disposeState.disposingState',
  },
});
