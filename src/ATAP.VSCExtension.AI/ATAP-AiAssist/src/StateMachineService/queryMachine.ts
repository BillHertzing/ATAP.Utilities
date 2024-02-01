import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';

import { QueryEngineNamesEnum, QueryEngineFlagsEnum } from '@BaseEnumerations/index';

import { IQueryFragment, IQueryFragmentCollection } from '@ItemWithIDs/index';

import { IQueryService } from '@QueryService/index';

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
} from 'xstate';

import { MachineContextT } from '@StateMachineService/index';

import {
  GatheringActorLogicInputT,
  GatheringActorLogicOutputT,
  gatheringActorLogic,
  ParallelQueryActorLogicInputT,
  ParallelQueryActorLogicOutputT,
  WaitingForAllActorLogicInputT,
  SingleQueryActorLogicInputT,
  SingleQueryActorLogicOutputT,
  fetchingFromQueryEngineActorLogic,
  fetchingFromBardActorLogic,
  waitingForAllActorLogic,
  WaitingForAllActorLogicOutputT,
} from './queryActorLogic';

export type QueryEventPayloadT = {
  queryService: IQueryService;
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
};

export type QueryOutputT = {
  responses?: { [key in QueryEngineNamesEnum]: string };
  errors?: { [key in QueryEngineNamesEnum]: string };
  cancelled: boolean;
};

export type QueryMachineContextT = MachineContextT & { queryService: IQueryService };

export type SingleQueryActorStateOutputT = SingleQueryActorLogicOutputT;

export type WaitingForAllOutputT = {
  responses?: { [key in QueryEngineNamesEnum]: string };
  errors?: { [key in QueryEngineNamesEnum]: DetailedError[] };
  cancelled: boolean;
};

