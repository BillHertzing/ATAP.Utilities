import * as vscode from 'vscode';
import { LogLevel, ILogger } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';

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
} from './queryActorLogic';

export type QueryEventPayloadT = {
  queryFragmentCollection: IQueryFragmentCollection;
  cTSToken: vscode.CancellationToken;
};

export type QueryEventOutputT = {
  data: { result: boolean; individualQueryResults: Array<string> };
};

// create the queryMachine definition
export const queryMachine = setup({
  types: {} as {
    context: MachineContextT;
    input: MachineContextT;
    events:
      | { type: 'queryEvent'; data: QueryEventPayloadT }
      | { type: 'gatherQueryFragmentsEvent'; data: GatherQueryFragmentsActorLogicInputT }
      | { type: 'parallelQueryEvent'; data: ParallelQueryActorLogicInputT }
      | { type: 'xstate.done.actor.GatherQueryFragmentsActor'; output: GatherQueryFragmentsActorLogicOutputT }
      | { type: 'xstate.done.actor.ParallelQueryFragmentsActor'; output: ParallelQueryActorLogicOutputT }
      | { type: 'disposeEvent' }
      | { type: 'disposingCompleteEvent' };
  },
  actions: {},
}).createMachine(
  //   // cSpell:disable
  //   // cSpell:enable
  {
    // ToDo: Disable VSC telemetry
    id: 'queryMachine',
    context: ({ input }) => ({ logger: input.logger, data: input.data }),
    type: 'parallel',
    states: {
      queryState: {
        description:
          'A parent state with child states that allow a user to send an ordered collection of queryfragments, update the extension (transition it) to the UI indicated by the new value, update the conversation, and then return to the Idle state.',
        // entry: { type: 'queryStateEntryAction' },
        // exit: {
        //   type: 'quickPickStateExitAction',
        // },
        initial: 'gatherQueryFragmentsState',
        // assemble the fragments into a string
        // call await to read from files
        // call every queryAgent to get the query results
        // create a new temporary file for each queryAgent's results, populate it, and open it in an editortab
        // perhaps store every queryAgent's results in a single file as well, with spans to identify the results

        states: {
          gatherQueryFragmentsState: {
            description:
              'given an ordered collection of fragment identifiers, gather the fragments and assemble them into a query string',
            // entry: {
            //   type: 'gatherQueryFragmentsStateEntryAction',
            // },
            // exit: {
            //   type: 'gatherQueryFragmentsStateExitAction',
            // },
            invoke: {
              id: 'queryGatherFragmentsActor',
              src: gatherQueryFragmentsActorLogic,
              input: ({ context, event }) => ({
                logger: context.logger,
                data: context.data,
                queryFragmentCollection: (event as { type: 'queryEvent'; data: QueryEventPayloadT }).data
                  .queryFragmentCollection,
                cTSToken: (event as { type: 'queryEvent'; data: QueryEventPayloadT }).data.cTSToken,
              }),
              onDone: {
                target: 'parallelQueryState',
                // actions:
                //       enqueueActions(({ context, event, enqueue, check }) => {
                //   context.logger.log('quickPickState onDone enqueueActions started', LogLevel.Debug);
                //   const _event = event as {
                //     type: 'xstate.done.actor.quickPickActor'; // is xstate.done.actor... the correct event for enqueuing actions?
                //     output: QPActorLogicOutputT;
                //   };
                //   if (_event && typeof _event.output !== 'undefined') {
                //     if (!_event.output.pickLabel.startsWith('undefined:')) {
                //       switch (_event.output.kindOfEnumeration) {
                //         case QuickPickEnumeration.ModeMenuItemEnum:
                //           context.logger.log(
                //             `quickPickState enqueuing assign(currentMode = ${_event.output.pickLabel})`,
                //             LogLevel.Debug,
                //           );
                //           enqueue.assign(({ context }) => {
                //             context.data.stateManager.priorMode = context.data.stateManager.currentMode;
                //             context.data.stateManager.currentMode = _event.output.pickLabel as ModeMenuItemEnum;
                //             return context;
                //           });
                //           break;
                //         case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
                //           enqueue.assign(({ context }) => {
                //             context.data.stateManager.priorQueryAgentCommand =
                //               context.data.stateManager.currentQueryAgentCommand;
                //             context.data.stateManager.currentQueryAgentCommand = _event.output
                //               .pickLabel as QueryAgentCommandMenuItemEnum;
                //             return context;
                //           });
                //           break;
                //         case QuickPickEnumeration.QueryEnginesMenuItemEnum:
                //           let _newQueryEngines: QueryEngineFlagsEnum = context.data.stateManager.currentQueryEngines;
                //           const _selectedQueryEngineName = event.output.pickLabel as QueryEngineNamesEnum;
                //           switch (_selectedQueryEngineName) {
                //             case QueryEngineNamesEnum.Grok:
                //               _newQueryEngines ^= QueryEngineFlagsEnum.Grok;
                //               break;
                //             case QueryEngineNamesEnum.ChatGPT:
                //               _newQueryEngines ^= QueryEngineFlagsEnum.ChatGPT;
                //               break;
                //             case QueryEngineNamesEnum.Claude:
                //               _newQueryEngines ^= QueryEngineFlagsEnum.Claude;
                //               break;
                //             case QueryEngineNamesEnum.Bard:
                //               _newQueryEngines ^= QueryEngineFlagsEnum.Bard;
                //               break;
                //             default:
                //               throw new Error(
                //                 `quickPickStateInvokedActorOnDoneAction received an unexpected _selectedQueryEngineName: ${_selectedQueryEngineName}`,
                //               );
                //           }
                //           enqueue.assign(({ context }) => {
                //             context.data.stateManager.currentQueryEngines = _newQueryEngines;
                //             return context;
                //           });
                //           break;
                //       }
                //     }
                //     // ToDo the unconditional assignment here to remove the cancellationTokenSource from the cTSCollection
                //     // context.data.cTSManager.cTSCollection.Remove(event.data.cTSId); // does this even require an assign action?
                //     // ToDo: should we keep the cancellation tokens around and record the cancellation reason? Would require a periodic GC if so...
                //     // ToDo: we could GC the CTS collection on idleState entry...
                //   }
                // }),
              },
              onError: [
                {
                  // use the error message to guard the target transitions
                  // if the error message is 'undefined', just go to the idleState
                  //target: '#primaryMachine.operationState.idleState',
                },
                // Any other error go to the errorState
                //{ target: '#primaryMachine.operationState.errorState' },
              ],
            },
          },
          parallelQueryState: {
            description: 'given a query string, send it to every enabled queryAgent and collect the results',
            invoke: {
              id: 'gatherQueryFragmentsActorLogic',
              src: parallelQueryActorLogic,
              input: ({ context, event }) =>
                ({
                  logger: context.logger,
                  data: context.data,
                  queryFragmentCollection: (event as { type: 'queryEvent'; data: QueryEventPayloadT }).data
                    .queryFragmentCollection,
                  cTSToken: (event as { type: 'queryEvent'; data: QueryEventPayloadT }).data.cTSToken,
                }) as GatherQueryFragmentsActorLogicInputT,
              onDone: {
                target: 'parallelQueryState',
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
              disposeEvent: 'disposingState',
            },
          },
          disposingState: {
            entry: {
              type: 'disposingStateEntryAction',
            },
            exit: {
              type: 'disposingStateExitAction',
            },
            on: {
              disposingCompleteEvent: {
                target: 'doneState',
              },
            },
          },
          doneState: {
            entry: {
              type: 'doneStateEntryAction',
            },
            type: 'final',
          },
        },
      },
    },
    on: {
      // Global transition to disposingState
      disposeEvent: '.disposeState.disposingState',
    },
  },
);
