import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

import {
  CommandMenuItemEnum,
  ModeMenuItemEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
  QuickPickEnumeration,
  StatusMenuItemEnum,
  SupportedQueryEnginesEnum,
} from '@BaseEnumerations/index';

import { fromCallback, StateMachine, fromPromise, assign, ActionFunction } from 'xstate';

import { IData } from '@DataService/index';

import { IQuickPickInput } from './StateMachineService';

export interface IQuickPickActorLogicModeOutput {
  kindOfEnumeration: QuickPickEnumeration;
  newMode: ModeMenuItemEnum;
}
export interface IQuickPickActorLogicCommandOutput {
  kindOfEnumeration: QuickPickEnumeration;
  newCommand: CommandMenuItemEnum;
}
export interface IQuickPickActorLogicQueryEnginesOutput {
  kindOfEnumeration: QuickPickEnumeration;
  newQueryEngineFlags: QueryEngineFlagsEnum;
}
export interface IQuickPickActorLogicVCSCommandOutput {
  kindOfEnumeration: QuickPickEnumeration;
  newVCSCommand: StatusMenuItemEnum;
}
export type showQuickPickActorLogicOutputTypeUnion =
  | IQuickPickActorLogicModeOutput
  | IQuickPickActorLogicCommandOutput
  | IQuickPickActorLogicQueryEnginesOutput
  | IQuickPickActorLogicVCSCommandOutput;

export const showQuickPickActorLogic = fromPromise(async ({ input }: { input: IQuickPickInput }) => {
  input.logger.log(`showQuickPickActorLogic called with KindOfEnumeration= ${input.kindOfEnumeration}`, LogLevel.Debug);
  let quickPickItems: vscode.QuickPickItem[];
  let prompt: string;
  let pick: vscode.QuickPickItem | undefined;
  switch (input.kindOfEnumeration) {
    case QuickPickEnumeration.ModeMenuItemEnum:
      quickPickItems = input.data.pickItems.modeMenuItems;
      prompt = `currentMode is ${input.data.stateManager.currentMode}, select from list below to change it`;
      pick = await vscode.window.showQuickPick(quickPickItems, {
        placeHolder: prompt,
      });
      let _newMode: ModeMenuItemEnum;
      if (pick !== undefined) {
        _newMode = pick.label as ModeMenuItemEnum;
      } else {
        throw new Error('undefined');
      }
      return { newMode: _newMode, kindOfEnumeration: input.kindOfEnumeration };
    case QuickPickEnumeration.CommandMenuItemEnum:
      quickPickItems = input.data.pickItems.commandMenuItems;
      prompt = `currentCommand is ${input.data.stateManager.currentCommand}, select from list below to change it`;
      pick = await vscode.window.showQuickPick(quickPickItems, {
        placeHolder: prompt,
      });
      let _newCommand: CommandMenuItemEnum;
      if (pick !== undefined) {
        _newCommand = pick.label as CommandMenuItemEnum;
      } else {
        throw new Error('undefined');
      }
      return { newCommand: _newCommand, kindOfEnumeration: input.kindOfEnumeration };
    case QuickPickEnumeration.QueryEnginesMenuItemEnum:
      quickPickItems = input.data.pickItems.queryEnginesMenuItems;
      prompt = `currently active Query Engines are shown below, select one from the list to toggle it`;
      pick = await vscode.window.showQuickPick(quickPickItems, {
        placeHolder: prompt,
      });
      // ToDo: is it necessary to create and track a priorQueryEngines field
      //const priorCommand = input.data.stateManager.currentCommand;
      let _newQueryEngines: QueryEngineFlagsEnum = input.data.stateManager.currentQueryEngines;
      if (pick !== undefined) {
        const _selectedQueryEngineName = pick.label as QueryEngineNamesEnum;
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
              `showQuickPickActor received an unexpected _selectedQueryEngineName: ${_selectedQueryEngineName}`,
            );
        }
      } else {
        throw new Error('undefined');
      }
      return { newQueryEngineFlags: _newQueryEngines, kindOfEnumeration: input.kindOfEnumeration };
    case QuickPickEnumeration.StatusMenuItemEnum:
      quickPickItems = input.data.pickItems.statusMenuItems;
      prompt = `pick an action from list below to execute it`;
      pick = await vscode.window.showQuickPick(quickPickItems, {
        placeHolder: prompt,
      });
      let _newVCSCommand: string;
      if (pick !== undefined) {
        const statusMenuItem = pick.label as StatusMenuItemEnum;
        switch (statusMenuItem) {
          case StatusMenuItemEnum.Mode:
            input.logger.log(`handle ${StatusMenuItemEnum.Mode}`, LogLevel.Debug);
            _newVCSCommand = 'atap-aiassist.primaryActor.quickPickMode';
            //vscode.commands.executeCommand(`atap-aiassist.primaryActor.quickPickMode`);
            break;
          case StatusMenuItemEnum.Command:
            input.logger.log(`handle ${StatusMenuItemEnum.Command}`, LogLevel.Debug);
            _newVCSCommand = 'atap-aiassist.primaryActor.quickPickCommand';
            // vscode.commands.executeCommand(`atap-aiassist.primaryActor.quickPickCommand`);
            break;
          case StatusMenuItemEnum.QueryEngines:
            input.logger.log(`handle ${StatusMenuItemEnum.QueryEngines}`, LogLevel.Debug);
            _newVCSCommand = 'atap-aiassist.primaryActor.quickPickQueryEngines';
            // vscode.commands.executeCommand(`atap-aiassist.primaryActor.quickPickQueryEngines`);
            break;
          case StatusMenuItemEnum.Sources:
            input.logger.log(`ToDo: handle ${StatusMenuItemEnum.Sources}`, LogLevel.Debug);
            _newVCSCommand = 'atap-aiassist.primaryActor.quickPickSources';
            break;
          case StatusMenuItemEnum.ShowLogs:
            input.logger.log(`handle ${StatusMenuItemEnum.ShowLogs}`, LogLevel.Debug);
            // ToDo: code smell Figure out how to return this instead of calling it here...
            input.logger.getChannelInfo('atap-aiassist')?.outputChannel?.show(true);
            _newVCSCommand = 'input.logger.getChannelInfo("atap-aiassist")?.outputChannel?.show(true)';
            break;
          default:
            // ToDo: investigate a better way than throwing inside an actor logic....
            throw new Error(`showQuickPickActor received an unexpected statusMenuItem: ${statusMenuItem}`);
            break;
        }
      } else {
        throw new Error('undefined');
      }
      return { kindOfEnumeration: input.kindOfEnumeration, newVCSCommand: _newVCSCommand };
    default:
      input.logger.log(
        `showQuickPickActorLogic called with an unknown KindOfEnumeration = ${input.kindOfEnumeration}`,
        LogLevel.Debug,
      );
      throw new Error(`showQuickPickActorLogic called with an unknown KindOfEnumeration = ${input.kindOfEnumeration}`);
  }
});

