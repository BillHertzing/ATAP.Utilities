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

import { quickPickActorLogic } from './quickPickActorLogic';

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
  SupportedQueryEnginesEnum,
} from '@BaseEnumerations/index';

export type LoggerDataT = { logger: ILogger; data: IData };

export type MachineContextT = LoggerDataT & { dummy: string };

export type QuickPickEventPayload = {
  kindOfEnumeration: QuickPickEnumeration;
  cTSId: string;
};

type QPActorLogicInput = QuickPickEventPayload;

type QPActorLogicOutput = {
  kindOfEnumeration: QuickPickEnumeration;
  pickLabel: string;
  cTSId: string;
};

// create the primaryMachine definition
export const primaryMachine = setup({
  types: {} as {
    context: MachineContextT;
    input: MachineContextT;
    events:
      | { type: 'quickPickEvent'; data: QuickPickEventPayload }
      | { type: 'errorEvent'; message: string }
      | { type: 'disposeEvent' }
      | { type: 'disposingCompleteEvent' }
      | { type: 'done.invoke.quickPickActorLogic'; data: QPActorLogicOutput }
      | { type: 'xstate.done.actor.quickPickActor'; output: QPActorLogicOutput };
  },
  actions: {
    idleStateEntryAction: ({ context, event }) => {
      context.logger.log(`IdleStateEntryAction called`, LogLevel.Debug);
      context.logger.log(
        `context.data.configurationData.currentEnvironment: ${context.data.configurationData.currentEnvironment}`,
        LogLevel.Debug,
      );
    },
    idleStateExitAction: ({ context, event }) => {
      context.logger.log(`IdleStateExitAction called`, LogLevel.Debug);
      context.logger.log(`event type: ${event.type}`, LogLevel.Debug);
    },
    quickPickStateEntryAction: ({ context, event }) => {
      context.logger.log(`quickPickStateEntryAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; data: QuickPickEventPayload }).data.kindOfEnumeration
          : undefined;
      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
    },
    quickPickStateOnDoneAction: ({ context, event }) => {
      context.logger.log(`quickPickStateOnDoneAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; data: QuickPickEventPayload }).data.kindOfEnumeration
          : undefined;
      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
    },
    quickPickStateExitAction: ({ context, event }) => {
      context.logger.log(`quickPickStateExitAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; data: QuickPickEventPayload }).data.kindOfEnumeration
          : undefined;
      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
      switch (kindOfEnumeration) {
        case QuickPickEnumeration.VCSCommandMenuItemEnum:
          context.logger.log(`VCSCommandQuickPick, no current value`, LogLevel.Debug);
          break;
        case QuickPickEnumeration.ModeMenuItemEnum:
          context.logger.log(`currentMode: ${context.data.stateManager.currentMode}`, LogLevel.Debug);
          break;
        case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
          context.logger.log(
            `currentQueryAgentCommand: ${context.data.stateManager.currentQueryAgentCommand}`,
            LogLevel.Debug,
          );
          break;
      }
    },

    changeQuickPickStateEntryAction: ({ context, event }) => {
      context.logger.log(`changeQuickPickStateEntryAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; data: QuickPickEventPayload }).data.kindOfEnumeration
          : undefined;

      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
    },
    updateUIStateEntryAction: ({ context, event }) => {
      context.logger.log(`updateUIStateEntryAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; data: QuickPickEventPayload }).data.kindOfEnumeration
          : undefined;

      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
    },
    updateUIStateExitAction: ({ context, event }) => {
      context.logger.log(`updateUIStateExitAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; data: QuickPickEventPayload }).data.kindOfEnumeration
          : undefined;
      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
      switch (kindOfEnumeration) {
        case QuickPickEnumeration.VCSCommandMenuItemEnum:
          context.logger.log(`updateUIStateExitAction, no current value`, LogLevel.Debug);
          break;
        case QuickPickEnumeration.ModeMenuItemEnum:
          context.logger.log(
            `priorMode: ${context.data.stateManager.priorMode}, currentMode: ${context.data.stateManager.currentMode}`,
            LogLevel.Debug,
          );
          break;
        case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
          context.logger.log(
            `priorQueryAgentCommand: ${context.data.stateManager.priorQueryAgentCommand}, currentQueryAgentCommand: ${context.data.stateManager.currentQueryAgentCommand}`,
            LogLevel.Debug,
          );
          break;
      }
    },
    errorStateEntryAction: ({ context, event }) => {
      context.logger.log(`errorStateEntryAction called`, LogLevel.Debug);
      context.logger.log(`event type: ${event.type}, event.error: ${event}`, LogLevel.Debug);
    },
    errorStateExitAction: ({ context, event }) => {
      context.logger.log(`errorStateExitAction called`, LogLevel.Debug);
      context.logger.log(`event type: ${event.type}, event.error: ${event}`, LogLevel.Debug);
    },

    disposingStateEntryAction: ({ context, event }) => {
      context.logger.log(`disposingStateEntryAction called`, LogLevel.Debug);
      context.logger.log(`event type: ${event.type}`, LogLevel.Debug);
    },
    disposingStateExitAction: ({ context, event }) => {
      context.logger.log(`disposingStateExitAction called`, LogLevel.Debug);
      context.logger.log(`event type: ${event.type}`, LogLevel.Debug);
    },
    doneStateEntryAction: ({ context, event }) => {
      context.logger.log(`DoneStateEntryAction called`, LogLevel.Debug);
      context.logger.log(`event type: ${event.type}`, LogLevel.Debug);
    },
  },
}).createMachine(
  //   // cSpell:disable
  //   // cSpell:enable
  {
    id: 'primaryMachine',
    context: ({ input }) => ({ logger: input.logger, data: input.data, dummy: input.dummy }),
    // input: ({ context }) => ({ loggerData: context.loggerData }),
    type: 'parallel',
    states: {
      operationState: {
        // This state handles the main operation of the machine. First of two parallel states
        initial: 'idleState',
        states: {
          idleState: {
            entry: {
              type: 'idleStateEntryAction',
            },
            exit: {
              type: 'idleStateExitAction',
            },
            on: {
              quickPickEvent: {
                target: 'quickPickStateP',
              },
            },
          },
          errorState: {
            entry: {
              type: 'errorStateEntryAction',
            },
            exit: {
              type: 'errorStateExitAction',
            },
            always: {
              target: 'idleState',
            },
          },
          quickPickStateP: {
            description:
              "A parent state with child states that allow a user to see a list of available enumeration values, pick one, update the extension (transition it) to the UI indicated by the new value, update the 'currentValue' of the enumeration, and then return to the Idle state.",
            // entry: {
            //   type: 'quickPickStateEntryAction',
            // },
            // exit: {
            //   type: 'quickPickStateExitAction',
            // },
            initial: 'quickPickState',
            states: {
              quickPickState: {
                description: 'A state where an actor is invoked to show and let the user select an enum value.',
                // entry: {
                //   type: 'quickPickStateEntryAction',
                // },
                // exit: {
                //   type: 'quickPickStateExitAction',
                // },
                invoke: {
                  id: 'quickPickActor',
                  src: quickPickActorLogic,
                  input: ({ context, event }) => ({
                    logger: context.logger,
                    data: context.data,
                    kindOfEnumeration:
                      event.type === 'quickPickEvent'
                        ? (event as { type: 'quickPickEvent'; data: QuickPickEventPayload }).data.kindOfEnumeration
                        : undefined,
                  }),
                  onDone: {
                    target: '#primaryMachine.operationState.idleState',
                    // target: 'updateUIState',
                    actions: enqueueActions(({ context, event, enqueue, check }) => {
                      context.logger.log('quickPickState onDone enqueueActions started', LogLevel.Debug);
                      const _event = event as {
                        type: 'xstate.done.actor.quickPickActor'; // is xstate.done.actor... the correct event for enqueuing actions?
                        output: QPActorLogicOutput;
                      };
                      if (_event && typeof _event.output !== 'undefined') {
                        if (!_event.output.pickLabel.startsWith('undefined:')) {
                          switch (_event.output.kindOfEnumeration) {
                            case QuickPickEnumeration.ModeMenuItemEnum:
                              context.logger.log(
                                `quickPickState enqueuing assign(currentMode = ${_event.output.pickLabel})`,
                                LogLevel.Debug,
                              );
                              enqueue.assign({
                                dummy: ({ context, event }) => _event.output.pickLabel,
                              });
                              enqueue.assign({
                                data: {
                                  ...context.data,
                                  stateManager: {
                                    ...context.data.stateManager,
                                    priorMode: context.data.stateManager.currentMode,
                                  },
                                },
                              });
                              enqueue.assign({
                                data: {
                                  ...context.data,
                                  stateManager: {
                                    ...context.data.stateManager,
                                    currentMode: _event.output.pickLabel as ModeMenuItemEnum,
                                  },
                                },
                              });
                              // 'context.context.data.stateManager.currentMode': _event.output
                              //   .pickLabel as ModeMenuItemEnum,
                              // });
                              break;
                            case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
                              enqueue.assign({
                                data: {
                                  ...context.data,
                                  stateManager: {
                                    ...context.data.stateManager,
                                    priorQueryAgentCommand: context.data.stateManager.currentQueryAgentCommand,
                                  },
                                },
                              });
                              enqueue.assign({
                                data: {
                                  ...context.data,
                                  stateManager: {
                                    ...context.data.stateManager,
                                    currentQueryAgentCommand: _event.output.pickLabel as QueryAgentCommandMenuItemEnum,
                                  },
                                },
                              });

                              // assign({
                              //   ' ...context.data, stateManager: { ...context.data.stateManager,currentQueryAgentCommand':
                              //     _event.output.pickLabel as QueryAgentCommandMenuItemEnum,
                              // });
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
                              enqueue.assign({
                                data: {
                                  ...context.data,
                                  stateManager: {
                                    ...context.data.stateManager,
                                    currentQueryEngines: _newQueryEngines,
                                  },
                                },
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
          updateUIState: {
            description: 'appearance',
            entry: {
              type: 'updateUIStateEntryAction',
            },
            exit: {
              type: 'updateUIStateExitAction',
            },
            always: [
              {
                target: '#primaryMachine.operationState.idleState',
              },
            ],
          },
        },
      }, // end of OperationState
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

// Helper function to update enums in context
// const updateContext = (context: { logger:ILogger, data: IData }, event: any) => {
//   if (event.type === 'quickPickEvent') {
//     const kindOfEnumeration = (event as { type: 'quickPick'; data: QuickPickEventPayload })
//       .kindOfEnumeration;
//     switch (kindOfEnumeration) {
//       case QuickPickEnumeration.VCSCommandMenuItemEnum:
//         break;
//       case QuickPickEnumeration.ModeMenuItemEnum:
//         context.data.stateManager.priorMode = context.data.stateManager.currentMode;
//         context.data.stateManager.currentMode = event.data as ModeMenuItemEnum;

//         break;
//       case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
//         context.data.stateManager.priorQueryAgentCommand = context.data.stateManager.currentQueryAgentCommand;
//         context.data.stateManager.currentQueryAgentCommand = event.data as QueryAgentCommandMenuItemEnum;
//         break;
//     }
//   }
// };

// enum CEnum {
//   C1 = 'C1',
//   C2 = 'C2',
// }
// enum MEnum {
//   M1 = 'M1',
//   M2 = 'M2',
// }
// enum Kenum {
//   Cenum = 'Cenum',
//   Menum = 'Menum',
// }

// // there is a State QPState and it invokes a fromPromise actor qPActorLogic that returns a done_invoke_QPActorLogic_Event
// type done_invoke_QPActorLogic_Event = {
//   // this is a psuedo name for the event
//   type: 'done.invoke.QPActorLogic_Event';
//   data: { k: Kenum; cTSId: string, s:string };
// };

// // This is psuedocode for how the context should be modified when done_invoke_QPActorLogic_Event arrives....
// // I cannot get the magic sauce for the correct syntax declaring this function
// function updateContext({ context: LoggerDataT, event: done_invoke_QPActorLogic_Event }) => {
//   if (event.type === 'done.invoke.QPActorLogic_Event' && event.data.k === Kenum.Menum) {
//     context.data.stateManager.currentMode = event.data.s as MEnum;// psuedocode for what the assign should do...
//     // maybe like this? but this is incorrect, it doesn't recognize context or event correctly...
//     // assign({
//     // ...context.data,
//     // stateManager: {
//     //   ...context.data.stateManager,
//     //   currentMode: (
//     //     event as { type: 'done.invoke.QPActorLogic_Event'; data: { k: Kenum; cTSId: string, s:string } }
//     //   ).data.s as MEnum,
//     // },
//   }
//   if (event.type === 'done.invoke.QPActorLogic_Event' && event.data.k === Kenum.Cenum) {
//     context.data.stateManager.currentCmd = event.data.s as CEnum; // psuedocode for what the assign should do...
//   }
//   context.data.cTSManager.cTSCollection.Remove(event.data.cTSId); // does this even require an assign action?
//   // Note that the updateContext should perform two assignments, one for the enum value and one to remove the cTSId from the CtsCollection
// };

// // The QPState should have an onDone entry that implements the intent of the updateContext above,
// onDone: [
//   {
//     target: 'updateUIState',
//     actions: [
//       // ?????
//       {
//         type: 'updateContext', // I assume this should be an action Object with dynamic action parameters...
//         params: ({ context, event }) => ({
//           // I cannot get the magic sauce for the correct syntax to invoke the function above with the correct parameters
//         }),
//       },
//     ],
//   },
// ];

// const quickPickAssignments = (
//   context: LoggerDataT,
//   event: { type: 'done.invoke.quickPickActorLogic'; data: QPActorLogicOutput },
// ): { [key: string]: string } => {
//   let assignments: { [key: string]: string } = {};
//   switch (event.data.kindOfEnumeration) {
//     case QuickPickEnumeration.ModeMenuItemEnum:
//       assignments[' ...context.data, stateManager: { ...context.data.stateManager,currentMode'] = (
//         event as { type: 'done.invoke.quickPickActorLogic'; data: QPActorLogicOutput }
//       ).data.pickLabel as ModeMenuItemEnum;
//       break;
//     case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
//       assignments[' ...context.data, stateManager: { ...context.data.stateManager,currentQueryAgentCommand'] = (
//         event as { type: 'done.invoke.quickPickActorLogic'; data: QPActorLogicOutput }
//       ).data.pickLabel as QueryAgentCommandMenuItemEnum;
//       break;
//     case QuickPickEnumeration.QueryEnginesMenuItemEnum:
//       // in this case leg, the name entered by the user is used to get a flag bit, which is XOR'd with the current flag bits
//       let _newQueryEngines: QueryEngineFlagsEnum = context.data.stateManager.currentQueryEngines;
//       const _selectedQueryEngineName = event.data.pickLabel as QueryEngineNamesEnum;
//       switch (_selectedQueryEngineName) {
//         case QueryEngineNamesEnum.Grok:
//           _newQueryEngines ^= QueryEngineFlagsEnum.Grok;
//           break;
//         case QueryEngineNamesEnum.ChatGPT:
//           _newQueryEngines ^= QueryEngineFlagsEnum.ChatGPT;
//           break;
//         case QueryEngineNamesEnum.Claude:
//           _newQueryEngines ^= QueryEngineFlagsEnum.Claude;
//           break;
//         case QueryEngineNamesEnum.Bard:
//           _newQueryEngines ^= QueryEngineFlagsEnum.Bard;
//           break;
//         default:
//           throw new Error(
//             `quickPickActor received an unexpected _selectedQueryEngineName: ${_selectedQueryEngineName}`,
//           );
//       }

//       //assignments[' ...context.data, stateManager: { ...context.data.stateManager,currentQueryEngines'] = _newQueryEngines;
//       break;
//   }
//   return assignments;
// };
