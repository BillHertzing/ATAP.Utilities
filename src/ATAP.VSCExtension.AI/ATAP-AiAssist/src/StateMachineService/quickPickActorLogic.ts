import * as vscode from "vscode";
import { LogLevel, ILogger, Logger } from "@Logger/index";
import { DetailedError, HandleError } from "@ErrorClasses/index";
import {
  ActionFunction,
  assertEvent,
  assign,
  fromCallback,
  fromPromise,
  sendTo,
  setup,
  StateMachine,
} from "xstate";

import {
  ModeMenuItemEnum,
  QueryAgentCommandMenuItemEnum,
  QueryFragmentEnum,
  QuickPickEnumeration,
  QueryEngineNamesEnum,
  QueryEngineFlagsEnum,
  VCSCommandMenuItemEnum,
} from "@BaseEnumerations/index";

import {
  QuickPickValueT,
  IQuickPickActorLogicInput,
  IQuickPickActorLogicOutput,
} from "./quickPickMachineTypes";

import { createQuickPickValue } from "./quickPickMachine";

// **********************************************************************************************************************
// Actor Logic for the quickPickMachine
export const quickPickActorLogic = fromPromise(
  async ({ input }: { input: IQuickPickActorLogicInput }) => {
    input.logger.log(
      `quickPickActorLogic called pickValue.quickPickKindOfEnumeration = ${input.pickValue[0]}, PickItems= ${input.pickItems}, prompt= ${input.prompt}`,
      LogLevel.Debug,
    );
    let _pick: vscode.QuickPickItem | undefined;
    let _isCancelled: boolean = false;
    let _isLostFocus: boolean = false;
    let _pickValue: QuickPickValueT = input.pickValue;
    const quickPickKindOfEnumeration = input.pickValue[0];
    _pick = await vscode.window.showQuickPick(
      input.pickItems,
      {
        placeHolder: input.prompt,
      },
      input.cTSToken,
    );
    if (input.cTSToken.isCancellationRequested) {
      _isCancelled = true;
      _pickValue = createQuickPickValue(quickPickKindOfEnumeration, undefined);
    } else if (_pick === undefined) {
      _isLostFocus = true;
      _pickValue = createQuickPickValue(quickPickKindOfEnumeration, undefined);
    } else {
      switch (quickPickKindOfEnumeration) {
        case QuickPickEnumeration.ModeMenuItemEnum:
          _pickValue = createQuickPickValue(
            quickPickKindOfEnumeration,
            _pick.label as ModeMenuItemEnum,
          );
          break;
        case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
          _pickValue = createQuickPickValue(
            quickPickKindOfEnumeration,
            _pick.label as QueryAgentCommandMenuItemEnum,
          );
          break;
        case QuickPickEnumeration.QueryEnginesMenuItemEnum:
          let _newQueryEngines: QueryEngineFlagsEnum = input
            .pickValue[1] as QueryEngineFlagsEnum;
          switch (_pick.label as QueryEngineNamesEnum) {
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
                `quickPickActorLogic received an unexpected QueryEngineName: ${_pick.label}`,
              );
          }
          _pickValue = createQuickPickValue(
            quickPickKindOfEnumeration,
            _newQueryEngines as QueryEngineFlagsEnum,
          );
          break;
        default:
          throw new Error(
            `quickPickActorLogic received an unexpected quickPickKindOfEnumeration: ${quickPickKindOfEnumeration}`,
          );
      }
    }
    input.logger.log(
      `quickPickActorLogic returning pickValue ${_pickValue}, isCancelled= ${_isCancelled}, isLostFocus= ${_isLostFocus}`,
      LogLevel.Debug,
    );

    return {
      pickValue: _pickValue,
      isCancelled: _isCancelled,
      isLostFocus: _isLostFocus,
    } as IQuickPickActorLogicOutput;
  },
);

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
