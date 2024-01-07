import * as vscode from 'vscode';
import { ILogger, Logger, LogLevel } from '@Logger/index';
import { Actor, createActor, assign, createMachine, fromCallback, StateMachine, fromPromise, raise } from 'xstate';
import { ILoggerData, StatusMenuItemEnum, ModeMenuItemEnum,CommandMenuItemEnum } from '@StateMachineService/index';

import { IQuickPickInput  } from './StateMachineService';
import { QuickPickEnumeration } from './PrimaryMachine';


export const changeQuickPickActorLogic = fromPromise(async ({ input }: { input: IQuickPickInput }) => {

    input.logger.log(`changeQuickPickActorLogic called with KindOfEnumeration= ${input.kindOfEnumeration}`, LogLevel.Debug);
    let quickPickItems: vscode.QuickPickItem[];
    let prompt: string;
    let pick: vscode.QuickPickItem | undefined;
  
    switch(input.kindOfEnumeration){
      case QuickPickEnumeration.StatusMenuItemEnum:
        quickPickItems = input.data.pickItems.statusMenuItems;
        prompt = `pick an action from list below to change it`;
        pick = await vscode.window.showQuickPick(quickPickItems, {
          placeHolder: prompt,
        });
        if (pick !== undefined) {
          // Call the appropriate VSC Command? Or just set the state?
          // input.data.stateManager.currentStatus = pick.label as StatusMenuItemEnum;
        }
        break;
      case QuickPickEnumeration.ModeMenuItemEnum:
        quickPickItems  = input.data.pickItems.modeMenuItems;
        prompt = `currentMode is ${input.data.stateManager.currentMode}, select from list below to change it`;
        pick = await vscode.window.showQuickPick(quickPickItems, {
          placeHolder: prompt,
        });
        if (pick !== undefined) {
          input.data.stateManager.priorMode = input.data.stateManager.currentMode;
          input.data.stateManager.currentMode = pick.label as ModeMenuItemEnum;
        }
        break;
      case QuickPickEnumeration.CommandMenuItemEnum:
        quickPickItems  = input.data.pickItems.commandMenuItems;
        prompt = `currentCommand is ${input.data.stateManager.currentCommand}, select from list below to change it`;
         pick = await vscode.window.showQuickPick(quickPickItems, {
          placeHolder: prompt,
        });
        const priorCommand = input.data.stateManager.currentCommand;
        if (pick !== undefined) {
          input.data.stateManager.priorCommand = input.data.stateManager.currentCommand;
          input.data.stateManager.currentCommand = pick.label as CommandMenuItemEnum;
        }
        break;
      }
    
  });
  