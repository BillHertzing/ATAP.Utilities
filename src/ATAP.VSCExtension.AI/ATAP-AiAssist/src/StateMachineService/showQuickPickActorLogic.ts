import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

import {
  CommandMenuItemEnum,
  ModeMenuItemEnum,
  QuickPickEnumeration,
  StatusMenuItemEnum,
  SupportedQueryEnginesEnum,
} from '@BaseEnumerations/index';

import { fromCallback, StateMachine, fromPromise, raise } from 'xstate';

import { ILoggerData } from '@StateMachineService/index';

import { IQuickPickInput } from './StateMachineService';

export const showQuickPickActorLogic = fromPromise(async ({ input }: { input: IQuickPickInput }) => {
  input.logger.log(`showQuickPickActorLogic called with KindOfEnumeration= ${input.kindOfEnumeration}`, LogLevel.Debug);
  let quickPickItems: vscode.QuickPickItem[];
  let prompt: string;
  let pick: vscode.QuickPickItem | undefined;
  switch (input.kindOfEnumeration) {
    case QuickPickEnumeration.StatusMenuItemEnum:
      quickPickItems = input.data.pickItems.statusMenuItems;
      prompt = `pick an action from list below to execute it`;
      pick = await vscode.window.showQuickPick(quickPickItems, {
        placeHolder: prompt,
      });
      if (pick !== undefined) {
        const statusMenuItem = pick.label as StatusMenuItemEnum;
        switch (statusMenuItem) {
          case StatusMenuItemEnum.Mode:
            input.logger.log(`handle ${StatusMenuItemEnum.Mode}`, LogLevel.Debug);
            vscode.commands.executeCommand(`atap-aiassist.primaryActor.quickPickMode`);
            break;
          case StatusMenuItemEnum.Command:
            input.logger.log(`handle ${StatusMenuItemEnum.Command}`, LogLevel.Debug);
            vscode.commands.executeCommand(`atap-aiassist.primaryActor.quickPickCommand`);
            break;
          case StatusMenuItemEnum.Sources:
            input.logger.log(`ToDo: handle ${StatusMenuItemEnum.Sources}`, LogLevel.Debug);
            break;
          case StatusMenuItemEnum.ShowLogs:
            input.logger.log(`handle ${StatusMenuItemEnum.ShowLogs}`, LogLevel.Debug);
            input.logger.getChannelInfo('atap-aiassist')?.outputChannel?.show(true);
            break;
          default:
            // ToDo: investigate a better way than throwing inside an actor logic....
            throw new DetailedError(`showQuickPickActor received an unexpected statusMenuItem: ${statusMenuItem}`);
            break;
        }
      }
      break;
    case QuickPickEnumeration.ModeMenuItemEnum:
      quickPickItems = input.data.pickItems.modeMenuItems;
      prompt = `currentMode is ${input.data.stateManager.currentMode}, select from list below to change it`;
      pick = await vscode.window.showQuickPick(quickPickItems, {
        placeHolder: prompt,
      });
      if (pick !== undefined) {
        input.data.stateManager.currentMode = pick.label as ModeMenuItemEnum;
      }
      break;
    case QuickPickEnumeration.CommandMenuItemEnum:
      quickPickItems = input.data.pickItems.commandMenuItems;
      prompt = `currentCommand is ${input.data.stateManager.currentCommand}, select from list below to change it`;
      pick = await vscode.window.showQuickPick(quickPickItems, {
        placeHolder: prompt,
      });

      const priorCommand = input.data.stateManager.currentCommand;
      if (pick !== undefined) {
        input.data.stateManager.currentCommand = pick.label as CommandMenuItemEnum;
      }
      break;
  }
  if (pick === undefined) {
    input.logger.log(`showQuickPickActorLogic pick is undefined`, LogLevel.Debug);

    throw new Error('undefined');
  }
  input.logger.log(`showQuickPickActorLogic done, pick.label  ${pick.label}`, LogLevel.Debug);
  return pick.label, input.kindOfEnumeration;
});

//   fromPromise(async ({ input }: { input: IQuickPickInput }) => {
//   let quickPickItems: vscode.QuickPickItem[];
//   let prompt: string;
//   let pick: vscode.QuickPickItem | undefined;

//   switch (input.kindOfEnumeration) {
//     case QuickPickEnumeration.StatusMenuItemEnum:
//       quickPickItems = input.data.pickItems.statusMenuItems;
//       prompt = `pick an action from list below to execute it`;
//       pick = await vscode.window.showQuickPick(quickPickItems, {
//         placeHolder: prompt,
//       });
//       if (pick !== undefined) {
//         // Call the appropriate VSC Command? Or Send an event to the parent, primaryActor?
//         // ToDo: send the appropriate event (quickPickEvent with kind set to pick.label) to the primaryActor
//       }
//       break;
//     case QuickPickEnumeration.ModeMenuItemEnum:
//       quickPickItems = input.data.pickItems.modeMenuItems;
//       prompt = `currentMode is ${input.data.stateManager.currentMode}, select from list below to change it`;
//       pick = await vscode.window.showQuickPick(quickPickItems, {
//         placeHolder: prompt,
//       });
//       if (pick !== undefined) {
//         input.data.stateManager.currentMode = pick.label as ModeMenuItemEnum;
//       }
//       break;
//     case QuickPickEnumeration.CommandMenuItemEnum:
//       quickPickItems = input.data.pickItems.commandMenuItems;
//       prompt = `currentCommand is ${input.data.stateManager.currentCommand}, select from list below to change it`;
//       pick = await vscode.window.showQuickPick(quickPickItems, {
//         placeHolder: prompt,
//       });
//       const priorCommand = input.data.stateManager.currentCommand;
//       if (pick !== undefined) {
//         input.data.stateManager.currentCommand = pick.label as CommandMenuItemEnum;
//       }
//       break;
//   }
// });
