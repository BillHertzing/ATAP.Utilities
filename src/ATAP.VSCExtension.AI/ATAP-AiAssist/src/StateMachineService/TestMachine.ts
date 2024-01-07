import { ILogger, Logger, LogLevel } from '@Logger/index';
import { IData } from '@DataService/index';
import { Actor, createActor, assign, createMachine, fromCallback, StateMachine, fromPromise } from 'xstate';

import {ILoggerData } from '@StateMachineService/index';

// Machine Logic to do an async file save (TBD with retry logic)
import { saveFileActorLogic } from './SaveFileActorLogic';

// create a test machine definition
export const testMachine = createMachine(
  //   // cSpell:disable
  //   // cSpell:enable
  {
    types: {
      context: {} as { loggerData: ILoggerData },
      input: {} as { loggerData: ILoggerData },
      events: {} as { type: 'saveFile' },
    },
    context: ({ input }) => ({ loggerData: input.loggerData}),
    id: 'testMachine',
    initial: 'Idle',
    states: {
      Idle: {
        entry: {
          type: 'testMachineInitialStateEntryAction',
        },
        exit: {
          type: 'testMachineInitialStateExitAction',
        },
        on: {
          saveFile: {
            target: 'SaveFileState',
          },
        },
      },
      SaveFileState: {
        entry: {
          type: 'testMachineSaveFileStateEntryAction',
        },
        invoke: {
          id: 'SaveFileActor',
          src: 'saveFileActorLogic',
          input: ({ context }) => ({
            logger: context.loggerData.logger,
            data: context.loggerData.data,
          }),
          onDone: {
            target: 'Idle',
          },
        },
      },
      'Final State': {
        entry: {
          type: 'testMachineFinalStateEntryAction',
        },
        type: 'final',
      },
    },
  },
  {
    actions: {
      testMachineInitialStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`testMachineInitialStateEntryAction called`, LogLevel.Debug);
        context.loggerData.logger.log(
          `context.data.configurationData.currentMode: ${context.loggerData.data.configurationData.currentMode}`,
          LogLevel.Debug,
        );
        context.loggerData.logger.log(`event type: ${event.type}`, LogLevel.Debug);
      },
      testMachineInitialStateExitAction: ({ context, event }) => {
        context.loggerData.logger.log(`testMachineInitialStateExitAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}`, LogLevel.Debug);
      },
      testMachineSaveFileStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`testMachineSaveFileStateEntryAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}`, LogLevel.Debug);
      },
      testMachineFinalStateEntryAction: ({ context, event }) => {
        context.loggerData.logger.log(`testMachineFinalStateEntryAction called`, LogLevel.Debug);
        context.loggerData.logger.log(`event type: ${event.type}`, LogLevel.Debug);
        // ToDo: call parent with TestStateComplete event
      },
    },
  },
);
