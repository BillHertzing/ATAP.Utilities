import * as vscode from 'vscode';
import { LogLevel, ILogger, Logger } from '@Logger/index';
import { DetailedError, HandleError } from '@ErrorClasses/index';
import { logConstructor, logFunction, logAsyncFunction, logExecutionTime } from '@Decorators/index';

import {
  QueryAgentCommandMenuItemEnum,
  ModeMenuItemEnum,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
  QuickPickEnumeration,
  VCSCommandMenuItemEnum,
} from '@BaseEnumerations/index';

import { fromCallback, StateMachine, fromPromise, assign, ActionFunction } from 'xstate';

import { MachineContextT } from '@StateMachineService/index';

export type QuickPickEventPayloadT = {
  kindOfEnumeration: QuickPickEnumeration;
  cTSId: string;
};

export type QPActorLogicInputT = MachineContextT & QuickPickEventPayloadT;

export type QPActorLogicOutputT = {
  kindOfEnumeration: QuickPickEnumeration;
  pickLabel: string;
  cTSId: string;
};

export const quickPickActorLogic = fromPromise(async ({ input }: { input: QPActorLogicInputT }) => {
  input.logger.log(`quickPickActorLogic called with KindOfEnumeration= ${input.kindOfEnumeration}`, LogLevel.Debug);

  let quickPickItems: vscode.QuickPickItem[];
  let prompt: string;
  let pick: vscode.QuickPickItem | undefined;
  let pickLabel: string;
  switch (input.kindOfEnumeration) {
    case QuickPickEnumeration.ModeMenuItemEnum:
      quickPickItems = input.data.pickItems.modeMenuItems;
      prompt = `currentMode is ${input.data.stateManager.currentMode}, select from list below to change it`;
      break;
    case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
      quickPickItems = input.data.pickItems.queryAgentCommandMenuItems;
      prompt = `currentQueryAgentCommand is ${input.data.stateManager.currentQueryAgentCommand}, select from list below to change it`;
      break;
    case QuickPickEnumeration.QueryEnginesMenuItemEnum:
      quickPickItems = input.data.pickItems.queryEnginesMenuItems;
      prompt = `currently active Query Engines are shown below, select one from the list to toggle it`;
      break;
    case QuickPickEnumeration.VCSCommandMenuItemEnum:
      quickPickItems = input.data.pickItems.vCSCommandMenuItems;
      prompt = `pick an action from list below to execute it`;
      break;
    default:
      input.logger.log(
        `quickPickActorLogic called with an unknown KindOfEnumeration = ${input.kindOfEnumeration}`,
        LogLevel.Debug,
      );
      throw new Error(`quickPickActorLogic called with an unknown KindOfEnumeration = ${input.kindOfEnumeration}`);
  }
  const cancellationToken = new vscode.CancellationTokenSource().token; // .  input.data.cancellationTokenSourceManager.cancellationTokenSourceCollection.FindByID(cTSId).token;
  pick = await vscode.window.showQuickPick(
    quickPickItems,
    {
      placeHolder: prompt,
    },
    cancellationToken,
  );
  // ToDo: make the various cancellation conditions into an enumeration, and return that as part of the retrun structure?
  if (cancellationToken.isCancellationRequested) {
    pickLabel = 'undefined:CancellationRequested';
  } else if (pick === undefined) {
    pickLabel = 'undefined:LostFocus';
  } else {
    pickLabel = pick.label;
  }
  input.logger.log(
    `quickPickActorLogic leaving with KindOfEnumeration= ${input.kindOfEnumeration}, pickLabel: ${pickLabel}`,
    LogLevel.Debug,
  );
  return { kindOfEnumeration: input.kindOfEnumeration, pickLabel: pickLabel, cTSId: input.cTSId };
});

// case QuickPickEnumeration.VCSCommandMenuItemEnum:
//   let _newVCSCommand: string;
//   if (pick !== undefined) {
//     const vCSCommandMenuItem = pick.label as VCSCommandMenuItemEnum;
//     switch (vCSCommandMenuItem) {
//       case VCSCommandMenuItemEnum.Mode:
//         input.logger.log(`handle ${VCSCommandMenuItemEnum.Mode}`, LogLevel.Debug);
//         _newVCSCommand = 'atap-aiassist.primaryActor.quickPickMode';
//         //vscode.commands.executeCommand(`atap-aiassist.primaryActor.quickPickMode`);
//         break;
//       case VCSCommandMenuItemEnum.Command:
//         input.logger.log(`handle ${VCSCommandMenuItemEnum.Command}`, LogLevel.Debug);
//         _newVCSCommand = 'atap-aiassist.primaryActor.quickPickCommand';
//         // vscode.commands.executeCommand(`atap-aiassist.primaryActor.quickPickCommand`);
//         break;
//       case VCSCommandMenuItemEnum.QueryEngines:
//         input.logger.log(`handle ${VCSCommandMenuItemEnum.QueryEngines}`, LogLevel.Debug);
//         _newVCSCommand = 'atap-aiassist.primaryActor.quickPickQueryEngines';
//         // vscode.commands.executeCommand(`atap-aiassist.primaryActor.quickPickQueryEngines`);
//         break;
//       case VCSCommandMenuItemEnum.Sources:
//         input.logger.log(`ToDo: handle ${VCSCommandMenuItemEnum.Sources}`, LogLevel.Debug);
//         _newVCSCommand = 'atap-aiassist.primaryActor.quickPickSources';
//         break;
//       case VCSCommandMenuItemEnum.ShowLogs:
//         input.logger.log(`handle ${VCSCommandMenuItemEnum.ShowLogs}`, LogLevel.Debug);
//         // ToDo: code smell Figure out how to return this instead of calling it here...
//         input.logger.getChannelInfo('atap-aiassist')?.outputChannel?.show(true);
//         _newVCSCommand = 'input.logger.getChannelInfo("atap-aiassist")?.outputChannel?.show(true)';
//         break;
//       default:
//         // ToDo: investigate a better way than throwing inside an actor logic....
//         throw new Error(`quickPickActor received an unexpected vCSCommandMenuItem: ${vCSCommandMenuItem}`);
//         break;
//     }
//   } else {
//     throw new Error('undefined');
//   }