// create the queryMachine definition
export const queryMachine = setup({
  types: {} as {
    context: QueryMachineContextT;
    input: QueryMachineContextT;
    events:
      | { type: 'queryEvent'; data: QueryEventPayloadT }
      | { type: 'xstate.init'; data: QueryEventPayloadT }
      | { type: 'gatherQueryFragmentsEvent'; data: GatheringActorLogicInputT }
      | { type: 'xstate.done.actor.gatheringActor'; output: GatheringActorLogicOutputT }
      | { type: 'xstate.error.actor.gatheringActor'; output: GatheringActorLogicOutputT }
      | { type: 'gatheringActorLogicSucceeded'; output: GatheringActorLogicOutputT }
      | { type: 'gatheringActorLogicError'; output: GatheringActorLogicOutputT }
      | { type: 'gatheringActorLogicCancelled' }
      | { type: 'xstate.done.actor.ParallelQueryFragmentsActor'; output: ParallelQueryActorLogicOutputT }
      | { type: 'xstate.error.actor.ParallelQueryFragmentsActor'; e: Error }
      | { type: 'waitingForAllEvent'; data: WaitingForAllActorLogicInputT }
      | { type: 'sendQueryToChatGPTEvent'; data: SingleQueryActorLogicInputT }
      | { type: 'sendQueryToClaudeEvent'; data: SingleQueryActorLogicInputT }
      | { type: 'sendQueryToGrokEvent'; data: SingleQueryActorLogicInputT }
      | { type: 'sendQueryToBardEvent'; data: SingleQueryActorLogicInputT }
      | { type: 'xstate.done.actor.sendQueryToBardActor'; output: SingleQueryActorLogicOutputT }
      | { type: 'xstate.error.actor.sendQueryToBardActor'; e: Error }
      | { type: 'sendQueryToBardSucceeded'; data: SingleQueryActorLogicOutputT }
      | { type: 'sendQueryToBardCancelled' }
      | { type: 'sendQueryToBardError' }

      // ToDo: define the mechanism to resolve the call to invoke (queryMachine) in the parent with an object of type QueryOutputT to the caller. The response can mix successfull queryEngine calls and unsuccessful ones
      | {
          type: 'xstate.done.actor.waitingForAllActor';
          output: WaitingForAllActorLogicOutputT;
        }
      | {
          type: 'xstate.error.actor.waitingForAllActor';
          // output: WaitingForAllActorLogicOutputT;
        }
      | { type: 'waitingForAllSettled'; data: WaitingForAllOutputT }
      | { type: 'waitingForAllCancelled' }
      | { type: 'waitingForAllError' }
      | { type: 'cancelledEvent'; data: { cancelled: true } }
      | { type: 'errorEvent'; data: QueryOutputT }
      | { type: 'disposeEvent' } // Can be called at any time. The queryMachine must free any allocated resources and transition to the disposeState.doneState.
      | { type: 'disposingCompleteEvent' };
  },
  actions: {
    // ToDo: this action goes into the extend stanza after PR xxx is incorporated into xState
    // raiseSingleEngineQueryEventsAction: ({ context, event }) => {
    //   enqueueActions(({ context, event, enqueue, check }) => {
    //     context.logger.log('raiseSingleEngineQueryEventsAction started', LogLevel.Debug);
    //     const _event = event as {
    //       type: 'xstate.done.actor.gatheringActor';
    //       output: GatheringActorLogicOutputT;
    //     };
    //     if (_event && typeof _event.output !== 'undefined') {
    //       if (_event.output.cTSToken.isCancellationRequested || !_event.output.queryString.length) {
    //         // Just quit the entry action because the waitingForAllState will recognize these conditions and handle appropriately
    //         return;
    //       }
    //       const _queryString = _event.output.queryString;
    //       const _cTSToken = _event.output.cTSToken;
    //       const _currentActiveQueryEngines = context.data.stateManager.currentQueryEngines;
    //       if (_currentActiveQueryEngines & QueryEngineFlagsEnum.Bard) {
    //         enqueue.raise({
    //           type: 'sendQueryToBardEvent',
    //           data: {
    //             logger: context.logger,
    //             data: context.data,
    //             queryString: _queryString,
    //             cTSToken: _cTSToken,
    //           } as SingleQueryActorLogicInputT,
    //         });
    //       }
    //       if (_currentActiveQueryEngines & QueryEngineFlagsEnum.ChatGPT) {
    //         enqueue.raise({
    //           type: 'sendQueryToChatGPTEvent',
    //           data: {
    //             logger: context.logger,
    //             data: context.data,
    //             queryString: _queryString,
    //             cTSToken: _cTSToken,
    //           } as SingleQueryActorLogicInputT,
    //         });
    //       }
    //       if (_currentActiveQueryEngines & QueryEngineFlagsEnum.Claude) {
    //         enqueue.raise({
    //           type: 'sendQueryToClaudeEvent',
    //           data: {
    //             logger: context.logger,
    //             data: context.data,
    //             queryString: _queryString,
    //             cTSToken: _cTSToken,
    //           } as SingleQueryActorLogicInputT,
    //         });
    //       }
    //       if (_currentActiveQueryEngines & QueryEngineFlagsEnum.Grok) {
    //         enqueue.raise({
    //           type: 'sendQueryToGrokEvent',
    //           data: {
    //             logger: context.logger,
    //             data: context.data,
    //             queryString: _queryString,
    //             cTSToken: _cTSToken,
    //           } as SingleQueryActorLogicInputT,
    //         });
    //       }
    //     }
    //   });
    // },
  },
}).createMachine({
  id: 'queryMachine',
  context: ({ input }) => ({ logger: input.logger, data: input.data, queryService: input.queryService }),
  type: 'parallel',
  states: {
    operation: {
      initial: 'gatheringState',
      states: {
        gatheringState: {
          description:
            'given an ordered collection of fragment identifiers, gather the fragments and assemble them into a query string',
          invoke: {
            id: 'gatheringActor',
            src: gatheringActorLogic,
            input: ({ context, event }) => ({
              logger: context.logger,
              data: context.data,
              queryFragmentCollection: (event as { type: 'xstate.init'; data: QueryEventPayloadT }).data
                .queryFragmentCollection,
              cTSToken: (event as { type: 'xstate.init'; data: QueryEventPayloadT }).data.cTSToken,
            }),
            onDone: {
              actions: (context) => {
                const _event = context.event as {
                  type: 'xstate.done.actor.gatheringActor';
                  output: GatheringActorLogicOutputT;
                };
                // if the ActorLogic was cancelled, send the appropriate event
                if (_event.output.cancelled) {
                  return {
                    type: 'gatheringActorLogicCancelled',
                  };
                }
                return {
                  type: 'gatheringActorLogicSucceeded',
                  output: {
                    queryString: _event.output.queryString,
                    cTSToken: _event.output.cTSToken,
                  } as ParallelQueryActorLogicInputT,
                };
              },
            },
            onError: {
              actions: (context) => {
                // const _event = context.event as {
                //   type: 'xstate.error.actor.gatheringActor';
                //   output: GatheringActorLogicOutputT;
                // };
                return {
                  type: 'gatheringActorLogicError',
                  // output: { error: _event.output.error } as GatheringActorLogicOutputT,
                };
              },
            },
          },
          on: {
            gatheringActorLogicSucceeded: 'parallelQueryingState',
            gatheringActorLogicCancelled: '#queryMachine.operation.cancelledState',
            gatheringActorLogicError: '#queryMachine.operation.errorState',
          },
        },

        parallelQueryingState: {
          description: 'given a query string, send it to every enabled queryAgent and collect the results',
          type: 'parallel',
          entry: 'raiseSingleEngineQueryEventsAction',
          states: {
            sendQueryToBardState: {
              initial: 'waitingforSendQueryToBardState',
              states: {
                waitingforSendQueryToBardState: {
                  on: { sendQueryToBardEvent: 'fetchingFromBardState' },
                },
                fetchingFromBardState: {
                  invoke: {
                    id: 'fetchingFromBardActor',
                    src: fetchingFromBardActorLogic,
                    input: ({ context, event }) => ({
                      logger: context.logger,
                      data: context.data,
                      queryString: (event as { type: 'sendQueryToBardEvent'; data: SingleQueryActorLogicInputT }).data
                        .queryString,
                      cTSToken: (event as { type: 'sendQueryToBardEvent'; data: SingleQueryActorLogicInputT }).data
                        .cTSToken,
                    }),
                    onDone: {
                      actions: (context) => {
                        const _event = context.event as {
                          type: 'xstate.done.actor.fetchingFromBardActor';
                          output: SingleQueryActorLogicOutputT;
                        };
                        // check the cancellation and send the appropriate event
                        if (_event.output.cancelled) {
                          return {
                            type: 'sendQueryToBardCancelled',
                          };
                        }
                        return {
                          type: 'sendQueryToBardSucceeded',
                          output: {
                            response: _event.output.response,
                            error: _event.output.error,
                            cancelled: _event.output.cancelled,
                          } as SingleQueryActorStateOutputT,
                        };
                      },
                    },
                    onError: {
                      actions: (context) => {
                        const _event = context.event; // as { type: 'xstate.error.actor.fetchingFromBardActor' };
                        return {
                          type: 'sendQueryToBardError',
                          //error: _event.type;
                        };
                      },
                    },
                  },
                  on: {
                    sendQueryToBardSucceeded: '#queryMachine.operation.parallelQueryingState.waitingForAllState',
                    sendQueryToBardCancelled: '#queryMachine.operation.cancelledState',
                    sendQueryToBardError: '#queryMachine.operation.errorState',
                  },
                },
              },
            },
            sendQueryToChatGPTState: {
              initial: 'waitingforSendQueryToChatGPTState',
              states: {
                waitingforSendQueryToChatGPTState: {
                  on: { sendQueryToChatGPTEvent: 'fetchingFromChatGPTState' },
                },
                fetchingFromChatGPTState: {
                  //...// }
                },
              },
            },
            sendQueryToClaudeState: {
              initial: 'waitingforSendQueryToClaudeState',
              states: {
                waitingforSendQueryToClaudeState: {
                  on: { sendQueryToClaudeEvent: 'fetchingFromClaudeState' },
                },
                fetchingFromClaudeState: {
                  /*...*/
                },
              },
            },
            sendQueryToGrokState: {
              initial: 'waitingforSendQueryToGrokState',
              states: {
                waitingforSendQueryToGrokState: {
                  on: { sendQueryToGrokEvent: 'fetchingFromGrokState' },
                },
                fetchingFromGrokState: {
                  /*...*/
                },
              },
            },

            waitingForAllState: {
              /* the invoke with a promise.allSettled happens in this actor logic
                 where the actors in the promise.allSettled array are the enabled fetchingFromXYZActor
                 when all of the active enabled fetchingFromXYZActors resolve or reject, move to the returnResultsState
              */
              invoke: {
                id: 'waitingForAllActor',
                src: waitingForAllActorLogic, // This logic should be FromPromise, and the promise should be Promise.all of the active query engines
                input: ({ context, event }) => ({
                  logger: context.logger,
                  data: context.data,
                  actorCollection: (
                    event as {
                      type: 'waitingForAllEvent';
                      data: WaitingForAllActorLogicInputT;
                    }
                  ).data.actorCollection,
                  cTSToken: (event as { type: 'waitingForAllEvent'; data: WaitingForAllActorLogicInputT }).data
                    .cTSToken,
                }),
                onDone: {
                  actions: (context) => {
                    const _event = context.event as {
                      type: 'xstate.done.actor.waitingForAllActor';
                      output: WaitingForAllActorLogicOutputT;
                    };
                    // check the cancellation and send the appropriate event
                    if (_event.output.cancelled) {
                      return {
                        type: 'waitingForAllCancelled',
                      };
                    }
                    // send the output of the actor to the parallelQueryingState
                    // the actor returns an instance of GatheringActorLogicOutputT},
                    // the next state requires an instance of ParallelQueryActorLogicInputT
                    return {
                      type: 'waitingForAllSettled',
                      output: {
                        responses: _event.output.responses,
                        errors: _event.output.errors,
                        cancelled: _event.output.cancelled,
                      } as WaitingForAllOutputT,
                    };
                  },
                },
                onError: {
                  actions: (context) => {
                    const _event = context.event; // as { type: 'xstate.error.actor.fetchingFromBardActor' };
                    // ToDo: this should throw an error, because the waitingForAllActorLogic should not fail
                    return {
                      type: 'waitingForAllError',
                      //error: _event.type;
                    };
                  },
                },
              },
              on: {
                waitingForAllSettled: '#queryMachine.operation.returnResultsState',
                waitingForAllCancelled: '#queryMachine.operation.cancelledState',
                waitingForAllError: '#queryMachine.operation.errorState',
              },
            },
          },
        },
        cancelledState: {
          always: {
            target: 'returnResultsState',
            actions: [raise({ type: 'cancelledEvent', data: { cancelled: true } })],
          },
        },
        errorState: {
          always: {
            target: 'returnResultsState',
            actions: [raise({ type: 'errorEvent', data: { errors: {} } as QueryOutputT })],
          },
        },
        returnResultsState: {
          type: 'final',
          data: { responses: {}, errors: {}, cancelled: true } as QueryOutputT,
        },
      },
      on: {
        cancelledEvent: '#queryMachine.operation.returnResultsState',
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
          // entry: {
          //   type: 'disposingStateEntryAction',
          // },
          // exit: {
          //   type: 'disposingStateExitAction',
          // },
          // ToDo: define the mechanism to dispose of the queryMachine
          // It should free any allocated resources and transition to the disposeState.doneState via the disposingCompleteEvent
          always: { target: 'doneState' },
          // on: {
          //   disposingCompleteEvent: 'doneState',
          // },
        },
        doneState: {
          // entry: {
          //   type: 'doneStateEntryAction',
          // },
          type: 'final',
        },
      },
    },
  },
  on: {
    // Global transition to disposingState
    disposeEvent: '#queryMachine.disposeState.disposingState',
  },
});
