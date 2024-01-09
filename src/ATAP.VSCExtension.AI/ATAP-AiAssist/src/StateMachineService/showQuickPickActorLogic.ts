import * as vscode from 'vscode';
import { ILogger, Logger, LogLevel } from '@Logger/index';
import { Actor, createActor, assign, createMachine, fromCallback, StateMachine, fromPromise, raise } from 'xstate';
import { ILoggerData, StatusMenuItemEnum, ModeMenuItemEnum, CommandMenuItemEnum } from '@StateMachineService/index';

import { IQuickPickInput } from './StateMachineService';
import { QuickPickEnumeration } from './PrimaryMachine';

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
        // Call the appropriate VSC Command? Or Send an event to the parent, primaryActor?
        // ToDo: send the appropriate event (quickPickEvent with kind set to pick.label) to the primaryActor
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
});