export const handleShowQuickPickActorLogicOutputAction: ActionFunction<{ logger: ILogger; data: IData }> = (
  context: { logger: ILogger; data: IData },
  event: { type: 'done.invoke.showQuickPickActorLogic'; data: showQuickPickActorLogicOutputTypeUnion },
) => {
  context.logger.log(`handleShowQuickPickActorLogicOutput called `, LogLevel.Debug);
  if (event.type === 'done.invoke.showQuickPickActorLogic' && event.data) {
    const data = event.data as showQuickPickActorLogicOutputTypeUnion;
    let assignAction: any;
    switch (data.kindOfEnumeration) {
      case QuickPickEnumeration.ModeMenuItemEnum:
        assignAction = assign({
          ...context.data,
          stateManager: { ...context.data.stateManager, currentMode: (data as IQuickPickActorLogicModeOutput).newMode },
        });
        break;
      case QuickPickEnumeration.CommandMenuItemEnum:
        assignAction = assign({
          ...context.data,
          stateManager: {
            ...context.data.stateManager,
            currentCommand: (data as IQuickPickActorLogicCommandOutput).newCommand,
          },
        });
        break;
      case QuickPickEnumeration.QueryEnginesMenuItemEnum:
        throw new Error(`ToDo: handle this kindOfEnumeration: ${data.kindOfEnumeration}`);
      case QuickPickEnumeration.StatusMenuItemEnum:
        throw new Error(`ToDo: handle this kindOfEnumeration: ${data.kindOfEnumeration}`);
      // return {
      //   ...context.data,
      //   stateManager: { ...context.data.stateManager, currentQueryEngineFlags: data.newQueryEngineFlags },
      // };
      //
    }
    // Execute the assign action to update the context
    assignAction(context, event);
  }
  // Throw  if this action is called with an event type other than 'done.invoke.showQuickPickActorLogic'
  throw new Error(`handleShowQuickPickActorLogicOutput called with event type ${event.type}`);
};
