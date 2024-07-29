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
  IQuickPickActorInput,
  IQuickPickActorOutput,
} from "./quickPickTypes";

import { createQuickPickValue } from "./quickPickMachine";

// *********************************************************************************************************************
// Actor Logic for the quickPickMachine
export const quickPickActorLogic = fromPromise(
  async ({ input }: { input: IQuickPickActorInput }) => {
    const logger = new Logger(input.logger, "quickPickActorLogic");
    logger.log(
      `Starting. pickValue.kindOfEnumeration = ${input.pickValue[0]}, PickItems= ${input.pickItems}, prompt= ${input.prompt}`,
      LogLevel.Debug,
    );
    let _pick: vscode.QuickPickItem | undefined;
    let _isCancelled: boolean = false;
    let _isLostFocus: boolean = false;
    let _pickValue: QuickPickValueT = input.pickValue;
    const kindOfEnumeration = input.pickValue[0];
    _pick = await vscode.window.showQuickPick(
      input.pickItems,
      {
        placeHolder: input.prompt,
      },
      input.cTSToken,
    );
    if (input.cTSToken.isCancellationRequested) {
      _isCancelled = true;
      _pickValue = createQuickPickValue(kindOfEnumeration, undefined);
    } else if (_pick === undefined) {
      _isLostFocus = true;
      _pickValue = createQuickPickValue(kindOfEnumeration, undefined);
    } else {
      switch (kindOfEnumeration) {
        case QuickPickEnumeration.ModeMenuItemEnum:
          _pickValue = createQuickPickValue(
            kindOfEnumeration,
            _pick.label as ModeMenuItemEnum,
          );
          break;
        case QuickPickEnumeration.QueryAgentCommandMenuItemEnum:
          _pickValue = createQuickPickValue(
            kindOfEnumeration,
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
              const _errorMessage = `Received an unexpected QueryEngineName: ${_pick.label}`;
              logger.log(_errorMessage, LogLevel.Error);
              throw new Error(`${logger.scope} ` + _errorMessage);
          }
          _pickValue = createQuickPickValue(
            kindOfEnumeration,
            _newQueryEngines as QueryEngineFlagsEnum,
          );
          break;
        default:
          const _errorMessage = `Received an unexpected kindOfEnumeration: ${kindOfEnumeration}`;
          logger.log(_errorMessage, LogLevel.Error);
          throw new Error(`${logger.scope} ` + _errorMessage);
      }
    }
    logger.log(
      `Returning pickValue ${_pickValue}, isCancelled= ${_isCancelled}, isLostFocus= ${_isLostFocus}`,
      LogLevel.Debug,
    );

    return {
      pickValue: _pickValue,
      isCancelled: _isCancelled,
      isLostFocus: _isLostFocus,
    } as IQuickPickActorOutput;
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
