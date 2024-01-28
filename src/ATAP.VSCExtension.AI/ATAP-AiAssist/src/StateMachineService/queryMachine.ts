import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';

import { QueryEngineNamesEnum, QueryEngineFlagsEnum } from '@BaseEnumerations/index';

import { IQueryFragment, IQueryFragmentCollection } from '@ItemWithIDs/index';

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
  GatherQueryFragmentsActorLogicInputT,
  GatherQueryFragmentsActorLogicOutputT,
  gatherQueryFragmentsActorLogic,
  ParallelQueryActorLogicInputT,
  ParallelQueryActorLogicOutputT,
  parallelQueryActorLogic,
  SingleQueryActorLogicInputT,
  SingleQueryActorLogicOutputT,
  fetchingFromBardActorLogic,
} from './queryActorLogic';

export type QueryEventPayloadT = {
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
};

export type QueryEventOutputT = {
  responses: { [key in QueryEngineNamesEnum]: string };
  errors: { [key in QueryEngineNamesEnum]: string };
};

// create the queryMachine definition
export const queryMachine = setup({
  types: {} as {
    context: MachineContextT;
    input: MachineContextT;
    events:
      | { type: 'queryEvent'; data: QueryEventPayloadT }
      | { type: 'gatherQueryFragmentsEvent'; data: GatherQueryFragmentsActorLogicInputT }
      | { type: 'xstate.done.actor.gatherQueryFragmentsActor'; output: GatherQueryFragmentsActorLogicOutputT }
      | { type: 'xstate.error.actor.gatherQueryFragmentsActor'; output: GatherQueryFragmentsActorLogicOutputT }
      | { type: 'gatherQueryFragmentsActorLogicSucceeded'; output: GatherQueryFragmentsActorLogicOutputT }
      | { type: 'gatherQueryFragmentsActorLogicError'; output: GatherQueryFragmentsActorLogicOutputT }
      | { type: 'gatherQueryFragmentsActorLogicCancelled'; output: GatherQueryFragmentsActorLogicOutputT }
      | { type: 'xstate.done.actor.ParallelQueryFragmentsActor'; output: ParallelQueryActorLogicOutputT }
      | { type: 'xstate.error.actor.ParallelQueryFragmentsActor'; output: ParallelQueryActorLogicOutputT }
      | { type: 'sendQueryToBardEvent'; data: SingleQueryActorLogicInputT }
      | { type: 'sendQueryToChatGPTEvent'; data: SingleQueryActorLogicInputT }
      | { type: 'sendQueryToClaudeEvent'; data: SingleQueryActorLogicInputT }
      | { type: 'sendQueryToGrokEvent'; data: SingleQueryActorLogicInputT }
      | { type: 'allSingleQueriesCompletedEvent'; data: ParallelQueryActorLogicOutputT }

      // ToDo: define the mechanism to resolve the call to invoke (queryMachine) in the parent with an object of type QueryEventOutputT to the caller. The response can mix successfull queryEngine calls and unsuccessful ones
      | { type: 'queryCompleteEvent'; data: QueryEventOutputT }
      | { type: 'disposeEvent' } // Can be called at any time. The queryMachine must free any allocated resources and transition to the disposeState.doneState.
      | { type: 'disposingCompleteEvent' };
  },
  actions: {
    conditionallyEnqueueRaiseSpecificSendQueryToQueryEnginesAction: ({ context, event }) => {
      enqueueActions(({ context, event, enqueue, check }) => {
        context.logger.log('conditionallyEnqueueRaiseSpecificSendQueryToQueryEnginesAction started', LogLevel.Debug);
        const _event = event as {
          type: 'xstate.done.actor.gatherQueryFragmentsActor';
          output: GatherQueryFragmentsActorLogicOutputT;
        };
        if (_event && typeof _event.output !== 'undefined') {
          const _queryString = _event.output.queryString;
          const _cTSToken = _event.output.cTSToken;
          const _currentActiveQueryEngines = context.data.stateManager.currentQueryEngines;
          if (_event.output.cTSToken.isCancellationRequested || !_queryString.length) {
            // Just quit the entry action because the gatherSendQueryPromisesStateActorLogic will recognize these conditions and handle appropriately
          }
          if (_currentActiveQueryEngines & QueryEngineFlagsEnum.Bard) {
            enqueue.raise({
              type: 'sendQueryToBardEvent',
              data: {
                logger: context.logger,
                data: context.data,
                queryString: _queryString,
                cTSToken: _cTSToken,
              } as SingleQueryActorLogicInputT,
            });
          }

          if (_currentActiveQueryEngines & QueryEngineFlagsEnum.ChatGPT) {
            enqueue.raise({
              type: 'sendQueryToChatGPTEvent',
              data: {
                logger: context.logger,
                data: context.data,
                queryString: _queryString,
                cTSToken: _cTSToken,
              } as SingleQueryActorLogicInputT,
            });
          }
          if (_currentActiveQueryEngines & QueryEngineFlagsEnum.Claude) {
            enqueue.raise({
              type: 'sendQueryToClaudeEvent',
              data: {
                logger: context.logger,
                data: context.data,
                queryString: _queryString,
                cTSToken: _cTSToken,
              } as SingleQueryActorLogicInputT,
            });
          }
          if (_currentActiveQueryEngines & QueryEngineFlagsEnum.Grok) {
            enqueue.raise({
              type: 'sendQueryToGrokEvent',
              data: {
                logger: context.logger,
                data: context.data,
                queryString: _queryString,
                cTSToken: _cTSToken,
              } as SingleQueryActorLogicInputT,
            });
          }
        }
      });
    },
  },
}).createMachine({
  id: 'queryMachine',
  context: ({ input }) => ({ logger: input.logger, data: input.data }),
  type: 'parallel',
  states: {
    queryState: {
      initial: 'gatherQueryFragmentsState',
      states: {
        gatherQueryFragmentsState: {
          description:
            'given an ordered collection of fragment identifiers, gather the fragments and assemble them into a query string',
          invoke: {
            id: 'gatherQueryFragmentsActor',
            src: gatherQueryFragmentsActorLogic,
            input: ({ context, event }) => ({
              logger: context.logger,
              data: context.data,
              queryFragmentCollection: (event as { type: 'queryEvent'; data: QueryEventPayloadT }).data
                .queryFragmentCollection,
              cTSToken: (event as { type: 'queryEvent'; data: QueryEventPayloadT }).data.cTSToken,
            }),
            onDone: {
              actions: (context, event) => {
                const _event = event as {
                  type: 'xstate.done.actor.gatherQueryFragmentsActor';
                  output: GatherQueryFragmentsActorLogicOutputT;
                };
                // send the output of the actor to the parallelQueryState
                // the actor retruns an instance of GatherQueryFragmentsActorLogicOutputT},
                // the next state requires an instance of ParallelQueryActorLogicInputT
                // ToDo: create code that will send the output on to the next state
                return {
                  type: 'gatherQueryFragmentsActorLogicSucceeded',
                  output: {} as GatherQueryFragmentsActorLogicOutputT,
                };
              },
            },
            onError: {
              actions: (context, event) => {
                const _event = event as {
                  type: 'xstate.error.actor.gatherQueryFragmentsActor';
                  output: GatherQueryFragmentsActorLogicOutputT;
                };
                if (_event.output.cancelled) {
                  return {
                    type: 'gatherQueryFragmentsActorLogicCancelled',
                    output: {} as GatherQueryFragmentsActorLogicOutputT,
                  };
                }
                return {
                  type: 'gatherQueryFragmentsActorLogicError',
                  output: {} as GatherQueryFragmentsActorLogicOutputT,
                };
              },
            },
            on: {
              gatherQueryFragmentsActorLogicSucceeded: '.parallelQueryState',
              gatherQueryFragmentsActorLogicCancelled: '.cancelledState',
              gatherQueryFragmentsActorLogicError: '.errorState',
            },
          },
        },

        parallelQueryState: {
          description: 'given a query string, send it to every enabled queryAgent and collect the results',
          type: 'parallel',
          entry: {
            type: 'conditionallyEnqueueRaiseSpecificSendQueryToQueryEnginesAction',
          },
          states: {
            sendQueryToBardState: {
              states: {
                waitingforSendQueryToBardState: {
                  on: { sendQueryToBardEvent: { target: 'fetchingFromBardState' } },
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
                      actions: (context, event) => {
                        const _event = event as {
                          type: 'xstate.done.actor.fetchingFromBardActor';
                          output: SingleQueryActorLogicOutputT;
                        };
                        // send the output of the actor to the parallelQueryState
                        // the actor retruns an instance of GatherQueryFragmentsActorLogicOutputT},
                        // the next state requires an instance of ParallelQueryActorLogicInputT
                        // ToDo: create code that will send the output on to the next state
                        return {
                          type: 'gatherQueryFragmentsActorLogicSucceeded',
                          output: {} as SingleQueryActorLogicOutputT,
                        };
                      },
                    },
                    onError: {},
                  },
                  on: {},
                },
              },
            },
            sendQueryToChatGPTState: {
              states: {
                waitingforSendQueryToChatGPTState: {
                  on: { sendQueryToChatGPTEvent: { target: 'fetchingFromChatGPTState' } },
                },
                fetchingFromChatGPTState: {
                  //...// }
                },
              },
            },
            sendQueryToClaudeState: {
              states: {
                waitingforSendQueryToClaudeState: {
                  on: { sendQueryToClaudeEvent: { target: 'fetchingFromClaudeState' } },
                },
                fetchingFromClaudeState: {
                  /*...*/
                },
              },
            },
            sendQueryToGrokState: {
              states: {
                waitingforSendQueryToGrokState: {
                  on: { sendQueryToGrokEvent: { target: 'fetchingFromGrokState' } },
                },
                fetchingFromGrokState: {
                  /*...*/
                },
              },
            },

            waitingToResolveAllQueriesState: {
              /* the invoke with a promise.all happens here, where the actors in the promise.all are just the enabled fetchingFrom... actors
                 when all of the active queryengines resolve or reject, move to the FormattingAllQueryResultsState
                 when allSingleQueriesCompletedEvent happens*/
              invoke: {
                id: 'waitingToResolveAllQueriesActor',
                src: waitingToResolveAllQueriesActorLogic, // This logic should be FromPromise, and the promise should be Promise.all of the active query engines
                onDone: {},
                onError: {},
              },
              on: { allSingleQueriesCompletedEvent: { target: 'formattingAllQueryResultsState' } },
            },
          },
        },
        formattingAllQueryResultsState: {
          /* this is a final state
          it needs to ensure that the results are formatted and returned to the caller
          */
        },
        cancelledState: {
          /*...*/
        },
        errorState: {
          /*...*/
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
          // entry: {
          //   type: 'disposingStateEntryAction',
          // },
          // exit: {
          //   type: 'disposingStateExitAction',
          // },
          on: {
            disposingCompleteEvent: {
              target: 'doneState',
            },
          },
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
    disposeEvent: '.disposeState.disposingState',
  },
});
