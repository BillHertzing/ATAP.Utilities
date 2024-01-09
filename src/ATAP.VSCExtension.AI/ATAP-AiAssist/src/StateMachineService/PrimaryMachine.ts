import * as vscode from 'vscode';
import { ILogger, Logger, LogLevel } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError } from '@ErrorClasses/index';
import {
  Actor,
  createActor,
  assign,
  createMachine,
  fromCallback,
  StateMachine,
  fromPromise,
  sendTo,
  raise,
  setup,
} from 'xstate';
import { quickPickActor, quickPickMachineLogic } from './quickPickMachineLogic';
import { ILoggerData } from '@StateMachineService/index';
import { IQuickPickInput, IUpdateUIInput } from './StateMachineService';
import { showQuickPickActorLogic } from './showQuickPickActorLogic';
import { changeQuickPickActorLogic } from './changeQuickPickActorLogic';
import { StatusMenuItemEnum, ModeMenuItemEnum, CommandMenuItemEnum } from '@StateMachineService/index';

// an enumeration of the kinds of enumerations that can be quickpicked
export enum QuickPickEnumeration {
  StatusMenuItemEnum = 'StatusMenuItemEnum',
  ModeMenuItemEnum = 'ModeMenuItemEnum',
  CommandMenuItemEnum = 'CommandMenuItemEnum',
}

// Guard function to check if a pick label is undefined
const lableIsUndefined = (context: { loggerData: ILoggerData }, event: any) => {
  return event.type === 'errorEvent' && event.data === 'undefined';
};

// create the primaryMachine definition
export const primaryMachine = setup({
  types: {} as {
    context: { logger: ILogger; data: IData };
    input: { logger: ILogger; data: IData };
    events:
      | { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }
      | { type: 'errorEvent'; message: string }
      | { type: 'disposeEvent' }
      | { type: 'disposingCompleteEvent' };
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
      context.logger.log(`event type: ${event.type}`, LogLevel.Debug);
    },
    quickPickStateExitAction: ({ context, event }) => {
      context.logger.log(`quickPickStateExitAction called`, LogLevel.Debug);
      //context.logger.log(`event type: ${event.type}, event.error: ${event.message}`, LogLevel.Debug);
      context.logger.log(`currentMode: ${context.data.stateManager.currentMode}`, LogLevel.Debug);
    },
    showQuickPickStateEntryAction: ({ context, event }) => {
      context.logger.log(`showQuickPickStateEntryAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
          : undefined;
      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
    },
    showQuickPickStateOnDoneAction: ({ context, event }) => {
      context.logger.log(`showQuickPickStateOnDoneAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
          : undefined;
      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
    },
    showQuickPickStateExitAction: ({ context, event }) => {
      context.logger.log(`showQuickPickStateExitAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
          : undefined;
      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
      switch (kindOfEnumeration) {
        case QuickPickEnumeration.StatusMenuItemEnum:
          context.logger.log(`StatusQuickPick, no current value`, LogLevel.Debug);
          break;
        case QuickPickEnumeration.ModeMenuItemEnum:
          context.logger.log(`currentMode: ${context.data.stateManager.currentMode}`, LogLevel.Debug);
          break;
        case QuickPickEnumeration.CommandMenuItemEnum:
          context.logger.log(`currentCommand: ${context.data.stateManager.currentCommand}`, LogLevel.Debug);
          break;
      }
    },
    changeQuickPickStateEntryAction: ({ context, event }) => {
      context.logger.log(`changeQuickPickStateEntryAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
          : undefined;

      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
    },
    updateUIStateEntryAction: ({ context, event }) => {
      context.logger.log(`updateUIStateEntryAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
          : undefined;

      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
    },
    updateUIStateExitAction: ({ context, event }) => {
      context.logger.log(`updateUIStateExitAction called`, LogLevel.Debug);
      const kindOfEnumeration =
        event.type === 'quickPickEvent'
          ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
          : undefined;
      context.logger.log(`event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`, LogLevel.Debug);
      switch (kindOfEnumeration) {
        case QuickPickEnumeration.StatusMenuItemEnum:
          context.logger.log(`updateUIStateExitAction, no current value`, LogLevel.Debug);
          break;
        case QuickPickEnumeration.ModeMenuItemEnum:
          context.logger.log(
            `priorMode: ${context.data.stateManager.priorMode}, currentMode: ${context.data.stateManager.currentMode}`,
            LogLevel.Debug,
          );
          break;
        case QuickPickEnumeration.CommandMenuItemEnum:
          context.logger.log(
            `priorCommand: ${context.data.stateManager.priorCommand}, currentCommand: ${context.data.stateManager.currentCommand}`,
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
    context: ({ input }) => ({ logger: input.logger, data: input.data }),
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
                target: 'quickPickState',
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
          quickPickState: {
            description:
              "A parent state with child states that allow a user to see a list of available enumeration values, pick one, update the extension (transition it) to the UI indicated by the new value, update the 'currentValue' of the enumeration, and then return to the Idle state.",
            entry: {
              type: 'quickPickStateEntryAction',
            },
            exit: {
              type: 'quickPickStateExitAction',
            },
            initial: 'showQuickPickState',
            states: {
              showQuickPickState: {
                description: 'A state where an actor is invoked to show and let the user select an enum value.',
                entry: {
                  type: 'showQuickPickStateEntryAction',
                },
                exit: {
                  type: 'showQuickPickStateExitAction',
                },
                invoke: {
                  id: 'showQuickPickActor',
                  src: showQuickPickActorLogic,
                  input: ({ context, event }) => ({
                    logger: context.logger,
                    data: context.data,
                    kindOfEnumeration:
                      event.type === 'quickPickEvent'
                        ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration })
                            .kindOfEnumeration
                        : undefined,
                  }),
                  onDone: [
                    {
                      //target: '#primaryMachine.operationState.idleState',
                      target: 'updateUIState',
                      //actions: assign({ data: ({ event }) => event.output }),
                    },
                  ],

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
              updateUIState: {
                description: 'A state where an actor is invoked to show and let the user select an enum value.',
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
//     const kindOfEnumeration = (event as { type: 'quickPick'; kindOfEnumeration: QuickPickEnumeration })
//       .kindOfEnumeration;
//     switch (kindOfEnumeration) {
//       case QuickPickEnumeration.StatusMenuItemEnum:
//         break;
//       case QuickPickEnumeration.ModeMenuItemEnum:
//         context.data.stateManager.priorMode = context.data.stateManager.currentMode;
//         context.data.stateManager.currentMode = event.data as ModeMenuItemEnum;

//         break;
//       case QuickPickEnumeration.CommandMenuItemEnum:
//         context.data.stateManager.priorCommand = context.data.stateManager.currentCommand;
//         context.data.stateManager.currentCommand = event.data as CommandMenuItemEnum;
//         break;
//     }
//   }
// };
