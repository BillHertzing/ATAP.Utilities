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
} from 'xstate';

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
} from '@BaseEnumerations/index';

import { IQueryService } from '@QueryService/index';
import { LoggerDataT } from '@StateMachineService/index';

import { quickPickActorLogic, QuickPickEventPayloadT, QPActorLogicOutputT } from './quickPickActorLogic';
import { queryMachine, QueryEventPayloadT, QueryOutputT } from './queryMachine';

export type PrimaryMachineContextT = LoggerDataT & { queryService: IQueryService };

// create the primaryMachine definition
export const primaryMachine = setup({
  types: {} as {
    context: PrimaryMachineContextT;
    input: PrimaryMachineContextT;
    events:
      | { type: 'quickPickEvent'; data: QuickPickEventPayloadT }
      | { type: 'done.invoke.quickPickActorLogic'; data: QPActorLogicOutputT }
      | { type: 'xstate.done.actor.quickPickActor'; output: QPActorLogicOutputT }
      | { type: 'queryEvent'; data: QueryEventPayloadT }
      | { type: 'xstate.done.actor.queryMachineActor'; data: QueryOutputT }
      | { type: 'querySucceeded'; data: QueryOutputT }
      | { type: 'queryCancelled' }
      | { type: 'queryError' }
      | { type: 'errorEvent'; message: string }
      | { type: 'disposeEvent' }
      | { type: 'disposingCompleteEvent' };
  },
  actions: {},
}).createMachine(
  //   // cSpell:disable
  //   // cSpell:enable
  {
    // ToDo: Disable VSC telemetry
    id: 'primaryMachine',
    context: ({ input }) => ({ logger: input.logger, data: input.data, queryService: input.queryService }), //, dummy: input.dummy, dummy2: input.dummy2 }),
    type: 'parallel',
    states: {
      operationState: {
        // This state handles the main operation of the machine. First of two parallel states
        initial: 'idleState',
        states: {
          idleState: {
            on: {
              quickPickEvent: {
                target: 'quickPickStateP',
              },
              queryEvent: {
                target: 'queryState',
              },
            },
          },
          errorState: {
            // ToDO: add code to attempt to remediate the error, otherwise transition to finalErrorState and throw an error
            always: {
              target: 'idleState',
            },
          },
          quickPickStateP: {
            description:
              "A parent state with child states that allow a user to see a list of available enumeration values, pick one, update the extension (transition it) to the UI indicated by the new value, update the 'currentValue' of the enumeration, and then return to the Idle state.",
            initial: 'quickPickState',
            states: {
              quickPickState: {
                description: 'A state where an actor is invoked to show and let the user select an enum value.',
                invoke: {
                  id: 'quickPickActor',
                  src: quickPickActorLogic,
                  input: ({ context, event }) => ({
                    logger: context.logger,
                    data: context.data,
                    kindOfEnumeration: (event as { type: 'quickPickEvent'; data: QuickPickEventPayloadT }).data
                      .kindOfEnumeration,
                    cTSId: (event as { type: 'quickPickEvent'; data: QuickPickEventPayloadT }).data.cTSId,
                  }),
                  onDone: {
                    target: '#primaryMachine.operationState.updateUIState',
                    actions: enqueueActions(({ context, event, enqueue, check }) => {
                      context.logger.log('quickPickState onDone enqueueActions started', LogLevel.Debug);
                      const _event = event as {
                        type: 'xstate.done.actor.quickPickActor'; // is xstate.done.actor... the correct event for enqueuing actions?
                        output: QPActorLogicOutputT;
                      };
                      if (_event && typeof _event.output !== 'undefined') {
                        if (!_event.output.pickLabel.startsWith('undefined:')) {
                          switch (_event.output.kindOfEnumeration) {
                            case QuickPickEnumeration.ModeMenuItemEnum:
                              context.logger.log(
                                `quickPickState enqueuing assign(currentMode = ${_event.output.pickLabel})`,
                                LogLevel.Debug,
                              );
                              enqueue.assign(({ context }) => {
                                context.data.stateManager.priorMode = context.data.stateManager.currentMode;
                                context.data.stateManager.currentMode = _event.output.pickLabel as ModeMenuItemEnum;
                                return context;
                              });
                              break;
                            case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
                              enqueue.assign(({ context }) => {
                                context.data.stateManager.priorQueryAgentCommand =
                                  context.data.stateManager.currentQueryAgentCommand;
                                context.data.stateManager.currentQueryAgentCommand = _event.output
                                  .pickLabel as QueryAgentCommandMenuItemEnum;
                                return context;
                              });
                              break;
                            case QuickPickEnumeration.QueryEnginesMenuItemEnum:
                              let _newQueryEngines: QueryEngineFlagsEnum =
                                context.data.stateManager.currentQueryEngines;
                              const _selectedQueryEngineName = event.output.pickLabel as QueryEngineNamesEnum;
                              switch (_selectedQueryEngineName) {
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
                                    `quickPickStateInvokedActorOnDoneAction received an unexpected _selectedQueryEngineName: ${_selectedQueryEngineName}`,
                                  );
                              }
                              enqueue.assign(({ context }) => {
                                context.data.stateManager.currentQueryEngines = _newQueryEngines;
                                return context;
                              });
                              break;
                          }
                        }
                        // ToDo the unconditional assignment here to remove the cancellationTokenSource from the cTSCollection
                        // context.data.cTSManager.cTSCollection.Remove(event.data.cTSId); // does this even require an assign action?
                        // ToDo: should we keep the cancellation tokens around and record the cancellation reason? Would require a periodic GC if so...
                        // ToDo: we could GC the CTS collection on idleState entry...
                      }
                    }),
                  },
                  onError: [
                    {
                      // use the error message to guard the target transitions
                      // if the error message is 'undefined', just go to the idleState
                      target: '#primaryMachine.operationState.idleState',
                    },
                    // Any other error go to the errorState
                    { target: '#primaryMachine.operationState.errorState' },
                  ],
                },
              },
            },
          },

          queryState: {
            description: 'A state where an machine is invoked to send a query to all enabled QueryEngines.',
            // entry: {
            //   type: 'queryStateEntryAction',
            // },
            // exit: {
            //   type: 'queryStateStateExitAction',
            // },
            invoke: {
              id: 'queryMachineActor',
              src: queryMachine,
              input: ({ context, event }) => ({
                logger: context.logger,
                data: context.data,
                queryService: context.queryService,
                queryFragmentCollection: (event as { type: 'queryEvent'; data: QueryEventPayloadT }).data
                  .queryFragmentCollection,
                cTSToken: (event as { type: 'queryEvent'; data: QueryEventPayloadT }).data.cTSToken,
              }),
              onDone: {
                actions: (context) => {
                  const _event = context.event as {
                    type: 'xstate.done.actor.queryMachineActor';
                    output: QueryOutputT;
                  };
                  // if the ActorLogic was cancelled, send the appropriate event
                  if (_event.output.cancelled) {
                    return {
                      type: 'queryCancelled',
                    };
                  }
                  return {
                    type: 'querySucceeded',
                    output: {
                      responses: _event.output.responses,
                      errors: _event.output.errors,
                      cancelled: _event.output.cancelled,
                    } as QueryOutputT,
                  };
                },
              },
            },
            on: {
              querySucceeded: 'updateUIState',
              queryCancelled: 'idleState',
            },
          },
          updateUIState: {
            description: 'appearance',
            entry: {
              type: 'updateUIStateEntryAction',
            },
            exit: {
              type: 'updateUIStateExitAction',
            },
            // ToDo: all the various on... events
            always: [
              {
                target: '#primaryMachine.operationState.idleState',
              },
            ],
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
      // Global transition to deactivateState
      disposeEvent: '.disposeState.disposingState',
    },
  },
);
