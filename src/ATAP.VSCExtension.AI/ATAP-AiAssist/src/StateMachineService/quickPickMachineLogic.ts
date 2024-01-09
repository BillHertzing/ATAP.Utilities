import * as vscode from 'vscode';
import { ILogger, Logger, LogLevel } from '@Logger/index';
import { createMachine, createActor, sendTo } from 'xstate';
import { ILoggerData } from '@StateMachineService/index';

import {
  CommandMenuItemEnum,
  ModeMenuItemEnum,
  QuickPickEnumeration,
  StatusMenuItemEnum,
  SupportedQueryEnginesEnum,
} from '@BaseEnumerations/index';
import { showQuickPickActorLogic } from './showQuickPickActorLogic';
import { changeQuickPickActorLogic } from './changeQuickPickActorLogic';
import { IQuickPickInput } from './StateMachineService';

export const quickPickMachineLogic = createMachine(
  {
    id: 'quickPickMachine',
    types: {
      context: {} as { qpPInput: IQuickPickInput },
      input: {} as { qpPInput: IQuickPickInput },
      events: {} as
        | { type: 'ShowQuickPickState'; kindOfEnumeration: QuickPickEnumeration }
        | { type: 'changeQuickPick' },
    },
    context: ({ input }) => ({
      qpPInput: input.qpPInput,
    }),
    initial: 'ShowQuickPickState',
    states: {
      ShowQuickPickState: {
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
          input: ({ context }) => ({
            qpPInput: context.qpPInput,
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
                type: 'errorEvent', //message: 'TBD: fill in why the error occurred, call stack etc',
              }),
            },
          ],
        },
      },
      changeQuickPickState: {
        description:
          'A state where an actor is invoked to change the current value of the enum based on the user selection.',
        exit: {
          type: 'changeQuickPickActorLogicExitAction',
        },
        invoke: {
          id: 'changeQuickPickActor',
          src: 'changeQuickPickActorLogic',
          onDone: [
            {
              actions: sendTo(({ system }) => system.get('primaryMachine'), {
                type: 'Idle',
              }),
            },
          ],
          onError: [
            {
              //target: 'Error',
              actions: sendTo(({ system }) => system.get('primaryMachine'), {
                type: 'Error',
              }),
            },
          ],
        },
      },
    },
  },
  {
    actions: {
      showQuickPickStateEntryAction: ({ context, event }) => {
        context.qpPInput.logger.log(`showQuickPickStateEntryAction called`, LogLevel.Debug);
        context.qpPInput.logger.log(
          `event type: ${event.type}, kindOfEnumeration: : ${context.qpPInput.kindOfEnumeration}`,
          LogLevel.Debug,
        );
      },
      showQuickPickStateExitAction: ({ context, event }) => {
        context.qpPInput.logger.log(`showQuickPickStateExitAction called`, LogLevel.Debug);
        context.qpPInput.logger.log(
          `event type: ${event.type}, kindOfEnumeration: : ${context.qpPInput.kindOfEnumeration}`,
          LogLevel.Debug,
        );
        switch (context.qpPInput.kindOfEnumeration) {
          case QuickPickEnumeration.StatusMenuItemEnum:
            context.qpPInput.logger.log(`StatusQuickPick, no current value`, LogLevel.Debug);
            break;
          case QuickPickEnumeration.ModeMenuItemEnum:
            context.qpPInput.logger.log(
              `currentMode: ${context.qpPInput.data.stateManager.currentMode}`,
              LogLevel.Debug,
            );
            break;
          case QuickPickEnumeration.CommandMenuItemEnum:
            context.qpPInput.logger.log(
              `currentCommand: ${context.qpPInput.data.stateManager.currentCommand}`,
              LogLevel.Debug,
            );
            break;
        }
      },
      changeQuickPickStateEntryAction: ({ context, event }) => {
        context.qpPInput.logger.log(`changeQuickPickStateEntryAction called`, LogLevel.Debug);
        context.qpPInput.logger.log(
          `event type: ${event.type}, kindOfEnumeration: : ${context.qpPInput.kindOfEnumeration}`,
          LogLevel.Debug,
        );
      },
      changeQuickPickStateExitAction: ({ context, event }) => {
        context.qpPInput.logger.log(`changeQuickPickStateExitAction called`, LogLevel.Debug);
        context.qpPInput.logger.log(
          `event type: ${event.type}, kindOfEnumeration: : ${context.qpPInput.kindOfEnumeration}`,
          LogLevel.Debug,
        );
        switch (context.qpPInput.kindOfEnumeration) {
          case QuickPickEnumeration.StatusMenuItemEnum:
            context.qpPInput.logger.log(`StatusQuickPick, no current value`, LogLevel.Debug);
            break;
          case QuickPickEnumeration.ModeMenuItemEnum:
            context.qpPInput.logger.log(
              `priorMode: ${context.qpPInput.data.stateManager.priorMode}, currentMode: ${context.qpPInput.data.stateManager.currentMode}`,
              LogLevel.Debug,
            );
            break;
          case QuickPickEnumeration.CommandMenuItemEnum:
            context.qpPInput.logger.log(
              `priorCommand: ${context.qpPInput.data.stateManager.priorCommand}, currentCommand: ${context.qpPInput.data.stateManager.currentCommand}`,
              LogLevel.Debug,
            );
            break;
        }
      },
    },
  },
);

export const quickPickActor = createActor(quickPickMachineLogic).start();
