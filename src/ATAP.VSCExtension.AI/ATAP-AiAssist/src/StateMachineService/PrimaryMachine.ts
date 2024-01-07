import * as vscode from 'vscode';
import { ILogger, Logger, LogLevel } from '@Logger/index';
import { IData } from '@DataService/index';
import { DetailedError } from '@ErrorClasses/index';
import { Actor, createActor, assign, createMachine, fromCallback, StateMachine, fromPromise, sendTo } from 'xstate';
import { quickPickActor, quickPickMachineLogic } from './quickPickMachineLogic';
import { ILoggerData } from '@StateMachineService/index';
import { IQuickPickInput } from './StateMachineService';

// an enumeration of the kinds of enumerations that can be quickpicked
export enum QuickPickEnumeration {
  StatusMenuItemEnum = 'StatusMenuItemEnum',
  ModeMenuItemEnum = 'ModeMenuItemEnum',
  CommandMenuItemEnum = 'CommandMenuItemEnum',
}

// create the primaryMachine definition
export const primaryMachine = createMachine(
  //   // cSpell:disable
  //   // cSpell:enable
  {
    types: {
      context: {} as { loggerData: ILoggerData },
      input: {} as { loggerData: ILoggerData },
      events: {} as
        | { type: 'returnToIdleEvent'; message: string }
        | { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }
        //| { type: 'saveCollection' }
        | { type: 'errorEvent'; message: string }
        | { type: 'disposeEvent' }
        | { type: 'disposeCompleteEvent' },
    },
    context: ({ input }) => ({ loggerData: input.loggerData }),
    id: 'primaryMachine',
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
          returnToIdleEvent: {
            target: 'idleState',
            reenter: true,
          },
          // saveCollection: {
          //   target: 'saveCollectionState',
          //   // params: ({ context }) => ({
          //   //   showAndSelectEnumerationValueType: QuickPickEnumeration = QuickPickEnumeration.CommandMenuItemEnum,
          //   // }),
          // },
          errorEvent: {
            target: 'errorState',
          },
          disposeEvent: {
            target: 'disposeState',
          },
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
          // params: ({ context }) => ({
          //   currentMode: context.data.stateManager.currentMode,
          //   newMode: pick
          // })
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
              src: 'showQuickPickActorLogic',
              input: ({ context, event }) => ({
                loggerData: context.loggerData,
                kindOfEnumeration:
                  event.type === 'quickPickEvent'
                    ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
                    : undefined,
              }),
              onDone: [
                {
                  target: 'changeQuickPickState',
                  // actions: {
                  //   type: 'ChangeCurrentValueOfEnum',
                  // },
                },
              ],
              onError: [
                {
                  actions: sendTo(({ system }) => system.get('primaryMachine'), {
                    type: 'errorEvent',
                    //message: 'TBD: fill in why the error occurred, call stack etc',
                  }),
                },
              ],
            },
          },
          changeQuickPickState: {
            description:
              'A state where an actor is invoked to change the current value of the enum based on the user selection.',
            entry: {
              type: 'changeQuickPickActorLogicEntryAction',
            },
            exit: {
              type: 'changeQuickPickActorLogicExitAction',
            },
            invoke: {
              id: 'changeQuickPickActor',
              src: 'changeQuickPickActorLogic',
              onDone: [
                {
                  actions: sendTo(({ system }) => system.get('primaryMachine'), {
                    type: 'returnToIdleEvent',
                    //message: 'TBD: fill in why the error occurred, call stack etc',
                  }),
                },
              ],
              onError: [
                {
                  actions: sendTo(({ system }) => system.get('primaryMachine'), {
                    type: 'errorEvent',
                    //message: 'TBD: fill in why the error occurred, call stack etc',
                  }),
                },
              ],
            },
          },
        },

        // invoke: {
        //   id: 'quickPickActor',
        //   src: quickPickMachineLogic,
        //   input: ({ context, event }) => ({
        //     logger: context.loggerData.logger,
        //     data: context.loggerData.data,
        //     // suggested by GitHub Copilot
        //     kindOfEnumeration:
        //       event.type === 'quickPick'
        //         ? (event as { type: 'quickPick'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
        //         : undefined,
        //     //kindOfEnumeration: event.kindOfEnumeration ,
        //   }),
        //   onDone: [
        //     {
        //       target: 'Idle',
        //       actions: {
        //         type: 'Idle',
        //       },
        //     },
        //   ],
        //   onError: [
        //     {
        //       target: 'Error',
        //       actions: {
        //         type: 'Error',
        //         params: ({ event }) => ({
        //           message: 'quickPickActor threw an error',
        //         }),
        //       },
        //     },
        //   ],
        // },
      },
      errorState: {
        entry: {
          type: 'errorStateEntryAction',
        },
        exit: {
          type: 'errorStateExitAction',
        },
        always: {
          description:
            ' During Development, this state is used to catch errors, log them, then return to Idle. ToDo will be retry or deactivate logic',
          actions: sendTo(({ system }) => system.get('primaryMachine'), {
            type: 'returnToIdleEvent',
            //ToDo: why can't the message parameter of the event be set here? message: 'TBD: fill in why the error occurred, call stack etc',
          }),
        },
      },
      disposeState: {
        entry: {
          type: 'disposeStateEntryAction',
        },
        exit: {
          type: 'disposeStateExitAction',
        },
        on: {
          disposeCompleteEvent: {
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
  {
    actions: {
      idleStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`IdleStateEntryAction called`, LogLevel.Debug);
        context.loggerData.logger.log(
          `context.data.configurationData.currentEnvironment: ${context.loggerData.data.configurationData.currentEnvironment}`,
          LogLevel.Debug,
        );
      },
      idleStateExitAction: ({ context, event }) => {
        context.loggerData.logger.log(`IdleStateExitAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}`, LogLevel.Debug);
      },
      quickPickStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`quickPickStateEntryAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}`, LogLevel.Debug);
      },
      quickPickStateExitAction: ({ context, event }) => {
        context.loggerData.logger.log(`quickPickStateExitAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}, event.error: ${event}`, LogLevel.Debug);

        context.loggerData.logger.log(
          `currentMode: ${context.loggerData.data.stateManager.currentMode}`,
          LogLevel.Debug,
        );
      },
      showQuickPickStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`showQuickPickStateEntryAction called`, LogLevel.Debug);
        const kindOfEnumeration =
          event.type === 'quickPickEvent'
            ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
            : undefined;
        context.loggerData.logger.log(
          `event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`,
          LogLevel.Debug,
        );
      },
      showQuickPickStateExitAction: ({ context, event }) => {
        context.loggerData.logger.log(`showQuickPickStateExitAction called`, LogLevel.Debug);
        const kindOfEnumeration =
          event.type === 'quickPickEvent'
            ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
            : undefined;
        context.loggerData.logger.log(
          `event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`,
          LogLevel.Debug,
        );
        switch (kindOfEnumeration) {
          case QuickPickEnumeration.StatusMenuItemEnum:
            context.loggerData.logger.log(`StatusQuickPick, no current value`, LogLevel.Debug);
            break;
          case QuickPickEnumeration.ModeMenuItemEnum:
            context.loggerData.logger.log(
              `currentMode: ${context.loggerData.data.stateManager.currentMode}`,
              LogLevel.Debug,
            );
            break;
          case QuickPickEnumeration.CommandMenuItemEnum:
            context.loggerData.logger.log(
              `currentCommand: ${context.loggerData.data.stateManager.currentCommand}`,
              LogLevel.Debug,
            );
            break;
        }
      },
      changeQuickPickStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`changeQuickPickStateEntryAction called`, LogLevel.Debug);
        const kindOfEnumeration =
          event.type === 'quickPickEvent'
            ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
            : undefined;

        context.loggerData.logger.log(
          `event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`,
          LogLevel.Debug,
        );
      },
      changeQuickPickStateExitAction: ({ context, event }) => {
        context.loggerData.logger.log(`changeQuickPickStateExitAction called`, LogLevel.Debug);
        const kindOfEnumeration =
          event.type === 'quickPickEvent'
            ? (event as { type: 'quickPickEvent'; kindOfEnumeration: QuickPickEnumeration }).kindOfEnumeration
            : undefined;

        context.loggerData.logger.log(
          `event type: ${event.type}, kindOfEnumeration: : ${kindOfEnumeration}`,
          LogLevel.Debug,
        );
        switch (kindOfEnumeration) {
          case QuickPickEnumeration.StatusMenuItemEnum:
            context.loggerData.logger.log(`StatusQuickPick, no current value`, LogLevel.Debug);
            break;
          case QuickPickEnumeration.ModeMenuItemEnum:
            context.loggerData.logger.log(
              `priorMode: ${context.loggerData.data.stateManager.priorMode}, currentMode: ${context.loggerData.data.stateManager.currentMode}`,
              LogLevel.Debug,
            );
            break;
          case QuickPickEnumeration.CommandMenuItemEnum:
            context.loggerData.logger.log(
              `priorCommand: ${context.loggerData.data.stateManager.priorCommand}, currentCommand: ${context.loggerData.data.stateManager.currentCommand}`,
              LogLevel.Debug,
            );
            break;
        }
      },
      errorStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`errorStateEntryAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}, event.error: ${event}`, LogLevel.Debug);
      },
      errorStateExitAction: ({ context, event }) => {
        context.loggerData.logger.log(`errorStateExitAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}, event.error: ${event}`, LogLevel.Debug);
      },

      disposeStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`DisposeStateEntryAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}`, LogLevel.Debug);
      },
      disposeStateExitAction: ({ context, event }) => {
        context.loggerData.logger.log(`DisposeStateExitAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}`, LogLevel.Debug);
      },
      doneStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`DoneStateEntryAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}`, LogLevel.Debug);
      },
    },
  },
);
